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
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Upload images first
            var imageURLs: [String] = []
            for (index, image) in images.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.7) else { continue }
                let imageURL = try await uploadImage(imageData, index: index, storyId: UUID().uuidString)
                imageURLs.append(imageURL)
                
                await MainActor.run {
                    uploadProgress = Double(index + 1) / Double(images.count)
                }
            }
            
            // Create story document
            let story = Story(
                id: nil, // Firestore will generate this
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
                createdAt: nil, // Firestore will set this
                updatedAt: nil  // Firestore will set this
            )
            
            let docRef = db.collection("stories").document()
            try docRef.setData(from: story)
            
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
        
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata) { progress in
            if let progress = progress {
                Task { @MainActor in
                    self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                }
            }
        }
        
        let downloadURL = try await imageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    func validateStory(title: String, content: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
} 
