import Foundation
import FirebaseFirestore

/// A model representing a user in the Dynasty app.
/// This model contains all essential user information and permissions.
struct User: Codable, Identifiable, Equatable {
    // MARK: - Core Properties
    /// Unique identifier for the user, typically from Firebase Auth
    @DocumentID var id: String?
    
    /// User's display name, shown in the UI
    var displayName: String
    
    /// User's email address, used for authentication and communication
    var email: String
    
    /// User's date of birth, used for age verification and features
    var dateOfBirth: Date?
    
    // MARK: - Personal Information
    /// User's first name
    var firstName: String?
    
    /// User's last name
    var lastName: String?
    
    /// User's phone number for contact and verification
    var phoneNumber: String?
    
    // MARK: - Family Tree Information
    /// ID of the family tree this user belongs to
    var familyTreeID: String?
    
    /// ID of the history book associated with this user
    var historyBookID: String?
    
    /// IDs of parent users in the family tree
    var parentIds: [String]
    
    /// IDs of children users in the family tree
    var childrenIds: [String]
    
    // MARK: - Permissions
    /// Whether the user has admin privileges
    var isAdmin: Bool
    
    /// Whether the user can add new members to the family tree
    var canAddMembers: Bool
    
    /// Whether the user can edit existing family tree information
    var canEdit: Bool
    
    // MARK: - Media
    /// URL to the user's profile photo
    var photoURL: String?
    
    // MARK: - Timestamps
    /// When the user account was created
    @ServerTimestamp var createdAt: Timestamp?
    
    /// When the user information was last updated
    @ServerTimestamp var updatedAt: Timestamp?
    
    // MARK: - Initialization
    /// Creates a new User instance with the specified properties
    /// - Parameters:
    ///   - id: Optional unique identifier
    ///   - displayName: User's display name
    ///   - email: User's email address
    ///   - dateOfBirth: Optional date of birth
    ///   - firstName: Optional first name
    ///   - lastName: Optional last name
    ///   - phoneNumber: Optional phone number
    ///   - familyTreeID: Optional ID of associated family tree
    ///   - historyBookID: Optional ID of associated history book
    ///   - parentIds: Array of parent user IDs
    ///   - childrenIds: Array of child user IDs
    ///   - isAdmin: Whether user has admin privileges
    ///   - canAddMembers: Whether user can add new members
    ///   - canEdit: Whether user can edit information
    ///   - photoURL: Optional URL to profile photo
    ///   - createdAt: Optional creation timestamp
    ///   - updatedAt: Optional last update timestamp
    init(id: String? = nil,
         displayName: String,
         email: String,
         dateOfBirth: Date? = nil,
         firstName: String? = nil,
         lastName: String? = nil,
         phoneNumber: String? = nil,
         familyTreeID: String? = nil,
         historyBookID: String? = nil,
         parentIds: [String] = [],
         childrenIds: [String] = [],
         isAdmin: Bool = false,
         canAddMembers: Bool = false,
         canEdit: Bool = true,
         photoURL: String? = nil,
         createdAt: Timestamp? = nil,
         updatedAt: Timestamp? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.dateOfBirth = dateOfBirth
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumber = phoneNumber
        self.familyTreeID = familyTreeID
        self.historyBookID = historyBookID
        self.parentIds = parentIds
        self.childrenIds = childrenIds
        self.isAdmin = isAdmin
        self.canAddMembers = canAddMembers
        self.canEdit = canEdit
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id &&
        lhs.displayName == rhs.displayName &&
        lhs.email == rhs.email &&
        lhs.dateOfBirth == rhs.dateOfBirth &&
        lhs.firstName == rhs.firstName &&
        lhs.lastName == rhs.lastName &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.familyTreeID == rhs.familyTreeID &&
        lhs.historyBookID == rhs.historyBookID &&
        lhs.parentIds == rhs.parentIds &&
        lhs.childrenIds == rhs.childrenIds &&
        lhs.isAdmin == rhs.isAdmin &&
        lhs.canAddMembers == rhs.canAddMembers &&
        lhs.canEdit == rhs.canEdit &&
        lhs.photoURL == rhs.photoURL &&
        lhs.createdAt?.seconds == rhs.createdAt?.seconds &&
        lhs.updatedAt?.seconds == rhs.updatedAt?.seconds
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case email
        case dateOfBirth
        case firstName
        case lastName
        case phoneNumber
        case familyTreeID
        case historyBookID
        case parentIds
        case childrenIds
        case isAdmin
        case canAddMembers
        case canEdit
        case photoURL
        case createdAt
        case updatedAt
    }
    
    /// Converts the User model to a dictionary for Firestore storage
    /// - Returns: Dictionary containing all user properties in a format suitable for Firestore
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id ?? "",
            "displayName": displayName,
            "email": email,
            "dateOfBirth": dateOfBirth ?? Date(),
            "firstName": firstName ?? "",
            "lastName": lastName ?? "",
            "phoneNumber": phoneNumber ?? "",
            "familyTreeID": familyTreeID ?? "",
            "historyBookID": historyBookID ?? "",
            "parentIds": parentIds,
            "childrenIds": childrenIds,
            "isAdmin": isAdmin,
            "canAddMembers": canAddMembers,
            "canEdit": canEdit,
            "photoURL": photoURL ?? "",
            "createdAt": createdAt ?? Timestamp(),
            "updatedAt": updatedAt ?? Timestamp()
        ]
        return dict
    }
}
