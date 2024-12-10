import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import OSLog

struct UserProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var user: User
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phoneNumber: String
    let db = Firestore.firestore()
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
        self._user = State(initialValue: currentUser)
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
                        } else if let photoURL = user.photoURL, let url = URL(string: photoURL) {
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
        }
    }

    private func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid else {
            logger.error("User not authenticated.")
            showAlert(message: "User not authenticated.")
            return
        }
        let userRef = db.collection("users").document(uid)

        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phoneNumber = phoneNumber

        if let selectedImage = selectedImage {
            isUploading = true
            uploadProfileImage(image: selectedImage) { result in
                isUploading = false
                switch result {
                case .success(let photoURL):
                    self.user.photoURL = photoURL
                    self.saveUserData(userRef: userRef)
                case .failure(let error):
                    logger.error("Image upload failed: \(error.localizedDescription)")
                    showAlert(message: "Failed to upload image. Please try again.")
                }
            }
        } else {
            saveUserData(userRef: userRef)
        }
    }

    private func saveUserData(userRef: DocumentReference) {
        do {
            try userRef.setData(from: user) { error in
                if let error = error {
                    logger.error("Error saving user data: \(error.localizedDescription)")
                    showAlert(message: "Failed to save profile. Please try again.")
                } else {
                    logger.info("User data saved successfully.")
                    dismiss()
                    Task {
                        await authManager.fetchAndUpdateUser()
                    }
                }
            }
        } catch {
            logger.error("Error encoding user data: \(error.localizedDescription)")
            showAlert(message: "Failed to save profile. Please try again.")
        }
    }

    private func uploadProfileImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            logger.error("Invalid image data.")
            completion(.failure(ProfileError.invalidImage))
            return
        }

        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("profile_images/\(user.id ?? UUID().uuidString).jpg")

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

    func loadImage() {
        guard let selectedImage = selectedImage else { return }
        logger.info("Image selected for profile.")
        // Update the UI or model as needed
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

enum ProfileError: Error {
    case invalidImage
}
