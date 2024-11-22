import FirebaseFirestore
import FirebaseAuth

class FamilyTreeManager {
    static let shared = FamilyTreeManager()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func createFamilyTree(completion: @escaping (Result<String, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "FamilyTreeManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])))
            return
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
        
        db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeId).setData(familyTreeData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // Update the user's document with the new family tree ID
                self.db.collection(Constants.Firebase.usersCollection).document(currentUser.uid).updateData([
                    "familyTreeID": familyTreeId,
                    "updatedAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(familyTreeId))
                    }
                }
            }
        }
    }
    
    func addMemberToFamilyTree(familyTreeId: String, member: FamilyMember, completion: @escaping (Result<Void, Error>) -> Void) {
        let membersRef = db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeId)
            .collection("members")
        
        do {
            let _ = try membersRef.addDocument(from: member) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func fetchFamilyTree(id: String, completion: @escaping (Result<FamilyTree, Error>) -> Void) {
        db.collection(Constants.Firebase.familyTreesCollection).document(id).getDocument { document, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let document = document, document.exists {
                do {
                    var familyTree = try document.data(as: FamilyTree.self)
                    familyTree.id = document.documentID
                    DispatchQueue.main.async {
                        completion(.success(familyTree))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "FamilyTreeManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Family tree not found"])))
                }
            }
        }
    }
    
    func updateFamilyTreeMember(_ member: FamilyMember, in familyTreeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let memberId = member.id else {
            completion(.failure(NSError(domain: "FamilyTreeManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid member ID"])))
            return
        }
        
        let memberRef = db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeId)
            .collection("members").document(memberId)
        
        do {
            var memberData = try member.asDictionary()
            memberData["updatedAt"] = FieldValue.serverTimestamp()
            
            memberRef.updateData(memberData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func removeMember(memberId: String, from familyTreeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let batch = db.batch()
        
        // Remove member document
        let memberRef = db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeId)
            .collection("members").document(memberId)
        batch.deleteDocument(memberRef)
        
        // Remove relationships
        let relationshipsRef = db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeId)
            .collection("relationships")
        
        relationshipsRef.whereFilter(Filter.orFilter([
            Filter.whereField("fromMemberID", isEqualTo: memberId),
            Filter.whereField("toMemberID", isEqualTo: memberId)
        ])).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    func addRelationship(fromMember: FamilyMember,
                        toMember: FamilyMember,
                        type: RelationType,
                        familyTreeId: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Create primary relationship
        let relationshipRef = db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeId)
            .collection("relationships")
            .document()
            
        let relationship = Relationship(
            fromMemberID: fromMember.id ?? "",
            toMemberID: toMember.id ?? "",
            type: type
        )
        
        try batch.setData(from: relationship, forDocument: relationshipRef)
        
        // Create reciprocal relationship if needed
        if type.requiresReciprocal {
            let reciprocalRef = db.collection(Constants.Firebase.familyTreesCollection)
                .document(familyTreeId)
                .collection("relationships")
                .document()
            
            let reciprocalRelationship = Relationship(
                fromMemberID: toMember.id ?? "",
                toMemberID: fromMember.id ?? "",
                type: type.reciprocalType
            )
            
            try batch.setData(from: reciprocalRelationship, forDocument: reciprocalRef)
        }
        
        try await batch.commit()
    }
    
    func fetchRelationships(familyTreeId: String, completion: @escaping (Result<[Relationship], Error>) -> Void) {
        let relationshipsRef = db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeId)
            .collection("relationships")
        
        relationshipsRef.getDocuments { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let relationships = documents.compactMap { doc -> Relationship? in
                var relationship = try? doc.data(as: Relationship.self)
                relationship?.id = doc.documentID
                return relationship
            }
            
            DispatchQueue.main.async {
                completion(.success(relationships))
            }
        }
    }
} 