import SwiftUI
import FirebaseFirestore
import Combine
import OSLog

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var profileImage: UIImage?
    
    private let db = FirestoreManager.shared.getDB()
    private let logger = Logger(subsystem: "com.dynasty.ProfileViewModel", category: "Profile")
    
    func fetchUserProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let docRef = db.collection("users").document(userId)
            let document = try await docRef.getDocument()
            
            if document.exists {
                user = try document.data(as: User.self)
                // Try to load profile image after fetching user
                await loadProfileImage(userId: userId)
            }
        } catch {
            self.error = error
            logger.error("Failed to fetch user profile: \(error.localizedDescription)")
        }
    }
    
    func updateUserProfile(userId: String, data: [String: Any]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        try await db.collection("users").document(userId).updateData(data)
        await fetchUserProfile(userId: userId)
    }
    
    /// Loads the profile image from cache or network
    /// - Parameter userId: The user ID whose profile image to load
    func loadProfileImage(userId: String) async {
        do {
            // Try to load from cache first
            if let imageData = await CacheService.shared.getCachedProfileImage(userId: userId),
               let image = UIImage(data: imageData) {
                self.profileImage = image
                logger.debug("Loaded profile image from cache for user: \(userId)")
                return
            }
            
            // If not in cache and we have a URL, try to load from network
            guard let photoURL = user?.photoURL,
                  let url = URL(string: photoURL) else {
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Cache the downloaded image
            try await CacheService.shared.cacheProfileImage(userId: userId, imageData: data)
            
            if let image = UIImage(data: data) {
                self.profileImage = image
                logger.debug("Loaded and cached profile image from network for user: \(userId)")
            }
        } catch {
            logger.error("Failed to load profile image: \(error.localizedDescription)")
            // Don't set self.error as this is not a critical failure
        }
    }
}
