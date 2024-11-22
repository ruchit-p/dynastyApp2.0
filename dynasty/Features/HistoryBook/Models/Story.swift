import Foundation
import FirebaseFirestore

struct Location: Codable {
    var latitude: Double
    var longitude: Double
    var name: String?
}

enum StoryCategory: String, Codable {
    case memory = "memory"
    case milestone = "milestone"
    case tradition = "tradition"
    case recipe = "recipe"
    case other = "other"
}

struct Story: Identifiable, Codable {
    @DocumentID var id: String?
    var familyTreeID: String
    var authorID: String
    var coverImageURL: String?
    var title: String
    var content: String
    var mediaURLs: [String]
    var eventDate: Date
    var privacy: PrivacyLevel
    var category: StoryCategory?
    var location: Location?
    var peopleInvolved: [String]? // Array of family member IDs
    var likes: [String]?
    var tags: [String]?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    
    enum PrivacyLevel: String, Codable {
        case inherited = "inherited" // Uses history book's privacy
        case familyPublic = "familyPublic" // Visible to all family members
        case privateAccess = "private"    // Only visible to creator
        
        static var `default`: PrivacyLevel { .inherited }
    }
} 
