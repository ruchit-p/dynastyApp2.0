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
    
    // Logger for error and event tracking
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
            Form {
                // Avatar Section
                Section(header: Text("Profile Picture")) {
                    VStack {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .clipShape(Circle())
                        } else if let user = viewModel.user, let photoURL = user.photoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 150, height: 150)
                        }

                        Button("Change Profile Picture") {
                            isShowingImagePicker = true
                        }
                        
                        if isUploading {
                            ProgressView("Uploading", value: uploadProgress, total: 1.0)
                        }
                    }
                }
                
                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveChanges()
                }
            )
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
