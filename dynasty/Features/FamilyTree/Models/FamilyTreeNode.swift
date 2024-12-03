import Foundation
import FirebaseFirestore

struct FamilyTreeNode: Identifiable, Codable {
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
    var isRegisteredUser: Bool
    var canEdit: Bool
    var updatedAt: Timestamp
    
    enum Gender: String, Codable {
        case male
        case female
        case other
        case unknown
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
            spouseIds: [],
            childrenIds: [],
            isRegisteredUser: true,
            canEdit: true,
            updatedAt: Timestamp()
        )
    }
} 