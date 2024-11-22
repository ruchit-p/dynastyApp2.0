import SwiftUI

struct CommentView: View {
    let comment: Comment
    let onLike: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author info
            HStack {
                if let imageURL = comment.authorImageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .foregroundColor(.gray)
                        .frame(width: 40, height: 40)
                }
                
                VStack(alignment: .leading) {
                    Text(comment.authorName)
                        .font(.headline)
                    if let date = comment.createdAt {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(role: .destructive, action: {
                        showDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            // Comment content
            Text(comment.content)
                .font(.body)
            
            // Likes and replies
            HStack {
                Button(action: onLike) {
                    HStack {
                        Image(systemName: comment.likes?.isEmpty == false ? "heart.fill" : "heart")
                            .foregroundColor(comment.likes?.isEmpty == false ? .red : .gray)
                        if let likeCount = comment.likes?.count, likeCount > 0 {
                            Text("\(likeCount)")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                if let replyCount = comment.replyCount, replyCount > 0 {
                    Text("·")
                        .foregroundColor(.gray)
                    Text("\(replyCount) replies")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
        .alert("Delete Comment", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
}