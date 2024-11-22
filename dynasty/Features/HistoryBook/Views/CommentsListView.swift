import SwiftUI
import FirebaseAuth

struct CommentsListView: View {
    let historyBookId: String
    let storyId: String
    @State private var comments: [Comment] = []
    @State private var newCommentText = ""
    @State private var isLoading = false
    @State private var error: Error?
    private let commentService = CommentService()
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(comments) { comment in
                            CommentView(
                                comment: comment,
                                onLike: { likeComment(comment) },
                                onDelete: { deleteComment(comment) }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            // Comment input
            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: addComment) {
                    Text("Post")
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .onAppear {
            fetchComments()
        }
    }
    
    private func fetchComments() {
        isLoading = true
        commentService.fetchComments(for: storyId, in: historyBookId) { result in
            isLoading = false
            switch result {
            case .success(let fetchedComments):
                comments = fetchedComments
            case .failure(let fetchError):
                error = fetchError
            }
        }
    }
    
    private func addComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        commentService.addComment(
            to: storyId,
            in: historyBookId,
            content: newCommentText
        ) { result in
            switch result {
            case .success(let comment):
                comments.insert(comment, at: 0)
                newCommentText = ""
            case .failure(let error):
                self.error = error
            }
        }
    }
    
    private func likeComment(_ comment: Comment) {
        guard let commentId = comment.id else { return }
        
        commentService.toggleLike(
            on: commentId,
            in: storyId,
            historyBookId: historyBookId
        ) { result in
            if case .failure(let error) = result {
                self.error = error
            }
        }
    }
    
    private func deleteComment(_ comment: Comment) {
        guard let commentId = comment.id else { return }
        
        commentService.deleteComment(
            commentId,
            from: storyId,
            in: historyBookId
        ) { result in
            switch result {
            case .success:
                comments.removeAll { $0.id == commentId }
            case .failure(let error):
                self.error = error
            }
        }
    }
}