import SwiftUI
import Combine
import FirebaseFirestore

class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    private let db = Firestore.firestore()
    
    init() {
        loadPosts()
    }
    
    private func loadPosts() {
        // Example data - replace with your actual data source
        posts = [
            Post(
                username: "Ruchtp",
                date: Timestamp(date: Date()),
                caption: "Introducing the newest addition to the family, Rovely the Labrador!",
                imageURL: "your-image-url",
                timestamp: Timestamp(date: Date())
            )
        ]
        
        // Fetch actual posts from Firestore
        fetchPostsFromFirestore()
    }
    
    private func fetchPostsFromFirestore() {
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching posts: \(error.localizedDescription)")
                    return
                }

                let fetchedPosts = snapshot?.documents.compactMap { document in
                    try? document.data(as: Post.self)
                } ?? []

                DispatchQueue.main.async {
                    self?.posts = fetchedPosts
                }
            }
    }
} 