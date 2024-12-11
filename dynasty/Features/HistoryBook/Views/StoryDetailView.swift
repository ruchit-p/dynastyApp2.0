import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StoryDetailView: View {
    @StateObject private var viewModel: StoryDetailViewModel
    let historyBookId: String
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init(story: Story, historyBookId: String) {
        self.historyBookId = historyBookId
        self._viewModel = StateObject(wrappedValue: StoryDetailViewModel(story: story))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                } else if let story = viewModel.story {
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
                                Image(systemName: story.likes?.contains(currentUserId) ?? false ? "heart.fill" : "heart")
                                    .foregroundColor(story.likes?.contains(currentUserId) ?? false ? .red : .gray)
                                if let likes = story.likes, !likes.isEmpty {
                                    Text("\(likes.count)")
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
                    CommentsSection(viewModel: viewModel, storyId: story.id ?? "")
                }
            }
            .padding(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let story = viewModel.story {
                ShareSheet(activityItems: [story.title, story.content])
            }
        }
        .onAppear {
            if let storyId = viewModel.story?.id {
                Task {
                    await viewModel.fetchStory(storyId: storyId)
                    await viewModel.fetchComments(storyId: storyId)
                }
            }
        }
    }
    
    private func toggleLike() {
        guard let storyId = viewModel.story?.id else { return }
        
        Task {
            do {
                try await viewModel.updateStoryPrivacy(storyId: storyId, isPrivate: !(viewModel.story?.likes?.contains(currentUserId) ?? false))
            } catch {
                // Error is handled by ViewModel
                print("Error toggling like: \(error.localizedDescription)")
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

struct CommentsSection: View {
    @ObservedObject var viewModel: StoryDetailViewModel
    let storyId: String
    @State private var newComment: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(viewModel.comments) { comment in
                CommentRow(comment: comment) {
                    if let commentId = comment.id {
                        Task {
                            try? await viewModel.deleteComment(commentId, from: storyId)
                        }
                    }
                }
            }
            
            HStack {
                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Post") {
                    submitComment()
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
        }
    }
    
    private func submitComment() {
        guard !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let comment = Comment(
            userID: Auth.auth().currentUser?.uid ?? "",
            content: newComment,
            authorName: Auth.auth().currentUser?.displayName ?? "Anonymous",
            authorImageURL: Auth.auth().currentUser?.photoURL?.absoluteString,
            likes: [],
            mentions: nil,
            attachments: nil
        )
        
        Task {
            do {
                try await viewModel.addComment(comment, to: storyId)
                newComment = ""
            } catch {
                // Error is handled by ViewModel
                print("Error adding comment: \(error.localizedDescription)")
            }
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorName)
                    .font(.headline)
                Spacer()
                if comment.userID == Auth.auth().currentUser?.uid {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            Text(comment.content)
                .font(.body)
            if let createdAt = comment.createdAt {
                Text(createdAt.formatted())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}