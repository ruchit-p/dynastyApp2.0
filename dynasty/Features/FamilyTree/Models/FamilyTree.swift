import Foundation
import FirebaseFirestore

struct FamilyTree: Codable, Identifiable {
    @DocumentID var id: String?
    var ownerUserID: String
    var admins: [String]
    var members: [String]
    var name: String
    var locked: Bool
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID
        case admins
        case members
        case name
        case locked
        case createdAt
        case updatedAt
    }
    
    init(id: String? = nil,
         ownerUserID: String,
         admins: [String],
         members: [String],
         name: String,
         locked: Bool,
         createdAt: Timestamp? = nil,
         updatedAt: Timestamp? = nil) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.admins = admins
        self.members = members
        self.name = name
        self.locked = locked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        ownerUserID = try container.decode(String.self, forKey: .ownerUserID)
        admins = try container.decode([String].self, forKey: .admins)
        members = try container.decodeIfPresent([String].self, forKey: .members) ?? []
        name = try container.decode(String.self, forKey: .name)
        locked = try container.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Timestamp.self, forKey: .updatedAt)
    }
}
