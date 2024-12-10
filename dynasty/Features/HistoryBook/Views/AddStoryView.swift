import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct AppError: Identifiable {
    let id = UUID()
    let message: String
}

struct AddStoryView: View {
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var privacy: Story.PrivacyLevel = .familyPublic
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var mediaURLs: [String] = []

    @State private var coverImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploading = false
    @State private var errorMessage: AppError?

    var historyBookID: String
    var familyTreeID: String

    var body: some View {
        NavigationView {
            VStack {
                // Cover Image Selection
                Button(action: {
                    showImagePicker = true
                }) {
                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                            Text("Tap to select a cover image")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: $coverImage)
                }

                // Title
                TextField("Title", text: $title)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)

                // Content (Markdown Editor)
                MarkdownTextView(text: $content, placeholder: "Write your story here...")
                    .frame(height: 200)
                    .padding(.horizontal)

                // Privacy Picker
                Picker("Privacy", selection: $privacy) {
                    Text("Public").tag(Story.PrivacyLevel.familyPublic)
                    Text("Private").tag(Story.PrivacyLevel.privateAccess)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                Spacer()
            }
            .navigationBarTitle("Add Story", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    addStory()
                }
                .disabled(isUploading || title.isEmpty || content.isEmpty)
            )
            .overlay(
                Group {
                    if isUploading {
                        ProgressView("Uploading...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            )
            .alert(item: $errorMessage) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func addStory() {
        isUploading = true
        errorMessage = nil

        if let image = coverImage {
            uploadImage(image) { result in
                switch result {
                case .success(let imageURL):
                    saveStoryData(coverImageURL: imageURL)
                case .failure(let error):
                    errorMessage = AppError(message: error.localizedDescription)
                    isUploading = false
                }
            }
        } else {
            // No cover image
            saveStoryData(coverImageURL: nil)
        }
    }

    private func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = Storage.storage().reference()
        let imageData = image.jpegData(compressionQuality: 0.8)
        let imageID = UUID().uuidString
        let imageRef = storageRef.child("stories/\(imageID).jpg")

        guard let data = imageData else {
            completion(.failure(NSError(domain: "Invalid image data", code: -1, userInfo: nil)))
            return
        }

        imageRef.putData(data, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                imageRef.downloadURL { url, error in
                    if let url = url {
                        completion(.success(url.absoluteString))
                    } else if let error = error {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func saveStoryData(coverImageURL: String?) {
        guard let currentUser = Auth.auth().currentUser else {
            print("User is not authenticated.")
            isUploading = false
            return
        }

        let db = Firestore.firestore()
        let storyID = UUID().uuidString
        let storyRef = db.collection(Constants.Firebase.historyBooksCollection)
            .document(historyBookID)
            .collection(Constants.Firebase.storiesSubcollection)
            .document(storyID)

        let story = Story(
            id: storyID,
            familyTreeID: familyTreeID,
            authorID: currentUser.uid,
            coverImageURL: coverImageURL,
            title: title,
            content: content,
            mediaURLs: mediaURLs,
            eventDate: selectedDate,
            privacy: privacy,
            category: nil,           // Provide default or actual value
            location: nil,           // Provide default or actual value
            peopleInvolved: [],      // Provide default or actual value
            likes: [],                // Provide default or actual value
            tags: [],                // Provide default or actual value
            createdAt: Date(),
            updatedAt: Date()
        )
        do {
            try storyRef.setData(from: story) { error in
                isUploading = false
                if let error = error {
                    self.errorMessage = AppError(message: "Error adding story: \(error.localizedDescription)")
                } else {
                    // Story saved successfully, now create a post
                    self.createPostFromStory(story: story)
                    dismiss()
                }
            }
        } catch {
            isUploading = false
            self.errorMessage = AppError(message: "Error encoding story data: \(error.localizedDescription)")
        }
    }

    private func createPostFromStory(story: Story) {
        // Fetch username if needed, or store it in the story creation process
        // For now, assume we have a method to get the current user’s displayName:
        let username = Auth.auth().currentUser?.displayName ?? "Unknown User"

        let caption = String(story.content.prefix(400))
        let db = Firestore.firestore()
        let postRef = db.collection("posts").document()

        let post = Post(
            username: username,
            date: Timestamp(date: story.createdAt ?? Date()),
            caption: caption,
            imageURL: story.coverImageURL,
            timestamp: Timestamp(date: Date())
        )

        do {
            try postRef.setData(from: post)
        } catch {
            print("Failed to create post from story: \(error.localizedDescription)")
        }
    }
} 
