import Foundation
import FirebaseFirestore

struct HistoryBook: Identifiable, Codable {
    @DocumentID var id: String?
    var ownerUserID: String
    var familyTreeID: String
    var title: String
    var description: String?
    var privacy: PrivacyLevel
    var coverImageURL: String?
    var collaborators: [String]? // Array of family member IDs who can edit
    var viewCount: Int?
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    
    enum PrivacyLevel: String, Codable {
        case familyPublic = "familyPublic"  // Visible to all family members
        case privateAccess = "private"    // Only visible to owner
        
        static var `default`: PrivacyLevel { .familyPublic }
    }
    
    init(id: String? = nil,
         ownerUserID: String, 
         familyTreeID: String,
         title: String = "My Family History",
         privacy: PrivacyLevel = .familyPublic) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.familyTreeID = familyTreeID
        self.title = title
        self.privacy = privacy
    }
} 
