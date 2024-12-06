import Foundation
import LocalAuthentication
import CryptoKit
import os.log
import UniformTypeIdentifiers
import FirebaseFirestore


enum VaultError: LocalizedError {
    case authenticationFailed(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case fileOperationFailed(String)
    case invalidData(String)
    case databaseError(String)
    case itemNotFound(String)
    case duplicateItem(String)
    case vaultLocked
    case fileTooLarge(String)
    case unknown(String)
    case authenticationCancelled
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .databaseError(let reason):
            return "Database error: \(reason)"
        case .itemNotFound(let reason):
            return "Item not found: \(reason)"
        case .duplicateItem(let reason):
            return "Duplicate item: \(reason)"
        case .vaultLocked:
            return "Vault is locked"
        case .fileTooLarge(let reason):
            return "File too large: \(reason)"
        case .unknown(let reason):
            return "Unknown error: \(reason)"
        case .authenticationCancelled:
            return "Authentication was cancelled"
        }
    }
}

@MainActor
class VaultManager: ObservableObject {
    static let shared = VaultManager()
    
    // MARK: - Published Properties
    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var isLocked = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isDocumentPickerPresented = false
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    private let encryptionService: VaultEncryptionService
    private let storageService: FirebaseStorageService
    private let dbManager = FirestoreDatabaseManager.shared
    private let logger = Logger(subsystem: "com.dynasty.VaultManager", category: "Vault")
    private var currentAuthenticationTask: Task<Void, Error>?
    private var processingTask: Task<Void, Error>?
    
    // New properties for authentication tracking
    private var failedAttempts = 0
    private var lockUntil: Date?
    
    private init() {
        self.encryptionService = VaultEncryptionService()
        self.storageService = FirebaseStorageService.shared
        logger.info("VaultManager initialized")
    }
    
    // MARK: - Public Methods
    
    // Public method for encryption key generation
    func generateEncryptionKey(for userId: String) throws -> String {
        return try encryptionService.generateEncryptionKey(for: userId)
    }
    
    // Public method for file encryption
    func encryptFile(data: Data, userId: String, keyId: String) throws -> (Data, Data) {
        return try encryptionService.encryptFile(data: data, userId: userId, keyId: keyId)
    }
    
    // Public method for file decryption
    func decryptFile(encryptedData: Data, userId: String, keyId: String, iv: Data) throws -> Data {
        return try encryptionService.decryptFile(encryptedData: encryptedData, userId: userId, keyId: keyId, iv: iv)
    }
    
    func setCurrentUser(_ user: User?) {
        self.currentUser = user
        if let user = user {
            Task {
                try? await self.loadItems(for: user.id!)
            }
        } else {
            self.items.removeAll()
            self.isLocked = true
        }
    }
    
    func setDocumentPickerPresented(_ isPresented: Bool) {
        self.isDocumentPickerPresented = isPresented
    }
    
    // New method for biometric authentication
    private func authenticateUser() async throws {
        // Check lockout status
        if let lockUntil = lockUntil, Date() < lockUntil {
            let remaining = Int(lockUntil.timeIntervalSinceNow / 60)
            let message = "Vault is locked due to multiple failed attempts. Please try again in \(max(1, remaining)) minute(s)."
            logger.error("\(message)")
            throw VaultError.authenticationFailed(message)
        }
        
        self.isAuthenticating = true
        defer { self.isAuthenticating = false }
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedReason = "Authenticate to access your secure vault"
        
        do {
            let success = try await withCheckedThrowingContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthentication, 
                                    localizedReason: "Access your vault") { success, error in
                    if success {
                        continuation.resume(returning: ())
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: VaultError.authenticationFailed("Unknown authentication error"))
                    }
                }
            }
            
            // Authentication succeeded
            logger.info("User successfully authenticated via biometrics/passcode")
            failedAttempts = 0
            
        } catch {
            // Handle failed attempt
            failedAttempts += 1
            logger.error("Authentication failed. Attempt \(self.failedAttempts) of 5. Error: \(error.localizedDescription)")
            
            if failedAttempts >= 5 {
                // Lock the vault for 10 minutes
                lockUntil = Date().addingTimeInterval(10 * 60)
                failedAttempts = 0
                let message = "Too many failed attempts. Vault locked for 10 minutes."
                logger.error("\(message)")
                throw VaultError.authenticationFailed(message)
            }
            
            if (error as NSError).code == LAError.userCancel.rawValue {
                throw VaultError.authenticationCancelled
            } else {
                throw VaultError.authenticationFailed("Authentication failed. Please try again.")
            }
        }
    }
    
    // Update unlock method to use new authentication
    func unlock() async throws {
        guard let user = currentUser, let userId = user.id else {
            throw VaultError.authenticationFailed("No authenticated user found")
        }
        
        // Require user authentication before unlocking
        try await authenticateUser()
        
        // Once authenticated, proceed with vault unlocking
        do {
            try await encryptionService.initialize()
            try await dbManager.openDatabase(for: userId)
            try await loadItems(for: userId)
            isLocked = false
            logger.info("Vault unlocked successfully for user: \(userId)")
        } catch {
            logger.error("Failed to unlock vault after authentication: \(error.localizedDescription)")
            throw error
        }
    }
    
    func lock() {
        self.isLocked = true
        self.items.removeAll()
        self.logger.info("Vault locked")
    }
    
    func loadItems(for userId: String) async throws {
        self.logger.info("Loading vault items for user: \(userId)")
        do {
            self.items = try await self.dbManager.fetchItems(for: userId)
            self.logger.info("Successfully loaded \(self.items.count) items for user: \(userId)")
        } catch {
            self.logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func importItems(from urls: [URL], userId: String) async throws {
        for url in urls {
            try await importFile(from: url, userId: userId)
        }
    }
    
    func downloadFile(_ item: VaultItem) async throws -> Data {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Downloading file: \(item.id)")
        
        do {
            let encryptedData = try await self.storageService.downloadEncryptedData(
                from: item.storagePath
            )
            
            let decryptedData = try self.encryptionService.decryptFile(
                encryptedData: encryptedData,
                userId: item.userId,
                keyId: item.metadata.encryptionKeyId,
                iv: item.metadata.iv
            )
            
            let fileHash = encryptionService.generateFileHash(for: decryptedData)
            guard fileHash == item.metadata.hash else {
                throw VaultError.fileOperationFailed("File integrity check failed")
            }
            
            logger.info("Successfully downloaded and decrypted file: \(item.id)")
            return decryptedData
        } catch {
            logger.error("Failed to download file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func restoreItem(_ item: VaultItem) async throws {
        guard !self.isLocked else {
            throw VaultError.vaultLocked
        }
        
        guard let userId = currentUser?.id else { throw VaultError.authenticationFailed("No user ID") }
        self.logger.info("Restoring item: \(item.id) for user: \(userId)")
        
        if let index = self.items.firstIndex(where: { $0.id == item.id }) {
            var restoredItem = self.items[index]
            restoredItem.isDeleted = false
            restoredItem.updatedAt = Date()
            self.items[index] = restoredItem
            try await saveItems(self.items, for: userId)
            self.logger.info("Successfully restored item: \(item.id)")
        } else {
            throw VaultError.itemNotFound("Could not find item \(item.id) to restore")
        }
    }
    
    func permanentlyDeleteItem(_ item: VaultItem) async throws {
        guard !self.isLocked else {
            throw VaultError.vaultLocked
        }
        
        guard let userId = currentUser?.id else { throw VaultError.authenticationFailed("No user ID") }
        
        self.logger.info("Permanently deleting item: \(item.id) for user: \(userId)")
        
        do {
            try await storageService.deleteFile(at: item.storagePath)
            try self.encryptionService.deleteEncryptionKey(keyId: item.metadata.encryptionKeyId)
            
            self.items.removeAll(where: { $0.id == item.id })
            try await dbManager.deleteItem(item, for: userId)
            
            self.logger.info("Successfully deleted item permanently: \(item.id)")
        } catch {
            self.logger.error("Failed to permanently delete item: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Public methods for encryption service functionality
    func generateEncryptionKey(for userId: String) async throws -> String {
        return try await encryptionService.generateEncryptionKey(for: userId)
    }
    
    func generateFileHash(for data: Data) -> String {
        return encryptionService.generateFileHash(for: data)
    }
    
    func importData(
        _ data: Data,
        filename: String,
        fileType: VaultItemType,
        metadata: VaultItemMetadata,
        userId: String
    ) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Importing data with filename: \(filename)")
        
        do {
            let (encryptedData, iv) = try encryptionService.encryptFile(
                data: data,
                userId: userId,
                keyId: metadata.encryptionKeyId
            )
            
            // Cache encrypted data locally
            let cacheURL = try cacheEncryptedData(encryptedData, filename: filename)
            
            let storagePath = try await storageService.uploadEncryptedData(
                encryptedData,
                fileName: filename,
                userId: userId
            )
            
            var updatedMetadata = metadata
            updatedMetadata.iv = iv
            
            let item = VaultItem(
                id: UUID().uuidString,
                userId: userId,
                title: metadata.originalFileName,
                description: nil,
                fileType: fileType,
                encryptedFileName: filename,
                storagePath: storagePath,
                thumbnailURL: nil,
                metadata: updatedMetadata,
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false
            )
            
            items.append(item)
            try await dbManager.saveItems(items, for: userId)
            
            logger.info("Successfully imported data")
        } catch {
            logger.error("Failed to import data: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    private func importFile(from url: URL, userId: String) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Importing file from URL: \(url)")
        
        do {
            let fileData = try Data(contentsOf: url)
            let fileType = determineFileType(from: url)
            let mimeType = determineMimeType(from: url)
            let keyId = try encryptionService.generateEncryptionKey(for: userId)
            
            let metadata = VaultItemMetadata(
                originalFileName: url.lastPathComponent,
                fileSize: Int64(fileData.count),
                mimeType: mimeType,
                encryptionKeyId: keyId,
                iv: Data(),
                hash: encryptionService.generateFileHash(for: fileData)
            )
            
            try await importData(fileData, filename: UUID().uuidString, fileType: fileType, metadata: metadata, userId: userId)
        } catch {
            logger.error("Failed to import file: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func determineFileType(from url: URL) -> VaultItemType {
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let type = UTType(uti) {
            if type.conforms(to: .image) {
                return .image
            } else if type.conforms(to: .video) {
                return .video
            } else if type.conforms(to: .audio) {
                return .audio
            } else if type.conforms(to: .pdf) || type.conforms(to: .text) {
                return .document
            }
        }
        return .document
    }
    
    private func determineMimeType(from url: URL) -> String {
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let type = UTType(uti) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
    
    // Line ~440: Add this new function to cache encrypted data
    private func cacheEncryptedData(_ data: Data, filename: String) throws -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            logger.info("Encrypted data cached at: \(fileURL.path)")
            return fileURL
        } catch {
            logger.error("Failed to cache encrypted data: \(error.localizedDescription)")
            throw VaultError.fileOperationFailed("Failed to cache encrypted data: \(error.localizedDescription)")
        }
    }
    
    private func saveItems(_ items: [VaultItem], for userId: String) async throws {
        try await self.dbManager.saveItems(items, for: userId)
        self.logger.info("Items saved to Firestore for user: \(userId)")
    }
    
     
}

extension VaultManager {
    func moveToTrash(_ item: VaultItem) async throws {
        guard let userId = currentUser?.id else {
            throw VaultError.authenticationFailed("No authenticated user")
        }
        
        // Mark the item as deleted
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.isDeleted = true
            updatedItem.updatedAt = Date()
            items[index] = updatedItem
            
            // Save the updated items to Firestore
            try await saveItems(items, for: userId)
        } else {
            throw VaultError.itemNotFound("Item not found to move to trash")
        }
    }
}