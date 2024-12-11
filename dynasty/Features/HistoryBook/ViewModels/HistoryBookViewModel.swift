import SwiftUI
import FirebaseFirestore
import Combine

class HistoryBookViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    func fetchStories(familyTreeID: String, currentUserId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch public stories
            let publicSnapshot = try await db.collection("stories")
                .whereField("familyTreeID", isEqualTo: familyTreeID)
                .whereField("privacy", isEqualTo: "public")
                .getDocuments()
            
            // Fetch user's private stories
            let privateSnapshot = try await db.collection("stories")
                .whereField("creatorUserID", isEqualTo: currentUserId)
                .whereField("privacy", isEqualTo: "private")
                .getDocuments()
            
            var allStories: [Story] = []
            
            // Add public stories
            allStories.append(contentsOf: publicSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            
            // Add private stories
            allStories.append(contentsOf: privateSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            
            // Sort combined results by creation date
            await MainActor.run {
                self.stories = allStories.sorted(by: { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) })
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func addStory(_ story: Story) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let docRef = db.collection("stories").document()
            try await docRef.setData(from: story)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func updateStory(_ story: Story) async throws {
        guard let storyId = story.id else {
            throw NSError(domain: "HistoryBook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid story ID"])
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("stories").document(storyId).setData(from: story)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func deleteStory(_ storyId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("stories").document(storyId).delete()
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 