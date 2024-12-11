import SwiftUI
import FirebaseFirestore
import Combine

class StoryDetailViewModel: ObservableObject {
    @Published var story: Story?
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    init(story: Story? = nil) {
        self.story = story
    }
    
    func fetchStory(storyId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let document = try await db.collection("stories").document(storyId).getDocument()
            if let story = try? document.data(as: Story.self) {
                await MainActor.run {
                    self.story = story
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func fetchComments(storyId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("stories")
                .document(storyId)
                .collection("comments")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            await MainActor.run {
                self.comments = snapshot.documents.compactMap { try? $0.data(as: Comment.self) }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func addComment(_ comment: Comment, to storyId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let docRef = db.collection("stories")
                .document(storyId)
                .collection("comments")
                .document()
            
            try await docRef.setData(from: comment)
            await fetchComments(storyId: storyId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func deleteComment(_ commentId: String, from storyId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("stories")
                .document(storyId)
                .collection("comments")
                .document(commentId)
                .delete()
            
            await fetchComments(storyId: storyId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func updateStoryPrivacy(storyId: String, isPrivate: Bool) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("stories")
                .document(storyId)
                .updateData([
                    "privacy": isPrivate ? "private" : "public",
                    "updatedAt": Timestamp()
                ])
            
            await fetchStory(storyId: storyId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 