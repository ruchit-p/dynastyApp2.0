import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    var userID: String
    var content: String
    var authorName: String
    var authorImageURL: String?
    var likes: [String]?  // Array of userIDs who liked the comment
    var mentions: [String]?  // Array of mentioned userIDs
    var attachments: [String]?  // Array of attachment URLs
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    
    // For threaded comments (optional)
    var parentCommentId: String?
    var replyCount: Int?
}

extension Comment: Equatable, Hashable {
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
