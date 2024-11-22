import Foundation
import FirebaseFirestore
import FirebaseAuth

enum Gender: String, Codable {
    case male
    case female
    case other
    case notSpecified
}

struct FamilyMember: Identifiable, Codable, Hashable {
    // MARK: - Essential Properties
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var email: String
    var displayName: String
    var dateOfBirth: Date?
    var profileImageURL: String?
    
    // Core Family Tree Fields
    var parentIds: [String] = []
    var childrenIds: [String] = []
    var spouseId: String?
    var generation: Int?
    
    // MARK: - User Status
    var isRegisteredUser: Bool = false
    var lastLoginDate: Date?
    var accountCreatedAt: Date?
    
    // MARK: - Extended Information
    var gender: Gender = .notSpecified
    var isAlive: Bool = true
    var dateOfDeath: Date?
    var birthPlace: String?
    var currentResidence: String?
    var occupation: String?
    var biography: String?
    
    // MARK: - Family Tree Organization
    var familyBranchId: String?
    var treePosition: CGPoint? // For FamilyTreeView layout
    
    // MARK: - Admin Properties
    var isAdmin: Bool = false
    var canAddMembers: Bool = false
    var canEdit: Bool = true
    
    // MARK: - Timestamp
    @ServerTimestamp var updatedAt: Timestamp?
    
    // MARK: - Initialization
    init(id: String? = nil,
         firstName: String,
         lastName: String,
         email: String,
         displayName: String? = nil,
         dateOfBirth: Date? = nil,
         profileImageURL: String? = nil,
         parentIds: [String] = [],
         childrenIds: [String] = [],
         spouseId: String? = nil,
         generation: Int? = nil,
         isRegisteredUser: Bool = false,
         lastLoginDate: Date? = nil,
         accountCreatedAt: Date? = nil,
         gender: Gender = .notSpecified,
         isAlive: Bool = true,
         dateOfDeath: Date? = nil,
         birthPlace: String? = nil,
         currentResidence: String? = nil,
         occupation: String? = nil,
         biography: String? = nil,
         familyBranchId: String? = nil,
         treePosition: CGPoint? = nil,
         isAdmin: Bool = false,
         canAddMembers: Bool = false,
         canEdit: Bool = true,
         updatedAt: Timestamp? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.displayName = displayName ?? "\(firstName) \(lastName)"
        self.dateOfBirth = dateOfBirth
        self.profileImageURL = profileImageURL
        self.parentIds = parentIds
        self.childrenIds = childrenIds
        self.spouseId = spouseId
        self.generation = generation
        self.isRegisteredUser = isRegisteredUser
        self.lastLoginDate = lastLoginDate
        self.accountCreatedAt = accountCreatedAt ?? (isRegisteredUser ? Date() : nil)
        self.gender = gender
        self.isAlive = isAlive
        self.dateOfDeath = dateOfDeath
        self.birthPlace = birthPlace
        self.currentResidence = currentResidence
        self.occupation = occupation
        self.biography = biography
        self.familyBranchId = familyBranchId
        self.treePosition = treePosition
        self.isAdmin = isAdmin
        self.canAddMembers = canAddMembers
        self.canEdit = canEdit
        self.updatedAt = updatedAt
    }
    
    // MARK: - Firebase User Conversion
    static func fromFirebaseUser(_ user: FirebaseAuth.User) -> FamilyMember {
        let names = user.displayName?.split(separator: " ") ?? []
        let firstName = names.first.map(String.init) ?? ""
        let lastName = names.last.map(String.init) ?? ""
        
        return FamilyMember(
            id: user.uid,
            firstName: firstName,
            lastName: lastName,
            email: user.email ?? "",
            isRegisteredUser: true,
            accountCreatedAt: user.metadata.creationDate
        )
    }
    
    // MARK: - Helper Methods
    func fullName() -> String {
        return displayName
    }
    
    func age() -> Int? {
        guard let dob = dateOfBirth else { return nil }
        let endDate = dateOfDeath ?? Date()
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: endDate)
        return ageComponents.year
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: FamilyMember, rhs: FamilyMember) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
