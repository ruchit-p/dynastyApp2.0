import Foundation
import FirebaseFirestore

struct FamilyTreeNode: Identifiable, Codable, Equatable {
    let id: String
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    var gender: Gender
    var email: String?
    var phoneNumber: String?
    var photoURL: String?
    var parentIds: [String]
    var spouseIds: [String]
    var childrenIds: [String]
    var generation: Int
    var isRegisteredUser: Bool
    var canEdit: Bool
    var updatedAt: Timestamp
    
    init(
        id: String,
        firstName: String,
        lastName: String,
        dateOfBirth: Date? = nil,
        gender: Gender,
        email: String?,
        phoneNumber: String?,
        photoURL: String?,
        parentIds: [String],
        childrenIds: [String],
        spouseIds: [String],
        generation: Int,
        isRegisteredUser: Bool,
        canEdit: Bool,
        updatedAt: Timestamp
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
        self.parentIds = parentIds
        self.childrenIds = childrenIds
        self.spouseIds = spouseIds
        self.generation = generation
        self.isRegisteredUser = isRegisteredUser
        self.canEdit = canEdit
        self.updatedAt = updatedAt
    }
    
    init(from user: User) {
        self.id = user.id ?? UUID().uuidString
        self.firstName = user.firstName ?? ""
        self.lastName = user.lastName ?? ""
        self.dateOfBirth = user.dateOfBirth
        self.gender = user.gender ?? .other
        self.email = user.email
        self.phoneNumber = user.phoneNumber
        self.photoURL = user.photoURL
        self.parentIds = user.parentIds
        self.childrenIds = user.childIds
        self.spouseIds = [user.spouseId].compactMap { $0 }
        self.generation = 0  // Default value, can be calculated later
        self.isRegisteredUser = user.isRegisteredUser
        self.canEdit = user.canEdit
        self.updatedAt = user.updatedAt ?? Timestamp()
    }
    
    var isRoot: Bool {
        parentIds.isEmpty
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Computed property to check if node has parents
    var hasParents: Bool {
        !parentIds.isEmpty
    }
    
    // Computed property to check if node has spouse
    var hasSpouse: Bool {
        !spouseIds.isEmpty
    }
    
    // Computed property to check if node has children
    var hasChildren: Bool {
        !childrenIds.isEmpty
    }
    
    static func == (lhs: FamilyTreeNode, rhs: FamilyTreeNode) -> Bool {
        lhs.id == rhs.id
    }
}

// Extension for creating a sample node (useful for previews and testing)
extension FamilyTreeNode {
    static var sample: FamilyTreeNode {
        FamilyTreeNode(
            id: UUID().uuidString,
            firstName: "John",
            lastName: "Doe",
            dateOfBirth: Date(),
            gender: .male,
            email: "john@example.com",
            phoneNumber: "+1234567890",
            photoURL: nil,
            parentIds: [],
            childrenIds: [],
            spouseIds: [],
            generation: 0,
            isRegisteredUser: true,
            canEdit: true,
            updatedAt: Timestamp()
        )
    }
} 