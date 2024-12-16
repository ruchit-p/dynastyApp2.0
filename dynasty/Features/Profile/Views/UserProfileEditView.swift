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
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @EnvironmentObject private var authManager: AuthManager
    
    private let logger = Logger(subsystem: "com.dynasty.UserProfileEditView", category: "Profile")

    init(currentUser: User) {
        self._viewModel = StateObject(wrappedValue: UserProfileEditViewModel(user: currentUser))
        self._firstName = State(initialValue: currentUser.firstName ?? "")
        self._lastName = State(initialValue: currentUser.lastName ?? "")
        self._email = State(initialValue: currentUser.email)
        self._phoneNumber = State(initialValue: currentUser.phoneNumber ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 16) {
                        profileImage
                        
                        Text("Hey, \(firstName)!")
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 20)
                    
                    // Personal Information Section
                    VStack(spacing: 8) {
                        personalInfoSection
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    
                    // Save Changes Button
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .overlay(Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            })
        }
    }
    
    private var profileImage: some View {
        VStack {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else if let user = viewModel.user, let photoURL = user.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
            }
            
            Button("Change Profile Picture") {
                isShowingImagePicker = true
            }
            .foregroundColor(.blue)
            .padding(.top, 8)
            
            if isUploading {
                ProgressView("Uploading", value: uploadProgress, total: 1.0)
                    .padding(.top, 8)
            }
        }
    }
    
    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Information")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Update your profile details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
            }
            
            VStack(spacing: 12) {
                TextField("First Name", text: $firstName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.error("User not authenticated.")
            showAlert(message: "User not authenticated.")
            return
        }

        var updatedData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "phoneNumber": phoneNumber
        ]

        if let selectedImage = selectedImage {
            isUploading = true
            uploadProfileImage(image: selectedImage) { result in
                isUploading = false
                switch result {
                case .success(let photoURL):
                    updatedData["photoURL"] = photoURL
                    saveUserData(userId: uid, data: updatedData)
                case .failure(let error):
                    logger.error("Image upload failed: \(error.localizedDescription)")
                    showAlert(message: "Failed to upload image. Please try again.")
                }
            }
        } else {
            saveUserData(userId: uid, data: updatedData)
        }
    }

    private func saveUserData(userId: String, data: [String: Any]) {
        Task {
            do {
                try await viewModel.updateProfile(userId: userId, updatedData: data)
                await MainActor.run {
                    dismiss()
                    Task {
                        await authManager.fetchAndUpdateUser()
                    }
                }
            } catch {
                await MainActor.run {
                    logger.error("Error saving user data: \(error.localizedDescription)")
                    showAlert(message: "Failed to save profile. Please try again.")
                }
            }
        }
    }

    private func uploadProfileImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            logger.error("Invalid image data.")
            completion(.failure(ProfileError.invalidImage))
            return
        }

        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("profile_images/\(viewModel.user?.id ?? UUID().uuidString).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let uploadTask = photoRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                logger.error("Storage upload error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            photoRef.downloadURL { url, error in
                if let error = error {
                    logger.error("Error getting download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let url = url {
                    logger.info("Image uploaded successfully: \(url.absoluteString)")
                    completion(.success(url.absoluteString))
                }
            }
        }

        uploadTask.observe(.progress) { snapshot in
            uploadProgress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

enum ProfileError: Error {
    case invalidImage
}
