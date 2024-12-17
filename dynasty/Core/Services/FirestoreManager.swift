import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()  // Singleton instance

    private let firestore: Firestore
    private let cacheSizeInMB: Int64 = 100  // 100MB cache size

    private init() {
        firestore = Firestore.firestore()
        
        // Configure Firestore settings
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = cacheSizeInMB * 1024 * 1024  // Convert MB to bytes
        
        // Apply settings
        firestore.settings = settings
    }

    func getDB() -> Firestore {
        return firestore
    }
    
    /// Clears the persistent cache
    func clearCache() async throws {
        try await firestore.clearPersistence()
    }
    
    /// Terminates the Firestore instance
    func terminate() async throws {
        try await firestore.terminate()
    }
    
    /// Waits for pending writes to be acknowledged by the server
    func waitForPendingWrites() async throws {
        try await firestore.waitForPendingWrites()
    }
}