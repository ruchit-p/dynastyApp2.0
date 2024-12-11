import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()  // Singleton instance

    private let firestore: Firestore

    private init() {
        firestore = Firestore.firestore()
        // You can add custom settings here if needed:
        // let settings = FirestoreSettings()
        // settings.isPersistenceEnabled = true
        // firestore.settings = settings
    }

    func getDB() -> Firestore {
        return firestore
    }
}