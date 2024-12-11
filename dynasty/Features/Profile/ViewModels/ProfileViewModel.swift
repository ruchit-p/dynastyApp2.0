import SwiftUI
import FirebaseFirestore
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    func fetchUserProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            if document.exists {
                user = try document.data(as: User.self)
            }
        } catch {
            self.error = error
        }
    }
    
    func updateUserProfile(userId: String, data: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await db.collection("users").document(userId).updateData(data)
        await fetchUserProfile(userId: userId)
    }
} 
