import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import OSLog

struct UserProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UserProfileEditViewModel
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingDiscardAlert = false
    @State private var showingSaveAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""
    @State private var showingValidationAlert = false
    @EnvironmentObject private var authManager: AuthManager
    
    private let logger = Logger(subsystem: "com.dynasty.UserProfileEditView", category: "Profile")
    private let analytics = AnalyticsService.shared
    
    init(currentUser: User) {
        self._viewModel = StateObject(wrappedValue: UserProfileEditViewModel(user: currentUser))
        self._firstName = State(initialValue: currentUser.firstName ?? "")
        self._lastName = State(initialValue: currentUser.lastName ?? "")
        self._email = State(initialValue: currentUser.email ?? "")
        self._phoneNumber = State(initialValue: currentUser.phoneNumber ?? "")
    }
    
    var hasChanges: Bool {
        guard let user = viewModel.user else { return false }
        return firstName != (user.firstName ?? "") ||
            lastName != (user.lastName ?? "") ||
            email != user.email ||
            phoneNumber != (user.phoneNumber ?? "") ||
            selectedImage != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    LoadingView(message: "Saving changes...")
                } else {
                    // Profile Header
                    VStack(spacing: 16) {
                        profileImage
                        
                        Text("Hey, \(firstName)!")
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 20)
                    
                    // Personal Information
                    SettingsSection(title: "Personal Information") {
                        VStack(spacing: 12) {
                            CustomTextField(
                                icon: "person.fill",
                                title: "First Name",
                                text: $firstName,
                                contentType: .givenName,
                                error: viewModel.validationErrors["firstName"]
                            )
                            
                            CustomTextField(
                                icon: "person.fill",
                                title: "Last Name",
                                text: $lastName,
                                contentType: .familyName,
                                error: viewModel.validationErrors["lastName"]
                            )
                            
                            CustomTextField(
                                icon: "envelope.fill",
                                title: "Email",
                                text: $email,
                                contentType: .emailAddress,
                                keyboardType: .emailAddress,
                                error: viewModel.validationErrors["email"]
                            )
                            
                            CustomTextField(
                                icon: "phone.fill",
                                title: "Phone Number",
                                text: $phoneNumber,
                                contentType: .telephoneNumber,
                                keyboardType: .phonePad,
                                error: viewModel.validationErrors["phone"]
                            )
                            
                            if let formError = viewModel.validationErrors["form"] {
                                Text(formError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    
                    // Save Changes Button
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasChanges ? Color.blue : Color.gray)
                            .cornerRadius(15)
                    }
                    .disabled(!hasChanges)
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            trailing: Button("Cancel") {
                if hasChanges {
                    showingDiscardAlert = true
                } else {
                    dismiss()
                }
            }
        )
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("Are you sure you want to discard your changes?")
        }
        .alert(isPresented: $showingSaveAlert) {
            Alert(
                title: Text(viewModel.error == nil ? "Success" : "Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if viewModel.error == nil {
                        dismiss()
                    }
                }
            )
        }
        .errorOverlay(error: viewModel.error, isPresented: $showingErrorAlert) {
            viewModel.error = nil
        }
        .onAppear {
            analytics.logProfileView()
            viewModel.loadCachedProfile()
        }
        .onChange(of: firstName) { _ in viewModel.clearValidationErrors() }
        .onChange(of: lastName) { _ in viewModel.clearValidationErrors() }
        .onChange(of: email) { _ in viewModel.clearValidationErrors() }
        .onChange(of: phoneNumber) { _ in viewModel.clearValidationErrors() }
    }
    
    private var profileImage: some View {
        VStack {
            Group {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let displayImage = viewModel.profileImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let imageURL = viewModel.profileImageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                            .frame(width: 100, height: 100)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                }
            }
            .accessibilityLabel("Profile photo")
            .onAppear {
                if let userId = viewModel.user?.id {
                    Task {
                        await viewModel.loadProfileImage(userId: userId)
                    }
                }
            }
            
            Button("Change Profile Picture") {
                isShowingImagePicker = true
            }
            .foregroundColor(.blue)
            .padding(.top, 8)
            
            if viewModel.isUploading {
                ProgressView("Uploading", value: viewModel.uploadProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }
        }
    }
    
    private func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.error("User not authenticated.")
            alertMessage = "User not authenticated."
            showingSaveAlert = true
            return
        }
        
        Task {
            do {
                var updatedData: [String: Any] = [
                    "firstName": firstName,
                    "lastName": lastName,
                    "email": email,
                    "phoneNumber": phoneNumber
                ]
                
                if let selectedImage = selectedImage {
                    let photoURL = try await viewModel.uploadProfileImage(image: selectedImage)
                    updatedData["photoURL"] = photoURL
                }
                
                try await viewModel.updateProfile(userId: uid, updatedData: updatedData)
                await MainActor.run {
                    alertMessage = "Profile updated successfully!"
                    showingSaveAlert = true
                    Task {
                        await authManager.fetchAndUpdateUser()
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("Error saving profile: \(error.localizedDescription)")
                    viewModel.error = error
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct CustomTextField: View {
    let icon: String
    let title: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var error: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                TextField(title, text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 30)
            }
        }
    }
}

#Preview {
    let previewUser = User(
        id: "preview",
        email: "john@example.com",
        firstName: "John",
        lastName: "Doe",
        dateOfBirth: Date(),
        gender: nil,
        phoneNumber: "+1234567890",
        country: nil,
        photoURL: nil,
        familyTreeID: nil,
        historyBookID: nil,
        parentIds: [],
        childIds: [],
        spouseId: nil,
        siblingIds: [],
        role: .member,
        canAddMembers: false,
        canEdit: false,
        createdAt: nil,
        updatedAt: nil
    )
    
    UserProfileEditView(currentUser: previewUser)
        .environmentObject(AuthManager())
}
