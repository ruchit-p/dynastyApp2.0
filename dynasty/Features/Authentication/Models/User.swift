import FirebaseFirestore
import Foundation

/// Represent the gender of the user.
/// Using an enum provides type safety and reduces the risk of invalid strings.
enum Gender: String, Codable {
    case male
    case female
    case nonBinary
    case other
}

/// Represent the user's role within the system.
/// You can expand this as needed.
enum UserRole: String, Codable {
    case admin
    case owner
    case member
}

/// A model representing a user in the Dynasty app.
/// This model stores personal information, relationships, roles, and metadata about the user.
struct User: Codable, Identifiable {
    // MARK: - Identity
    
    /// The unique Firestore document ID for the user.
    @DocumentID var id: String?
    
    /// The user's email address.
    /// Consider validating email addresses before saving.
    var email: String?
    
    /// The user's given (first) name.
    var firstName: String?
    
    /// The user's family (last) name.
    var lastName: String?
    
    /// The user's date of birth.
    var dateOfBirth: Date?
    
    /// The user's gender.
    /// This field can help personalize the user experience.
    var gender: Gender?
    
    /// The user's phone number as a string.
    /// Use a validation library (e.g., PhoneNumberKit) before saving this to ensure it's in a proper format.
    var phoneNumber: String?
    
    /// A country code or identifier for the user's country.
    /// Use a library or validation logic to ensure this is valid (e.g., ISO 3166-1 alpha-2 code).
    var country: String?
    
    // MARK: - Family and Relationships
    
    /// The family tree document ID this user belongs to.
    /// Retaining as String for now.
    var familyTreeID: String?
    
    /// The history book document ID this user belongs to.
    /// Retaining as String for now.
    var historyBookID: String?
    
    /// The user's parent IDs.
    /// Stored as String IDs. Consider fetching related documents as needed.
    var parentIds: [String] = []
    
    /// The user's child IDs.
    var childIds: [String] = []
    
    /// The user's spouse ID.
    var spouseId: String?
    
    /// The user's sibling IDs.
    var siblingIds: [String] = []
    
    // MARK: - Roles and Permissions
    
    /// The user's role within the system.
    /// This can simplify permission checks.
    var role: UserRole = .member
    
    /// Indicates whether the user can add members.
    var canAddMembers: Bool = false
    
    /// Indicates whether the user can edit family details.
    var canEdit: Bool = false
    
    // MARK: - Media
    
    /// A URL string pointing to the user's profile photo in storage.
    var photoURL: String?
    
    // MARK: - Metadata
    
    /// Timestamp when the user was created (set by Firestore).
    @ServerTimestamp var createdAt: Timestamp?
    
    /// Timestamp when the user was last updated (set by Firestore).
    @ServerTimestamp var updatedAt: Timestamp?
    
    // MARK: - Computed Properties
    
    /// A computed property that returns the user's display name.
    /// Prioritizes firstName and lastName. If both exist, returns "firstName lastName".
    /// If only one is available, returns that one. If neither, returns a fallback string.
    var displayName: String {
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName {
            return firstName
        } else if let lastName = lastName {
            return lastName
        } else {
            return "Unknown"
        }
    }
    
    /// Indicates whether this user is considered "registered" (has an ID and email).
    var isRegisteredUser: Bool {
        return id != nil && email != nil
    }
    
    // MARK: - Initialization
    
    /// Creates a new `User` instance.
    /// Consider using a Builder or specialized initializers if complexity grows.
    init(
        id: String? = nil,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        dateOfBirth: Date? = nil,
        gender: Gender? = nil,
        phoneNumber: String? = nil,
        country: String? = nil,
        photoURL: String? = nil,
        familyTreeID: String? = nil,
        historyBookID: String? = nil,
        parentIds: [String] = [],
        childIds: [String] = [],
        spouseId: String? = nil,
        siblingIds: [String] = [],
        role: UserRole = .member,
        canAddMembers: Bool = false,
        canEdit: Bool = false,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.phoneNumber = phoneNumber
        self.country = country
        self.photoURL = photoURL
        self.familyTreeID = familyTreeID
        self.historyBookID = historyBookID
        self.parentIds = parentIds
        self.childIds = childIds
        self.spouseId = spouseId
        self.siblingIds = siblingIds
        self.role = role
        self.canAddMembers = canAddMembers
        self.canEdit = canEdit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from node: FamilyTreeNode) {
        self.id = node.id
        self.email = node.email
        self.firstName = node.firstName
        self.lastName = node.lastName
        self.dateOfBirth = node.dateOfBirth
        self.gender = node.gender
        self.phoneNumber = node.phoneNumber
        self.photoURL = node.photoURL
        self.familyTreeID = nil // Set this based on your needs
        self.historyBookID = nil
        self.parentIds = node.parentIds
        self.childIds = node.childrenIds
        self.spouseId = node.spouseIds.first
        self.siblingIds = []
        self.role = .member
        self.canAddMembers = false
        self.canEdit = node.canEdit
        self.createdAt = nil
        self.updatedAt = node.updatedAt
    }
    
    // MARK: - Codable
    
    /// Coding keys for encoding/decoding the User object.
    /// Adjust these if field names differ in Firestore.
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName
        case lastName
        case dateOfBirth
        case gender
        case phoneNumber
        case country
        case familyTreeID
        case historyBookID
        case parentIds
        case childIds
        case spouseId
        case siblingIds
        case role
        case canAddMembers
        case canEdit
        case photoURL
        case createdAt
        case updatedAt
    }
}
