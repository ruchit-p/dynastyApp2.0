import SwiftUI
import FirebaseFirestore
import Combine

class UserProfileEditViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
    init(user: User? = nil) {
        self.user = user
    }
    
    func updateProfile(userId: String, updatedData: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await db.collection("users").document(userId).updateData(updatedData)
            // Fetch updated profile
            let updatedDoc = try await db.collection("users").document(userId).getDocument()
            if let updatedUser = try? updatedDoc.data(as: User.self) {
                await MainActor.run {
                    self.user = updatedUser
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
} 