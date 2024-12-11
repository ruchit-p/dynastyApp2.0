import Foundation
import FirebaseStorage
import FirebaseFirestore
import os.log

class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    private let storage = Storage.storage()
    private let db = FirestoreManager.shared.getDB()
    private let logger = Logger(subsystem: "com.dynasty.FirebaseStorageService", category: "Storage")
    
    private init() {}

    func fetchItems(for userId: String, sortOption: SortOption, isAscending: Bool) async throws -> [VaultItem] {
        logger.info("Fetching vault items for user: \(userId) with sorting")

        let collectionRef = db.collection("users").document(userId).collection("vaultItems")

        // Construct the query with ordering
        var query: Query = collectionRef

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

    
    func uploadEncryptedData(_ data: Data, fileName: String, userId: String) async throws -> String {
        let storageRef = storage.reference()
        let userFolderRef = storageRef.child("vault").child(userId)
        let fileRef = userFolderRef.child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        
        do {
            logger.info("Starting upload for file: \(fileName) to path: \(fileRef.fullPath)")
            _ = try await fileRef.putDataAsync(data, metadata: metadata)
            logger.info("Successfully uploaded encrypted data to Firebase Storage")
            return fileRef.fullPath
        } catch let error as NSError {
            logger.error("Failed to upload encrypted data: \(error.localizedDescription)")
            if error.domain == StorageErrorDomain {
                switch error.code {
                case StorageErrorCode.unauthorized.rawValue:
                    throw VaultError.fileOperationFailed("Unauthorized access to storage. Please check permissions.")
                case StorageErrorCode.quotaExceeded.rawValue:
                    throw VaultError.fileOperationFailed("Storage quota exceeded. Please free up space.")
                case StorageErrorCode.retryLimitExceeded.rawValue:
                    throw VaultError.fileOperationFailed("Network error. Please try again.")
                default:
                    throw VaultError.fileOperationFailed("Storage error: \(error.localizedDescription)")
                }
            }
            throw VaultError.fileOperationFailed("Failed to upload encrypted file: \(error.localizedDescription)")
        }
    }
    
    func downloadEncryptedData(from path: String, progressHandler: ((Double) -> Void)? = nil) async throws -> Data {
        let fileRef = storage.reference(withPath: path)
        let maxSize: Int64 = 100 * 1024 * 1024 // 100MB limit
        
        do {
            logger.info("Starting download from path: \(path)")
            
            return try await withCheckedThrowingContinuation { continuation in
                let task = fileRef.getData(maxSize: maxSize) { data, error in
                    if let error = error as? NSError {
                        if error.domain == StorageErrorDomain {
                            switch error.code {
                            case StorageErrorCode.unauthorized.rawValue:
                                continuation.resume(throwing: VaultError.fileOperationFailed("Unauthorized access to file. Please check permissions."))
                            case StorageErrorCode.objectNotFound.rawValue:
                                continuation.resume(throwing: VaultError.fileOperationFailed("File not found in storage."))
                            default:
                                continuation.resume(throwing: VaultError.fileOperationFailed("Storage error: \(error.localizedDescription)"))
                            }
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                    
                    if let data = data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: VaultError.fileOperationFailed("No data received"))
                    }
                }
                
                // Observe download progress
                task.observe(.progress) { snapshot in
                    if let progress = snapshot.progress {
                        let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                        progressHandler?(percentComplete)
                    }
                }
            }
        } catch {
            logger.error("Failed to download encrypted data: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteFile(at path: String) async throws {
        let fileRef = storage.reference(withPath: path)
        
        do {
            logger.info("Attempting to delete file at path: \(path)")
            try await fileRef.deleteAsync()
            logger.info("Successfully deleted file from Firebase Storage")
        } catch let error as NSError {
            logger.error("Failed to delete file: \(error.localizedDescription)")
            if error.domain == StorageErrorDomain {
                switch error.code {
                case StorageErrorCode.unauthorized.rawValue:
                    throw VaultError.fileOperationFailed("Unauthorized to delete file. Please check permissions.")
                case StorageErrorCode.objectNotFound.rawValue:
                    logger.warning("File already deleted or not found: \(path)")
                    return // Don't throw error if file is already gone
                default:
                    throw VaultError.fileOperationFailed("Storage error: \(error.localizedDescription)")
                }
            }
            throw VaultError.fileOperationFailed("Failed to delete file: \(error.localizedDescription)")
        }
    }
}

// MARK: - Firebase Storage Extensions
extension StorageReference {
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            putData(uploadData, metadata: metadata) { metadata, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let metadata = metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: VaultError.unknown("Unknown upload error"))
                }
            }
        }
    }
    
    func getDataAsync(maxSize: Int64) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            getData(maxSize: maxSize) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: VaultError.unknown("Unknown download error"))
                }
            }
        }
    }
    
    func deleteAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
} 
