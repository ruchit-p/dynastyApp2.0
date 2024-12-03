import Foundation
import LocalAuthentication
import CryptoKit
import os.log
import UniformTypeIdentifiers

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
    
    @Published private(set) var isLocked = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0
    @Published private(set) var isDocumentPickerPresented = false
    
    private let logger = Logger(subsystem: "com.dynasty.VaultManager", category: "Vault")
    private let encryptionService: VaultEncryptionService
    private let fileManager: FileManager
    private let dbManager: Vault.DatabaseManager
    private var processingTask: Task<Void, Error>?
    private var currentAuthenticationTask: Task<Bool, Error>?
    
    init() {
        self.encryptionService = VaultEncryptionService.shared
        self.fileManager = FileManager.default
        self.dbManager = Vault.DatabaseManager.shared
        logger.info("VaultManager initialized")
    }
    
    func loadItems() async throws -> [VaultItem] {
        if isLocked {
            try await unlock()
        }
        
        do {
            logger.info("Loading vault items")
            let items = try await dbManager.fetchItems()
            logger.info("Successfully loaded \(items.count) items")
            return items
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func unlock() async throws {
        guard isLocked else { return }
        guard !isAuthenticating else { return }
        
        // Cancel any existing authentication task
        currentAuthenticationTask?.cancel()
        currentAuthenticationTask = nil
        
        isAuthenticating = true
        
        defer {
            isAuthenticating = false
            currentAuthenticationTask = nil
        }
        
        do {
            // Create a new authentication task
            let authSuccess = try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask { [weak self] in
                    guard let self = self else { throw VaultError.unknown("VaultManager deallocated") }
                    
                    // First authenticate with Face ID/Touch ID
                    let context = LAContext()
                    let reason = "Authenticate to access your vault"
                    
                    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                        logger.error("Biometric authentication not available")
                        throw VaultError.authenticationFailed("Biometric authentication not available")
                    }
                    
                    return try await withCheckedThrowingContinuation { continuation in
                        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                            if Task.isCancelled {
                                continuation.resume(throwing: VaultError.authenticationCancelled)
                                return
                            }
                            
                            if success {
                                continuation.resume(returning: true)
                            } else {
                                if let laError = error as? LAError {
                                    switch laError.code {
                                    case .userCancel, .systemCancel, .appCancel:
                                        continuation.resume(throwing: VaultError.authenticationCancelled)
                                    default:
                                        continuation.resume(throwing: VaultError.authenticationFailed(laError.localizedDescription))
                                    }
                                } else {
                                    let message = error?.localizedDescription ?? "Unknown error"
                                    continuation.resume(throwing: VaultError.authenticationFailed(message))
                                }
                            }
                        }
                    }
                }
                
                // Get the first (and only) result
                guard let success = try await group.next() else {
                    throw VaultError.authenticationFailed("Authentication failed")
                }
                
                return success
            }
            
            guard authSuccess else {
                throw VaultError.authenticationFailed("Authentication failed")
            }
            
            // Only proceed with vault unlocking if authentication succeeded
            try await encryptionService.initialize()
            try dbManager.openDatabase()
            let items = try await dbManager.fetchItems()
            self.items = items
            isLocked = false
            logger.info("Vault unlocked successfully")
        } catch {
            logger.error("Failed to unlock vault: \(error.localizedDescription)")
            // Clean up on failure
            dbManager.closeDatabase()
            encryptionService.clearKeys()
            isLocked = true
            items.removeAll()
            
            // Rethrow the error to be handled by the view
            throw error
        }
    }
    
    func lock() {
        // Don't lock if we're showing document picker
        guard !isDocumentPickerPresented else { return }
        
        // Don't lock if we're already locked
        guard !isLocked else { return }
        
        logger.info("Locking vault")
        isLocked = true
        isAuthenticating = false
        currentAuthenticationTask?.cancel()
        currentAuthenticationTask = nil
        items.removeAll()
        dbManager.closeDatabase()
        encryptionService.clearKeys()
        logger.info("Vault locked successfully")
    }
    
    func setDocumentPickerPresented(_ isPresented: Bool) {
        isDocumentPickerPresented = isPresented
    }
    
    func importItems(from urls: [URL], userId: String) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        isProcessing = true
        processingProgress = 0
        
        do {
            let totalItems = Double(urls.count)
            var processedItems = 0.0
            
            for url in urls {
                let item = try await importItem(from: url, userId: userId)
                items.append(item)
                
                processedItems += 1
                processingProgress = processedItems / totalItems
            }
            
            try await saveItems()
            logger.info("Successfully imported \(urls.count) items")
        } catch {
            logger.error("Failed to import items: \(error.localizedDescription)")
            throw error
        }
        
        isProcessing = false
        processingProgress = 0
    }
    
    private func importItem(from url: URL, userId: String) async throws -> VaultItem {
        logger.info("Starting import of file: \(url.lastPathComponent)")
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("Failed to access security-scoped resource: \(url.lastPathComponent)")
            throw VaultError.fileOperationFailed("Permission denied to access file")
        }
        
        defer {
            // Make sure to release the security-scoped resource when done
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Validate file size
            let fileSize = Int64(data.count)
            let fileType = determineFileType(from: url)
            guard fileSize <= fileType.maxFileSize else {
                logger.error("File too large: \(fileSize) bytes")
                throw VaultError.fileTooLarge("File size exceeds maximum allowed size of \(ByteCountFormatter().string(fromByteCount: fileType.maxFileSize))")
            }
            
            // Generate a new encryption key for the file
            logger.info("Generating encryption key")
            let keyId = try encryptionService.generateEncryptionKey(for: userId)
            
            // Encrypt the file data
            logger.info("Encrypting file data")
            let (encryptedData, iv) = try encryptionService.encryptFile(data: data, userId: userId, keyId: keyId)
            
            // Save encrypted data to a file
            logger.info("Saving encrypted data")
            let encryptedFileURL = try saveEncryptedData(encryptedData, fileName: UUID().uuidString)
            
            // Compute file hash
            let fileHash = encryptionService.generateFileHash(for: data)
            
            let mimeType = try determineMimeType(for: url)
            
            // Create metadata
            let metadata = VaultItemMetadata(
                originalFileName: url.lastPathComponent,
                fileSize: fileSize,
                mimeType: mimeType,
                encryptionKeyId: keyId,
                iv: iv,
                hash: fileHash
            )
            
            let item = VaultItem(
                id: UUID().uuidString,
                userId: userId,
                title: url.lastPathComponent,
                description: nil,
                fileType: fileType,
                encryptedFileURL: encryptedFileURL.path,
                thumbnailURL: nil,
                metadata: metadata,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            logger.info("Successfully imported file: \(url.lastPathComponent)")
            return item
        } catch {
            logger.error("Failed to import file: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func saveEncryptedData(_ data: Data, fileName: String) throws -> URL {
        logger.info("Saving encrypted data to file: \(fileName)")
        do {
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folderURL = documentsDirectory.appendingPathComponent("Vault", isDirectory: true)
            
            if !fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let fileURL = folderURL.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: .completeFileProtection)
            logger.info("Successfully saved encrypted data")
            return fileURL
        } catch {
            logger.error("Failed to save encrypted data: \(error.localizedDescription)")
            throw VaultError.fileOperationFailed("Failed to save encrypted file: \(error.localizedDescription)")
        }
    }
    
    private func determineFileType(from url: URL) -> VaultItemType {
        let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier ?? ""
        
        if let utType = UTType(typeIdentifier ?? "") {
            if utType.conforms(to: .image) {
                return .image
            } else if utType.conforms(to: .movie) {
                return .video
            } else if utType.conforms(to: .audio) {
                return .audio
            }
        }
        return .document
    }
    
    private func determineMimeType(for url: URL) throws -> String {
        let typeIdentifier = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier ?? ""
        if let utType = UTType(typeIdentifier) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
    
    private func saveItems() async throws {
        try await dbManager.saveItems(items)
    }
    
    func deleteItems(at offsets: IndexSet) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        items.remove(atOffsets: offsets)
        try await saveItems()
    }
    
    func getDecryptedData(for item: VaultItem, userId: String) async throws -> Data {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        // Retrieve encrypted data from file
        let encryptedFileURL = URL(fileURLWithPath: item.encryptedFileURL)
        let encryptedData = try Data(contentsOf: encryptedFileURL)
        
        // Get encryption parameters from metadata
        let keyId = item.metadata.encryptionKeyId
        let iv = item.metadata.iv
        
        // Decrypt data
        let decryptedData = try encryptionService.decryptFile(
            encryptedData: encryptedData,
            userId: userId,
            keyId: keyId,
            iv: iv
        )
        
        return decryptedData
    }
    
    func cancelProcessing() {
        processingTask?.cancel()
        isProcessing = false
        processingProgress = 0
    }
    
    func downloadFile(_ item: VaultItem, userId: String) async throws -> Data {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Downloading file: \(item.id)")
        do {
            let data = try await getDecryptedData(for: item, userId: userId)
            logger.info("Successfully downloaded file: \(item.id)")
            return data
        } catch {
            logger.error("Failed to download file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteItem(_ item: VaultItem) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Deleting item: \(item.id)")
        do {
            // Delete encrypted file
            let encryptedFileURL = URL(fileURLWithPath: item.encryptedFileURL)
            try fileManager.removeItem(at: encryptedFileURL)
            
            // Remove from items array
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
            
            // Update database
            try await saveItems()
            
            logger.info("Successfully deleted item: \(item.id)")
        } catch {
            logger.error("Failed to delete item: \(error.localizedDescription)")
            throw VaultError.fileOperationFailed("Failed to delete file: \(error.localizedDescription)")
        }
    }
} 