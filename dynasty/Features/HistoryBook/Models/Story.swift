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
    
    enum PrivacyLevel: String, Codable, CaseIterable {
        case familyPublic = "familyPublic"
        case familyPrivate = "familyPrivate"
    }
}

// Represents a single element within the story content
struct ContentElement: Identifiable, Codable {
    var id: String
    var type: ContentType
    var value: String
    var format: TextFormat?

    enum ContentType: String, Codable {
        case text, image, video, audio
    }

    struct TextFormat: Codable {
        var isBold: Bool = false
        var isItalic: Bool = false
        var isUnderlined: Bool = false
        var highlightColor: String?
        var textColor: String?
        var alignment: TextAlignment = .leading
    }

    enum TextAlignment: String, Codable {
        case leading, center, trailing
    }
} 
