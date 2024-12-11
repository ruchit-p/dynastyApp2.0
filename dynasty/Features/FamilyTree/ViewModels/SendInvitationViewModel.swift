import SwiftUI
import FirebaseFirestore
import Combine

class SendInvitationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var invitations: [Invitation] = []
    
    private let db = FirestoreManager.shared.getDB()
    
    func sendInvitation(to email: String, familyTreeId: String, invitedBy: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let invitation = Invitation(
                email: email,
                familyTreeId: familyTreeId,
                invitedBy: invitedBy,
                status: "pending",
                timestamp: Timestamp()
            )
            
            try await db.collection("invitations").document().setData(from: invitation)
            await fetchInvitations(for: familyTreeId)
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    func fetchInvitations(for familyTreeId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("invitations")
                .whereField("familyTreeId", isEqualTo: familyTreeId)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            await MainActor.run {
                self.invitations = snapshot.documents.compactMap { document in
                    try? document.data(as: Invitation.self)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func cancelInvitation(_ invitationId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("invitations").document(invitationId).delete()
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 