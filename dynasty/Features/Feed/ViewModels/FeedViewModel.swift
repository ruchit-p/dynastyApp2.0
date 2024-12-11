import SwiftUI
import Combine
import FirebaseFirestore

class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    private let db = FirestoreManager.shared.getDB()
    
    init() {
        loadPosts()
    }
    
    func loadPosts() {
        isLoading = true
        fetchPostsFromFirestore()
    }
    
    private func fetchPostsFromFirestore() {
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let error = error {
                        self?.error = error
                        return
                    }

                    self?.posts = snapshot?.documents.compactMap { document in
                        try? document.data(as: Post.self)
                    } ?? []
                }
            }
    }
    
    func addPost(post: Post) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let docRef = db.collection("posts").document()
            try await docRef.setData(from: post)
            await MainActor.run {
                loadPosts()
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func deletePost(postId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("posts").document(postId).delete()
            await MainActor.run {
                loadPosts()
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func updatePost(postId: String, updatedData: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("posts").document(postId).updateData(updatedData)
            await MainActor.run {
                loadPosts()
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 