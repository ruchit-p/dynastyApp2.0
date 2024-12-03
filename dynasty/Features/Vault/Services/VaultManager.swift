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
    
    // MARK: - Published Properties
    @Published private(set) var items: [VaultItem] = []
    @Published private(set) var isLocked = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isDocumentPickerPresented = false
    @Published private(set) var isProcessing = false
    @Published private(set) var processingProgress: Double = 0
    @Published var currentUser: User?
    
    // MARK: - Private Properties
    let encryptionService: VaultEncryptionService
    private let storageService: FirebaseStorageService
    private let dbManager: Vault.DatabaseManager
    private let logger = Logger(subsystem: "com.dynasty.VaultManager", category: "Vault")
    private var currentAuthenticationTask: Task<Void, Error>?
    private var processingTask: Task<Void, Error>?
    
    private init() {
        self.encryptionService = VaultEncryptionService()
        self.storageService = FirebaseStorageService.shared
        self.dbManager = Vault.DatabaseManager.shared
        logger.info("VaultManager initialized")
    }
    
    // MARK: - Public Methods
    func setCurrentUser(_ user: User?) {
        self.currentUser = user
        if user != nil {
            Task {
                try? await self.loadItems()
            }
        }
    }
    
    func setDocumentPickerPresented(_ isPresented: Bool) {
        self.isDocumentPickerPresented = isPresented
    }
    
    func unlock() async throws {
        guard !self.isAuthenticating else { return }
        
        self.isAuthenticating = true
        defer { self.isAuthenticating = false }
        
        do {
            try await self.encryptionService.initialize()
            try await self.dbManager.openDatabase()
            try await self.loadItems()
            self.isLocked = false
            self.logger.info("Vault unlocked successfully")
        } catch {
            self.logger.error("Failed to unlock vault: \(error.localizedDescription)")
            throw error
        }
    }
    
    func lock() {
        self.isLocked = true
        self.items.removeAll()
        self.logger.info("Vault locked")
    }
    
    func loadItems() async throws {
        self.logger.info("Loading vault items")
        do {
            self.items = try await self.dbManager.fetchItems()
            self.logger.info("Successfully loaded \(self.items.count) items")
        } catch {
            self.logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func importItems(from urls: [URL], userId: String) async throws {
        guard !self.isProcessing else { return }
        
        self.isProcessing = true
        self.processingProgress = 0
        
        defer {
            self.isProcessing = false
            self.processingProgress = 0
        }
        
        do {
            self.logger.info("Importing \(urls.count) documents for user: \(userId)")
            let total = Double(urls.count)
            
            for (index, url) in urls.enumerated() {
                try await self.importFile(from: url, userId: userId)
                self.processingProgress = Double(index + 1) / total
            }
            
            try await self.loadItems()
            self.logger.info("Successfully imported all items")
        } catch {
            self.logger.error("Failed to import items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func importData(_ data: Data, filename: String, fileType: VaultItemType, metadata: VaultItemMetadata, userId: String) async throws {
        guard !self.isLocked else {
            throw VaultError.vaultLocked
        }
        
        self.logger.info("Importing data with filename: \(filename)")
        
        do {
            // Encrypt the data
            self.logger.info("Encrypting data")
            let (encryptedData, iv) = try self.encryptionService.encryptFile(
                data: data,
                userId: userId,
                keyId: metadata.encryptionKeyId
            )
            
            // Upload to Firebase Storage
            self.logger.info("Uploading encrypted data to Firebase Storage")
            let storagePath = try await self.storageService.uploadEncryptedData(
                encryptedData,
                fileName: filename,
                userId: userId
            )
            
            // Create vault item
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
            
            // Add to items array and save to database
            self.items.append(item)
            try await self.dbManager.saveItems(self.items)
            
            self.logger.info("Successfully imported data: \(filename)")
        } catch {
            self.logger.error("Failed to import data: \(error.localizedDescription)")
            throw error
        }
    }
    
    func downloadFile(_ item: VaultItem, userId: String, progressHandler: ((Double) -> Void)? = nil) async throws -> Data {
        guard !self.isLocked else {
            throw VaultError.vaultLocked
        }
        
        do {
            self.logger.info("Downloading file: \(item.encryptedFileName)")
            let encryptedData = try await self.storageService.downloadEncryptedData(
                from: item.storagePath,
                progressHandler: progressHandler
            )
            
            self.logger.info("Decrypting file")
            let decryptedData = try self.encryptionService.decryptFile(
                encryptedData: encryptedData,
                userId: userId,
                keyId: item.metadata.encryptionKeyId,
                iv: item.metadata.iv
            )
            
            self.logger.info("Successfully downloaded and decrypted file")
            return decryptedData
        } catch {
            self.logger.error("Failed to download file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteItems(at offsets: IndexSet) async throws {
        guard !self.isLocked else {
            throw VaultError.vaultLocked
        }
        
        do {
            self.logger.info("Deleting items at offsets: \(offsets)")
            var updatedItems = self.items
            let itemsToDelete = offsets.map { updatedItems[$0] }
            
            for item in itemsToDelete {
                var deletedItem = item
                deletedItem.isDeleted = true
                if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
                    updatedItems[index] = deletedItem
                }
            }
            
            self.items = updatedItems
            try await self.dbManager.saveItems(self.items)
            self.logger.info("Successfully deleted items")
        } catch {
            self.logger.error("Failed to delete items: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    private func importFile(from url: URL, userId: String) async throws {
        self.logger.info("Starting import of file: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            let filename = "\(UUID().uuidString).\(url.pathExtension)"
            let fileType = self.determineFileType(from: url)
            
            // Generate encryption key
            self.logger.info("Generating encryption key")
            let keyId = try self.encryptionService.generateEncryptionKey(for: userId)
            
            let metadata = VaultItemMetadata(
                originalFileName: url.lastPathComponent,
                fileSize: Int64(data.count),
                mimeType: self.determineMimeType(from: url),
                encryptionKeyId: keyId,
                iv: Data(),
                hash: self.encryptionService.generateFileHash(for: data)
            )
            
            try await self.importData(data, filename: filename, fileType: fileType, metadata: metadata, userId: userId)
        } catch {
            self.logger.error("Failed to import file: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func determineFileType(from url: URL) -> VaultItemType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic":
            return .image
        case "mp4", "mov":
            return .video
        case "mp3", "m4a", "wav":
            return .audio
        default:
            return .document
        }
    }
    
    private func determineMimeType(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
} 