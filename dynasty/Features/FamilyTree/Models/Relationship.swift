import Foundation
import FirebaseFirestore


struct Relationship: Identifiable, Codable {
    var id: String?
    let fromMemberID: String
    let toMemberID: String
    let type: RelationType
    
    init(fromMemberID: String, toMemberID: String, type: RelationType) {
        self.fromMemberID = fromMemberID
        self.toMemberID = toMemberID
        self.type = type
    }
}