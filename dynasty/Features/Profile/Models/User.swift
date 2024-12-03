import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var displayName: String
    var email: String
    var dateOfBirth: Date?
    var firstName: String?
    var lastName: String?
    var phoneNumber: String?
    var familyTreeID: String?
    var historyBookID: String?
    var parentIds: [String]
    var childrenIds: [String]
    var isAdmin: Bool
    var canAddMembers: Bool
    var canEdit: Bool
    var photoURL: String? = nil
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?

    // Custom initializer
    init(id: String?,
         displayName: String,
         email: String,
         dateOfBirth: Date,
         firstName: String,
         lastName: String?,
         phoneNumber: String?,
         familyTreeID: String?,
         historyBookID: String?,
         parentIds: [String],
         childrenIds: [String],
         isAdmin: Bool,
         canAddMembers: Bool,
         canEdit: Bool,
         photoURL: String?,
         createdAt: Timestamp,
         updatedAt: Timestamp?) {
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
}

extension User {
    func toDict() -> [String: Any] {
        let dict: [String: Any] = [
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
