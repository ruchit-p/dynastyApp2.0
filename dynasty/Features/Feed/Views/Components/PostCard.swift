import SwiftUI

struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let imageURL = post.imageURL {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray
                    case .empty:
                        ProgressView()
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Username and date
            HStack {
                Text(post.username)
                    .font(.headline)
                Text(post.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Caption
            Text(post.caption)
                .font(.body)
                .lineLimit(3)
        }
    }
} 