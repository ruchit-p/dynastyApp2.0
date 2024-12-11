import Foundation
import FirebaseFirestore
import os.log

class FirestoreDatabaseManager {
    static let shared = FirestoreDatabaseManager()
    
    private let db = FirestoreManager.shared.getDB()
    private let logger = Logger(subsystem: "com.dynasty.FirestoreDatabaseManager", category: "Database")
    
    private init() {}
    
    func openDatabase(for userId: String) async throws {
        logger.info("Firestore database context prepared for user: \(userId)")
    }
    
 func fetchItems(for userId: String, sortOption: SortOption, isAscending: Bool) async throws -> [VaultItem] {
        logger.info("Fetching vault items for user: \(userId) with sorting")
        let collectionRef = db.collection("users").document(userId).collection("vaultItems")
        
        // Construct the query with ordering
        var query: Query = collectionRef.whereField("isDeleted", isEqualTo: false)
        
        switch sortOption {
        case .name:
            query = query.order(by: "title", descending: !isAscending)
        case .kind:
            query = query.order(by: "fileType", descending: !isAscending)
        case .date:
            query = query.order(by: "createdAt", descending: !isAscending)
        case .size:
            query = query.order(by: "metadata.fileSize", descending: !isAscending)
        }
        
        let snapshot = try await query.getDocuments()
        var items: [VaultItem] = []
        for doc in snapshot.documents {
            do {
                let item = try doc.data(as: VaultItem.self)
                items.append(item)
            } catch {
                logger.error("Failed to decode VaultItem \(doc.documentID): \(error.localizedDescription)")
            }
        }
        logger.info("Fetched \(items.count) vault items from Firestore for user: \(userId)")
        return items
    }
    
    func saveItems(_ items: [VaultItem], for userId: String) async throws {
        logger.info("Saving \(items.count) items to Firestore for user: \(userId)")
        let batch = db.batch()
        let collectionRef = db.collection("users").document(userId).collection("vaultItems")
        
        for item in items {
            let docRef = collectionRef.document(item.id)
            do {
                try batch.setData(from: item, forDocument: docRef, merge: true)
            } catch {
                logger.error("Failed to encode VaultItem \(item.id): \(error.localizedDescription)")
                throw VaultError.databaseError("Failed to encode item \(item.id)")
            }
        }
        try await batch.commit()
        logger.info("Successfully saved items to Firestore for user: \(userId)")
    }
    
    func deleteItem(_ item: VaultItem, for userId: String) async throws {
        logger.info("Deleting item: \(item.id) for user: \(userId)")
        let docRef = db.collection("users").document(userId).collection("vaultItems").document(item.id)
        try await docRef.delete()
        logger.info("Successfully deleted item from Firestore: \(item.id)")
    }
} 
