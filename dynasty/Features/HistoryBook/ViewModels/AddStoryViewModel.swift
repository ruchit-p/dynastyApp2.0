import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine

class AddStoryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var uploadProgress: Double = 0
    
    private let db = FirestoreManager.shared.getDB()
    private let storage = Storage.storage()
    
    func createStory(title: String, content: String, images: [UIImage], privacy: String, familyTreeId: String, creatorUserId: String) async throws {
        await MainActor.run {
            self.isLoading = true
            self.uploadProgress = 0
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        do {
            // Upload images first
            var imageURLs: [String] = []
            for (index, image) in images.enumerated() {
                // Process image data in background
                let imageData = await Task.detached(priority: .userInitiated) { () -> Data? in
                    return image.jpegData(compressionQuality: 0.7)
                }.value
                
                guard let data = imageData else { continue }
                
                let imageURL = try await uploadImage(data, index: index, storyId: UUID().uuidString)
                imageURLs.append(imageURL)
                
                await MainActor.run {
                    self.uploadProgress = Double(index + 1) / Double(images.count)
                }
            }
            
            // Create story document
            let story = Story(
                id: nil,
                familyTreeID: familyTreeId,
                authorID: creatorUserId,
                coverImageURL: imageURLs.first,
                title: title,
                content: content,
                mediaURLs: imageURLs,
                eventDate: Date(),
                privacy: Story.PrivacyLevel(rawValue: privacy) ?? .inherited,
                category: .memory,
                location: nil,
                peopleInvolved: [],
                likes: [],
                tags: [],
                createdAt: nil,
                updatedAt: nil
            )
            
            // Perform Firestore write in background
            try await Task.detached(priority: .userInitiated) {
                let docRef = self.db.collection("stories").document()
                try docRef.setData(from: story)
            }.value
            
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    private func uploadImage(_ imageData: Data, index: Int, storyId: String) async throws -> String {
        let storageRef = storage.reference()
        let imageRef = storageRef.child("stories/\(storyId)/image\(index).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload with progress tracking
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let uploadTask = imageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    Task { @MainActor in
                        self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    }
                }
            }
        }
        
        // Get download URL after upload completes
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    func validateStory(title: String, content: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
} 
