import Foundation
import FirebaseFirestore

struct FamilyTree: Codable, Identifiable {
    @DocumentID var id: String?
    var ownerUserID: String
    var admins: [String]
    var members: [String]?
    var name: String
    var locked: Bool
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
}
