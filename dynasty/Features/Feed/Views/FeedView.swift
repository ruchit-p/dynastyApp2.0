import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var stories: [Story] = []
    @State private var user: User?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.posts) { post in
                        PostCard(post: post)
                    }
                }
                .padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Feed")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Share action */ }) {
                        Image(systemName: "paperplane")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .withPlusButton {
            // Action for plus button
            print("Plus button tapped in FeedView")
        }
        .onAppear {
            fetchUserAndStories()
        }
    }
    
    func fetchUserAndStories() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        // Fetch user data to get familyTreeID
        db.collection("users").document(currentUser.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                do {
                    let fetchedUser = try document.data(as: User.self)
                    self.user = fetchedUser
                    
                    guard let familyTreeID = fetchedUser.familyTreeID else {
                        print("No familyTreeID found for user.")
                        return
                    }

                    fetchStories(familyTreeID: familyTreeID)
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func fetchStories(familyTreeID: String) {
        let db = Firestore.firestore()
        
        // Get current user
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Fetch public stories
        let publicStoriesQuery = db.collection("stories")
            .whereField("familyTreeID", isEqualTo: familyTreeID)
            .whereField("privacy", isEqualTo: "public")
        
        // Fetch user's private stories
        let privateStoriesQuery = db.collection("stories")
            .whereField("creatorUserID", isEqualTo: currentUser.uid)
            .whereField("privacy", isEqualTo: "private")
        
        // Since Firestore doesn't support union directly, we'll fetch both queries separately
        // and combine the results in memory
        publicStoriesQuery.getDocuments { publicSnapshot, publicError in
            if let publicError = publicError {
                print("Error fetching public stories: \(publicError.localizedDescription)")
                return
            }
            
            privateStoriesQuery.getDocuments { privateSnapshot, privateError in
                if let privateError = privateError {
                    print("Error fetching private stories: \(privateError.localizedDescription)")
                    return
                }
                
                // Combine the results
                var allStories: [Story] = []
                
                // Add public stories
                if let publicDocs = publicSnapshot?.documents {
                    allStories.append(contentsOf: publicDocs.compactMap { try? $0.data(as: Story.self) })
                }
                
                // Add private stories
                if let privateDocs = privateSnapshot?.documents {
                    allStories.append(contentsOf: privateDocs.compactMap { try? $0.data(as: Story.self) })
                }
                
                // Sort combined results by creation date
                self.stories = allStories.sorted(by: { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) })
            }
        }
    }
}

#Preview {
    FeedView()
}
