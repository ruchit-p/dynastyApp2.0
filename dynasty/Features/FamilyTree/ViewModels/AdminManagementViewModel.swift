import SwiftUI
import FirebaseFirestore
import Combine

class AdminManagementViewModel: ObservableObject {
    @Published var admins: [FamilyMember] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    func fetchAdmins(familyTreeId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("familyTrees")
                .document(familyTreeId)
                .collection("members")
                .whereField("isAdmin", isEqualTo: true)
                .getDocuments()
            
            await MainActor.run {
                self.admins = snapshot.documents.compactMap { document in
                    try? document.data(as: FamilyMember.self)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func updateAdminStatus(memberId: String, familyTreeId: String, isAdmin: Bool) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("familyTrees")
                .document(familyTreeId)
                .collection("members")
                .document(memberId)
                .updateData([
                    "isAdmin": isAdmin,
                    "updatedAt": Timestamp()
                ])
            
            await fetchAdmins(familyTreeId: familyTreeId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func transferOwnership(from currentOwnerId: String, to newOwnerId: String, familyTreeId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let batch = db.batch()
        let treeRef = db.collection("familyTrees").document(familyTreeId)
        
        // Update tree ownership
        batch.updateData(["ownerId": newOwnerId], forDocument: treeRef)
        
        // Update current owner's admin status
        let currentOwnerRef = treeRef.collection("members").document(currentOwnerId)
        batch.updateData([
            "isAdmin": true,
            "isOwner": false,
            "updatedAt": Timestamp()
        ], forDocument: currentOwnerRef)
        
        // Update new owner's admin status
        let newOwnerRef = treeRef.collection("members").document(newOwnerId)
        batch.updateData([
            "isAdmin": true,
            "isOwner": true,
            "updatedAt": Timestamp()
        ], forDocument: newOwnerRef)
        
        do {
            try await batch.commit()
            await fetchAdmins(familyTreeId: familyTreeId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 