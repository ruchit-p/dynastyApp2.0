import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StoryDetailView: View {
    let story: Story
    let historyBookId: String
    @State private var showingShareSheet = false
    @State private var isLiked: Bool = false
    @State private var localLikes: [String] = []
    @Environment(\.dismiss) private var dismiss
    let db = Firestore.firestore()
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Cover Image
                if let coverImageURL = story.coverImageURL, let url = URL(string: coverImageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    .clipped()
                }
                
                // Story Title
                Text(story.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Rendered Markdown Content
                Text(tryAttributedString(from: story.content))
                    .padding(.horizontal)
                
                // Like and Share buttons
                HStack {
                    Button(action: toggleLike) {
                        HStack {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .gray)
                            if !localLikes.isEmpty {
                                Text("\(localLikes.count)")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical)
                
                // Comments section
                CommentsListView(historyBookId: historyBookId, storyId: story.id ?? "")
            }
            .padding(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [story.title, story.content])
        }
        .onAppear {
            setupLikesListener()
        }
    }
    
    private func setupLikesListener() {
        guard let storyId = story.id else { return }
        
        db.collection("stories").document(storyId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching story: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.localLikes = document.data()?["likes"] as? [String] ?? []
                self.isLiked = self.localLikes.contains(self.currentUserId)
            }
    }
    
    private func toggleLike() {
        guard let storyId = story.id else { return }
        let storyRef = db.collection("stories").document(storyId)
        
        if isLiked {
            storyRef.updateData([
                "likes": FieldValue.arrayRemove([currentUserId])
            ]) { error in
                if let error = error {
                    print("Error removing like: \(error.localizedDescription)")
                }
            }
        } else {
            storyRef.updateData([
                "likes": FieldValue.arrayUnion([currentUserId])
            ]) { error in
                if let error = error {
                    print("Error adding like: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func tryAttributedString(from markdown: String) -> AttributedString {
        do {
            return try AttributedString(markdown: markdown)
        } catch {
            print("Error parsing Markdown: \(error.localizedDescription)")
            return AttributedString(markdown)
        }
    }
}