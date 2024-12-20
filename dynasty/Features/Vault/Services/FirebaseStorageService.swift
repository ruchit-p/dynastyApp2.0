import Foundation
import FirebaseStorage
import FirebaseFirestore
import os.log

class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    private let storage = Storage.storage()
    private let db = FirestoreManager.shared.getDB()
    private let logger = Logger(subsystem: "com.dynasty.FirebaseStorageService", category: "Storage")
    private let encryptionService = EncryptionService.shared
    
    // Use a serial queue to ensure thread safety for uploadTasks
    private let uploadQueue = DispatchQueue(label: "com.dynasty.FirebaseStorageService.uploadQueue")
    private var uploadTasks: [String: StorageUploadTask] = [:]
    
    private init() {}

    func fetchItems(for userId: String, sortOption: VaultSortOption, isAscending: Bool) async throws -> [VaultItem] {
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

    
    func uploadEncryptedData(
        _ data: Data,
        fileName: String,
        userId: String,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let storageRef = storage.reference()
        let userFolderRef = storageRef.child("vault").child(userId)
        let fileRef = userFolderRef.child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"

        // Cancel any existing upload task for this file
        uploadQueue.sync {
            if let existingTask = uploadTasks[fileName] {
                existingTask.cancel()
                uploadTasks.removeValue(forKey: fileName)
                logger.info("Cancelled existing upload task for file: \(fileName)")
            }
        }

        logger.info("Starting upload for file: \(fileName) to path: \(fileRef.fullPath)")
        let uploadTask = fileRef.putDataAsync(data, metadata: metadata)

        // Track the new upload task
        uploadQueue.sync {
            uploadTasks[fileName] = uploadTask
        }

        // Observe progress
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let self = self else { return }
            
            if let progress = snapshot.progress {
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                
                // Call progressHandler on the main thread with the progress percentage
                DispatchQueue.main.async {
                    progressHandler?(percentComplete)
                }
            }
        }

        // Handle success and failure
        uploadTask.observe(.success) { [weak self] snapshot in
            self?.uploadQueue.sync {
                self?.uploadTasks.removeValue(forKey: fileName)
            }
            self?.logger.info("Successfully uploaded encrypted data to Firebase Storage")
            completion(.success(fileRef.fullPath))
        }

        uploadTask.observe(.failure) { [weak self] snapshot in
            self?.uploadQueue.sync {
                self?.uploadTasks.removeValue(forKey: fileName)
            }
            if let error = snapshot.error as NSError? {
                self?.logger.error("Failed to upload encrypted data: \(error.localizedDescription)")
                let vaultError = self?.handleFirebaseStorageError(error) ?? VaultError.fileOperationFailed("Failed to upload encrypted file: \(error.localizedDescription)")
                completion(.failure(vaultError))
            } else {
                completion(.failure(VaultError.fileOperationFailed("Failed to upload encrypted file: Unknown error")))
            }
        }
    }
    
    func downloadEncryptedData(
        from path: String,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let fileRef = storage.reference(withPath: path)
        let maxSize: Int64 = 100 * 1024 * 1024 // 100MB limit

        logger.info("Starting download from path: \(path)")

        let downloadTask = fileRef.getDataAsync(maxSize: maxSize) { data, error in
            if let error = error as NSError? {
                self.logger.error("Failed to download encrypted data: \(error.localizedDescription)")
                let vaultError = self.handleFirebaseStorageError(error) ?? VaultError.fileOperationFailed("Failed to download encrypted file: \(error.localizedDescription)")
                completion(.failure(vaultError))
            } else if let data = data {
                self.logger.info("Successfully downloaded encrypted data from Firebase Storage")
                completion(.success(data))
            } else {
                completion(.failure(VaultError.fileOperationFailed("Failed to download encrypted file: Unknown error")))
            }
        }

        // Observe progress
        downloadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                progressHandler?(percentComplete) // Call the progress handler, if provided
            }
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

    // Helper function to handle Firebase Storage errors
    private func handleFirebaseStorageError(_ error: NSError) -> VaultError {
        if error.domain == StorageErrorDomain {
            switch error.code {
            case StorageErrorCode.unauthorized.rawValue:
                return VaultError.fileOperationFailed("Unauthorized access to storage. Please check permissions.")
            case StorageErrorCode.quotaExceeded.rawValue:
                return VaultError.fileOperationFailed("Storage quota exceeded. Please free up space.")
            case StorageErrorCode.retryLimitExceeded.rawValue:
                return VaultError.fileOperationFailed("Network error. Please try again.")
            default:
                return VaultError.fileOperationFailed("Storage error: \(error.localizedDescription)")
            }
        }
        return VaultError.fileOperationFailed("Failed to perform storage operation: \(error.localizedDescription)")
    }

    func uploadEncryptedFile(
        from fileURL: URL,
        fileName: String,
        userId: String,
        mimeType: String,
        encryptionKeyId: String,
        parentFolderId: String?,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard let encryptionKey = try await encryptionService.loadKey(for: encryptionKeyId) else {
            logger.error("Encryption key not found for ID: \(encryptionKeyId)")
            throw VaultError.encryptionFailed("Encryption key not found")
        }

        let encryptedFileURL: URL
        do {
            encryptedFileURL = try await encryptionService.encrypt(
                fileURL: fileURL,
                encryptionKey: encryptionKey,
                keyId: encryptionKeyId
            )
        } catch {
            logger.error("Encryption failed: \(error.localizedDescription)")
            throw VaultError.encryptionFailed("File encryption failed: \(error.localizedDescription)")
        }

        let storageRef = storage.reference().child("users/\(userId)/vault/\(fileName)")
        var uploadTask: StorageUploadTask?

        do {
            let metadata = StorageMetadata()
            metadata.contentType = mimeType
            
            // Create and store the upload task
            uploadTask = storageRef.putFile(from: encryptedFileURL, metadata: metadata)
            
            // Observe progress
            uploadTask?.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    logger.info("Upload progress: \(percentComplete * 100)%")
                    DispatchQueue.main.async {
                        progressHandler?(percentComplete)
                    }
                }
            }
            
            // Wait for upload completion
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<StorageMetadata, Error>) in
                uploadTask?.observe(.success) { snapshot in
                    if let metadata = snapshot.metadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: VaultError.fileOperationFailed("Upload completed but metadata is missing"))
                    }
                }
                
                uploadTask?.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: VaultError.fileOperationFailed("Upload failed with unknown error"))
                    }
                }
            }
        } catch {
            logger.error("Firebase Storage upload failed: \(error.localizedDescription)")
            throw VaultError.fileOperationFailed("File upload failed: \(error.localizedDescription)")
        }

        // Clean up temporary encrypted file
        do {
            try FileManager.default.removeItem(at: encryptedFileURL)
            logger.info("Temporary encrypted file removed at: \(encryptedFileURL.path)")
        } catch {
            logger.warning("Failed to remove temporary encrypted file at: \(encryptedFileURL.path) - \(error.localizedDescription)")
        }

        // Save metadata to Firestore
        let metadata = VaultItemMetadata(
            originalFileName: (fileURL.lastPathComponent as NSString).deletingPathExtension,
            fileExtension: fileURL.pathExtension,
            mimeType: mimeType,
            sizeInBytes: try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
            encryptionKeyId: encryptionKeyId,
            uploadDate: Date()
        )

        let newItem = VaultItem(
            id: fileName,
            userId: userId,
            title: metadata.originalFileName,
            fileType: try determineFileType(from: fileURL),
            metadata: metadata,
            parentFolderId: parentFolderId,
            isFavorite: false,
            isDeleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            try await FirestoreDatabaseManager.shared.saveItem(newItem, for: userId)
            logger.info("File metadata saved to Firestore for: \(fileName)")
        } catch {
            logger.error("Failed to save file metadata to Firestore: \(error.localizedDescription)")
            throw VaultError.databaseOperationFailed("Failed to save file metadata")
        }
    }

    private func determineFileType(from fileURL: URL) throws -> VaultItemType {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "heif":
            return .image
        case "mov", "mp4", "m4v", "avi":
            return .video
        case "pdf":
            return .document
        case "doc", "docx":
            return .document
        case "xls", "xlsx":
            return .spreadsheet
        case "txt", "rtf":
            return .text
        case "zip", "rar", "7z":
            return .archive
        default:
            return .other
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
