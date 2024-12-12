import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import Combine
import PhotosUI

class AddStoryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var uploadProgress: Double = 0
    @Published var contentElements: [ContentElement] = []
    
    private let db = FirestoreManager.shared.getDB()
    private let storage = Storage.storage()
    
    func createStory(title: String, content: String, privacy: String, familyTreeId: String, creatorUserId: String) async throws {
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
            // 1. Create content JSON string
            let contentJSON = try createContentJSON()

            // 2. Create Story object
            let newStory = Story(
                familyTreeID: familyTreeId,
                authorID: creatorUserId,
                title: title,
                content: content,
                mediaURLs: [],
                eventDate: Date(),
                privacy: Story.PrivacyLevel(rawValue: privacy) ?? .familyPublic
            )

            // 3. Upload to Firestore
            let docRef = db.collection("stories").document()
            try await docRef.setData(from: newStory)

        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    private func createContentJSON() throws -> String {
        let contentData = try JSONEncoder().encode(["elements": contentElements])
        guard let contentJSON = String(data: contentData, encoding: .utf8) else {
            throw NSError(domain: "AddStoryViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create content JSON"])
        }
        return contentJSON
    }
    
    func uploadMedia(item: PhotosPickerItem, index: Int, storyId: String) async throws -> String {
        // Determine media type and get data
        let (mediaData, fileExtension) = try await getMediaData(from: item)

        // Create storage reference
        let storageRef = storage.reference()
        let mediaRef = storageRef.child("stories/\(storyId)/media\(index).\(fileExtension)")

        // Upload with progress tracking
        let metadata = StorageMetadata()
        metadata.contentType = item.supportedContentTypes.first?.preferredMIMEType

        // Upload the media data
        let uploadTask = mediaRef.putData(mediaData, metadata: metadata)
        
        // Add progress observer
        uploadTask.observe(.progress) { [weak self] snapshot in
            Task { @MainActor in
                let percentComplete = Double(snapshot.progress?.fractionCompleted ?? 0)
                self?.uploadProgress = percentComplete
            }
        }
        
        // Wait for completion
        _ = try await uploadTask.snapshot

        // Get the download URL and return it
        let downloadURL = try await mediaRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    private func getMediaData(from item: PhotosPickerItem) async throws -> (Data, String) {
        if let imageData = try await item.loadTransferable(type: Data.self) {
            return (imageData, "jpg")
        } else if let videoURL = try await item.loadTransferable(type: URL.self), videoURL.isFileURL {
            let videoData = try Data(contentsOf: videoURL)
            let fileExtension = videoURL.pathExtension
            return (videoData, fileExtension)
        } else {
            throw NSError(domain: "AddStoryViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unsupported media type"])
        }
    }
    
    func validateStory(title: String, content: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func addTextElement(text: String) {
        let element = ContentElement(id: UUID().uuidString, type: .text, value: text)
        contentElements.append(element)
    }
    
    func addImageElement(imageURL: String) {
        let element = ContentElement(id: UUID().uuidString, type: .image, value: imageURL)
        contentElements.append(element)
    }
    
    func addVideoElement(videoURL: String) {
        let element = ContentElement(id: UUID().uuidString, type: .video, value: videoURL)
        contentElements.append(element)
    }
    
    func addAudioElement(audioURL: String) {
        let element = ContentElement(id: UUID().uuidString, type: .audio, value: audioURL)
        contentElements.append(element)
    }
} 
