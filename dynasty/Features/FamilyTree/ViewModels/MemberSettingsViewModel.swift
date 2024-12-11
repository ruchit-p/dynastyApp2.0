import SwiftUI
import FirebaseFirestore
import Combine

class MemberSettingsViewModel: ObservableObject {
    @Published var member: FamilyMember?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    init(member: FamilyMember?) {
        self.member = member
    }
    
    func updateMemberSettings(memberId: String, familyTreeId: String, updatedData: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("familyTrees")
                .document(familyTreeId)
                .collection("members")
                .document(memberId)
                .updateData(updatedData)
                
            // Fetch updated member data
            let updatedDoc = try await db.collection("familyTrees")
                .document(familyTreeId)
                .collection("members")
                .document(memberId)
                .getDocument()
                
            if let updatedMember = try? updatedDoc.data(as: FamilyMember.self) {
                await MainActor.run {
                    self.member = updatedMember
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func removeMember(memberId: String, familyTreeId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("familyTrees")
                .document(familyTreeId)
                .collection("members")
                .document(memberId)
                .delete()
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func updateMemberPermissions(memberId: String, familyTreeId: String, canEdit: Bool, canAddMembers: Bool) async throws {
        let updatedData: [String: Any] = [
            "canEdit": canEdit,
            "canAddMembers": canAddMembers,
            "updatedAt": Timestamp()
        ]
        
        try await updateMemberSettings(memberId: memberId, familyTreeId: familyTreeId, updatedData: updatedData)
    }
} 