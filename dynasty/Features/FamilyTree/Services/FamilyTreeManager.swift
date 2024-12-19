import FirebaseFirestore
import FirebaseAuth
import OSLog

actor FamilyTreeManager {
    static let shared = FamilyTreeManager()
    private let db = FirestoreManager.shared.getDB()
    private let logger = Logger(subsystem: "com.dynasty.FamilyTreeManager", category: "FamilyTree")
    
    private init() {}
    
    // MARK: - Family Tree Operations
    
    /// Creates a new family tree for the current user
    /// - Returns: The ID of the newly created family tree
    func createFamilyTree() async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        let familyTreeId = db.collection(Constants.Firebase.familyTreesCollection).document().documentID
        
        let familyTreeData: [String: Any] = [
            "id": familyTreeId,
            "ownerUserID": currentUser.uid,
            "admins": [currentUser.uid],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "name": "Family Tree",
            "members": [currentUser.uid]
        ]
        
        try await db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeId)
            .setData(familyTreeData)
        
        // Update the user's document with the new family tree ID
        try await db.collection(Constants.Firebase.usersCollection)
            .document(currentUser.uid)
            .updateData([
                "familyTreeID": familyTreeId,
                "isOwner": true,
                "isAdmin": true,
                "canAddMembers": true,
                "canEdit": true,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        
        logger.info("Created new family tree with ID: \(familyTreeId)")
        return familyTreeId
    }
    
    /// Fetches all members of a family tree
    /// - Parameter familyTreeId: The ID of the family tree to fetch members from
    /// - Returns: An array of User objects representing the family tree members
    func fetchFamilyTreeMembers(familyTreeId: String) async throws -> [User] {
        let snapshot = try await db.collection(Constants.Firebase.usersCollection)
            .whereField("familyTreeID", isEqualTo: familyTreeId)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: User.self)
        }
    }
    
    /// Adds a new member to the family tree
    /// - Parameters:
    ///   - email: Email of the new member
    ///   - familyTreeId: ID of the family tree to add the member to
    ///   - relationship: Relationship to the current user
    func addMember(email: String, to familyTreeId: String, relationship: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw AuthError.notAuthenticated
        }
        
        // Create new user document
        let newUserId = db.collection(Constants.Firebase.usersCollection).document().documentID
        let newUser = User(
            email: email,
            familyTreeID: familyTreeId,
            canAddMembers: false,
            canEdit: true
        )
        
        try await db.collection(Constants.Firebase.usersCollection)
            .document(newUserId)
            .setData(from: newUser)
        
        // Update family tree document
        try await db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeId)
            .updateData([
                "members": FieldValue.arrayUnion([newUserId]),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        
        // Update relationships based on the relationship type
        var updates: [String: Any] = [:]
        switch relationship.lowercased() {
        case "parent":
            updates["parentIds"] = FieldValue.arrayUnion([newUserId])
        case "child":
            updates["childIds"] = FieldValue.arrayUnion([newUserId])
        case "spouse":
            updates["spouseId"] = newUserId
        case "sibling":
            updates["siblingIds"] = FieldValue.arrayUnion([newUserId])
        default:
            logger.warning("Unknown relationship type: \(relationship)")
        }
        
        if !updates.isEmpty {
            try await db.collection(Constants.Firebase.usersCollection)
                .document(currentUser.uid)
                .updateData(updates)
        }
        
        logger.info("Added new member with ID: \(newUserId) to family tree: \(familyTreeId)")
    }
    
    /// Updates a member's information in the family tree
    /// - Parameters:
    ///   - user: The updated user information
    ///   - familyTreeId: The ID of the family tree
    func updateMember(_ user: User, in familyTreeId: String) async throws {
        guard let userId = user.id else {
            throw FamilyTreeError.invalidUserId
        }
        
        try await db.collection(Constants.Firebase.usersCollection)
            .document(userId)
            .setData(from: user, merge: true)
        
        logger.info("Updated member with ID: \(userId) in family tree: \(familyTreeId)")
    }
    
    /// Removes a member from the family tree
    /// - Parameters:
    ///   - userId: The ID of the user to remove
    ///   - familyTreeId: The ID of the family tree
    func removeMember(_ userId: String, from familyTreeId: String) async throws {
        let batch = db.batch()
        
        // Remove user's family tree reference
        let userRef = db.collection(Constants.Firebase.usersCollection).document(userId)
        batch.updateData([
            "familyTreeID": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: userRef)
        
        // Remove from family tree members array
        let treeRef = db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeId)
        batch.updateData([
            "members": FieldValue.arrayRemove([userId]),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: treeRef)
        
        try await batch.commit()
        logger.info("Removed member with ID: \(userId) from family tree: \(familyTreeId)")
    }
    
    // MARK: - Error Types
    
    enum AuthError: LocalizedError {
        case notAuthenticated
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "No authenticated user found"
            }
        }
    }
    
    enum FamilyTreeError: LocalizedError {
        case invalidUserId
        case invalidFamilyTreeId
        case memberNotFound
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .invalidUserId:
                return "Invalid user ID"
            case .invalidFamilyTreeId:
                return "Invalid family tree ID"
            case .memberNotFound:
                return "Member not found in family tree"
            case .permissionDenied:
                return "You don't have permission to perform this action"
            }
        }
    }
}