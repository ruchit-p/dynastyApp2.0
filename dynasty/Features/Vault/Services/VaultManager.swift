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
    
    // Cache properties
    private var fileDataCache: [String: Data] = [:]
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    // New properties for authentication tracking
    private var failedAttempts = 0
    private var lockUntil: Date?
    
    private init() {
        self.encryptionService = VaultEncryptionService(keychainHelper: KeychainHelper.shared)
        self.storageService = FirebaseStorageService.shared
        logger.info("VaultManager initialized")
    }
    
    // MARK: - Cache Methods
    
    func cachedFileData(for item: VaultItem) -> Data? {
        return fileDataCache[item.id]
    }
    
    func cacheFileData(_ data: Data, for item: VaultItem) {
        fileDataCache[item.id] = data
    }
    
    func cachedThumbnail(for item: VaultItem) -> UIImage? {
        if let cachedImage = thumbnailCache.object(forKey: item.id as NSString) {
            return cachedImage
        }

        // Try loading from encrypted disk cache
        do {
            if let diskThumbnail = try loadEncryptedThumbnail(for: item) {
                thumbnailCache.setObject(diskThumbnail, forKey: item.id as NSString)
                return diskThumbnail
            }
        } catch {
            logger.error("Failed to load encrypted thumbnail for \(item.id): \(error.localizedDescription)")
        }
        return nil
    }
    
    func cacheThumbnail(_ image: UIImage, for item: VaultItem) {
        do {
            try cacheEncryptedThumbnail(image, for: item)
        } catch {
            logger.error("Failed to cache encrypted thumbnail for \(item.id): \(error.localizedDescription)")
        }
    }
    
    func clearCache() {
        fileDataCache.removeAll()
        thumbnailCache.removeAllObjects()
        logger.info("In-memory caches cleared")
    }
    
    // MARK: - Authentication Methods
    
    private func authenticateUser() async throws {
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
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Access your vault") { success, error in
                    if success {
                        continuation.resume()
                    } else if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: VaultError.authenticationFailed("Unknown authentication error"))
                    }
                }
            }
            
            failedAttempts = 0
            logger.info("User successfully authenticated via biometrics/passcode")
        } catch {
            failedAttempts += 1
            if failedAttempts >= 3 {
                lockUntil = Date().addingTimeInterval(5 * 60) // Lock for 5 minutes
            }
            throw error
        }
    }
    
    // MARK: - Public Methods
    
    func generateEncryptionKey(for userId: String) throws -> String {
        logger.info("Generating encryption key for user: \(userId)")
        
        let (key, keyId) = encryptionService.generateEncryptionKey()
        
        // Verify the key was stored successfully
        do {
            _ = try encryptionService.keychainHelper.loadEncryptionKey(for: keyId)
            logger.info("Successfully verified encryption key storage for key: \(keyId)")
        } catch {
            logger.error("Failed to verify encryption key storage: \(error.localizedDescription)")
            throw VaultError.encryptionFailed("Failed to store encryption key: \(error.localizedDescription)")
        }
        
        logger.info("Successfully generated encryption key: \(keyId)")
        return keyId
    }
    
    func unlock() async throws {
        guard let user = currentUser, let userId = user.id else {
            throw VaultError.authenticationFailed("No authenticated user found")
        }
        
        try await authenticateUser()
        
        do {
            try await dbManager.openDatabase(for: userId)
            try await loadItems(for: userId)
            isLocked = false
            logger.info("Vault unlocked successfully for user: \(userId)")
        } catch {
            logger.error("Failed to unlock vault after authentication: \(error.localizedDescription)")
            throw error
        }
    }
    
    func loadItems(for userId: String) async throws {
        logger.info("Loading vault items for user: \(userId)")
        do {
            self.items = try await dbManager.fetchItems(for: userId)
            logger.info("Successfully loaded \(self.items.count) items for user: \(userId)")
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }
    
    func renameItem(_ item: VaultItem, to newName: String) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        guard let userId = currentUser?.id else {
            throw VaultError.authenticationFailed("No authenticated user")
        }
        
        logger.info("Renaming item \(item.id) to: \(newName)")
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.title = newName
            updatedItem.updatedAt = Date()
            items[index] = updatedItem
            
            try await dbManager.saveItems(items, for: userId)
            clearItemsCache()
            logger.info("Successfully renamed item: \(item.id)")
        } else {
            throw VaultError.itemNotFound("Item not found for renaming")
        }
    }

    private var itemsCache: [String: [VaultItem]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.dynasty.VaultManager.cacheQueue")


func loadItems(for userId: String, sortOption: SortOption, isAscending: Bool) async throws {
        logger.info("Loading vault items for user: \(userId) with sorting")
        
        let cacheKey = "\(userId)-\(sortOption.rawValue)-\(isAscending)"
        
        // Check cache first
        if let cachedItems = itemsCache[cacheKey] {
            logger.info("Using cached items for key: \(cacheKey)")
            await MainActor.run {
                self.items = cachedItems
            }
            return
        }
        
        do {
            let fetchedItems = try await dbManager.fetchItems(for: userId, sortOption: sortOption, isAscending: isAscending)
            await MainActor.run {
                self.items = fetchedItems
            }
            // Cache the fetched items
            cacheQueue.sync {
                self.itemsCache[cacheKey] = fetchedItems
            }
            
            logger.info("Successfully loaded \(self.items.count) items for user: \(userId) and cached with key: \(cacheKey)")
        } catch {
            logger.error("Failed to load items: \(error.localizedDescription)")
            throw error
        }
    }

    func clearItemsCache() {
        cacheQueue.sync {
            itemsCache.removeAll()
        }
    }
    
    func createFolder(named name: String, parentFolderId: String? = nil) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        guard let userId = currentUser?.id else {
            throw VaultError.authenticationFailed("No authenticated user")
        }
        
        logger.info("Creating folder: \(name)")
        
        let keyId = try generateEncryptionKey(for: userId)
        
        let metadata = VaultItemMetadata(
            originalFileName: name,
            fileSize: 0,
            mimeType: "application/vnd.folder",
            encryptionKeyId: keyId,
            hash: generateFileHash(for: Data())
        )
        
        let folderId = UUID().uuidString
        
        let folder = VaultItem(
            id: folderId,
            userId: userId,
            title: name,
            description: nil,
            fileType: .folder,
            encryptedFileName: folderId,
            storagePath: "",
            thumbnailURL: nil,
            metadata: metadata,
            createdAt: Date(),
            updatedAt: Date(),
            isDeleted: false,
            parentFolderId: parentFolderId
        )
        
        items.append(folder)
        try await dbManager.saveItems(items, for: userId)
        
        logger.info("Successfully created folder: \(name)")
    }
    
    func moveToTrash(_ item: VaultItem) async throws {
        guard let userId = currentUser?.id else {
            throw VaultError.authenticationFailed("No authenticated user")
        }
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.isDeleted = true
            updatedItem.updatedAt = Date()
            items[index] = updatedItem
            
            // Remove from caches when moved to trash
            fileDataCache.removeValue(forKey: item.id)
            thumbnailCache.removeObject(forKey: item.id as NSString)
            
            try await dbManager.saveItems(items, for: userId)
            clearItemsCache()
            logger.info("Item moved to trash and removed from cache: \(item.id)")
        } else {
            throw VaultError.itemNotFound("Item not found to move to trash")
        }
    }
    
    func restoreItem(_ item: VaultItem) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        guard let userId = currentUser?.id else {
            throw VaultError.authenticationFailed("No authenticated user")
        }
        
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var restoredItem = items[index]
            restoredItem.isDeleted = false
            restoredItem.updatedAt = Date()
            items[index] = restoredItem
            try await dbManager.saveItems(items, for: userId)
            logger.info("Successfully restored item: \(item.id)")
        } else {
            throw VaultError.itemNotFound("Item not found to restore")
        }
    }
    
func permanentlyDeleteItem(_ item: VaultItem) async throws {
    guard !isLocked else {
        throw VaultError.vaultLocked
    }

    guard let userId = currentUser?.id else {
        throw VaultError.authenticationFailed("No authenticated user")
    }

    logger.info("Permanently deleting item: \(item.id)")

    do {
        try await storageService.deleteFile(at: item.storagePath)
        items.removeAll(where: { $0.id == item.id })

        // Remove from caches when permanently deleted
        fileDataCache.removeValue(forKey: item.id)
        thumbnailCache.removeObject(forKey: item.id as NSString) // Fixed line

        try await dbManager.deleteItem(item, for: userId)
        
        logger.info("Successfully deleted item permanently: \(item.id)")
    } catch {
        logger.error("Failed to permanently delete item: \(error.localizedDescription)")
        throw error
        }
    }
    
    // Public methods for encryption service functionality
    func generateFileHash(for data: Data) -> String {
        return encryptionService.generateFileHash(for: data)
    }
    
    func downloadFile(_ item: VaultItem) async throws -> Data {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        // Check cache first
        if let cachedData = fileDataCache[item.id] {
            logger.info("Using cached data for file: \(item.id)")
            return cachedData
        }
        
        logger.info("Downloading file: \(item.id)")
        do {
            let encryptedData = try await storageService.downloadEncryptedData(from: item.storagePath) { progress in
                Task { @MainActor in
                    self.processingProgress = progress
                }
            }
            
            let decryptedData = try encryptionService.decryptFile(
                encryptedData: encryptedData,
                userId: item.userId,
                keyId: item.metadata.encryptionKeyId
            )
            
            let fileHash = encryptionService.generateFileHash(for: decryptedData)
            guard fileHash == item.metadata.hash else {
                throw VaultError.fileOperationFailed("File integrity check failed")
            }
            
            // Cache the decrypted data
            fileDataCache[item.id] = decryptedData
            
            logger.info("Successfully downloaded and decrypted file: \(item.id)")
            return decryptedData
        } catch {
            logger.error("Failed to download file: \(error.localizedDescription)")
            throw error
        }
    }
    
    func importData(
        _ data: Data,
        filename: String,
        fileType: VaultItemType,
        metadata: VaultItemMetadata,
        userId: String,
        parentFolderId: String? = nil
    ) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        logger.info("Starting import for file: \(filename)")
        
        // Generate storage path
        var storagePath = "users/\(userId)/files/\(filename)"
        
        // Encrypt the data
        let encryptedData = try encryptionService.encryptFile(data: data, userId: userId, keyId: metadata.encryptionKeyId)
        
        // Upload to Firebase Storage
        storagePath = try await storageService.uploadEncryptedData(encryptedData, fileName: filename, userId: userId)
        
        let item = VaultItem(
            id: UUID().uuidString,
            userId: userId,
            title: metadata.originalFileName,
            description: nil,
            fileType: fileType,
            encryptedFileName: filename,
            storagePath: storagePath,
            thumbnailURL: nil,
            metadata: metadata,
            createdAt: Date(),
            updatedAt: Date(),
            isDeleted: false,
            parentFolderId: parentFolderId
        )
        
        items.append(item)
        try await dbManager.saveItems(items, for: userId)
        clearItemsCache()
        logger.info("Successfully imported data")
    }
    
    // MARK: - Private Helper Methods
    private func importFile(
        from url: URL,
        userId: String,
        parentFolderId: String?
    ) async throws {
        let fileData = try Data(contentsOf: url)
        let fileType = try determineFileType(from: url)
        let encryptionKeyId = try generateEncryptionKey(for: userId)
        
        let metadata = VaultItemMetadata(
            originalFileName: url.lastPathComponent,
            fileSize: Int64(fileData.count),
            mimeType: try determineMimeType(from: url),
            encryptionKeyId: encryptionKeyId,
            hash: generateFileHash(for: fileData)
        )
        
        try await importData(
            fileData,
            filename: UUID().uuidString,
            fileType: fileType,
            metadata: metadata,
            userId: userId,
            parentFolderId: parentFolderId
        )
    }
    
    private func determineFileType(from url: URL) throws -> VaultItemType {
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
        throw VaultError.invalidData("Invalid file type")
    }
    
    private func determineMimeType(from url: URL) throws -> String {
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let type = UTType(uti) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        throw VaultError.invalidData("Invalid MIME type")
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
        try await dbManager.saveItems(items, for: userId)
        self.logger.info("Items saved to Firestore for user: \(userId)")
    }
    
    // MARK: - User Management
    
    func setCurrentUser(_ user: User?) {
        self.currentUser = user
        if user == nil {
            lock()
        }
    }
    
    func lock() {
        self.isLocked = true
        self.items = []
        clearCache() // Clear in-memory cache only
        // Encrypted thumbnails remain on disk but can't be decrypted until unlocked
        logger.info("Vault locked and in-memory caches cleared")
    }
    
    // MARK: - File Import
    
    func importItems(
        from urls: [URL],
        userId: String,
        parentFolderId: String? = nil
    ) async throws {
        guard !isLocked else {
            throw VaultError.vaultLocked
        }
        
        for url in urls {
            try await importFile(from: url, userId: userId, parentFolderId: parentFolderId)
        }
    }
    
    // MARK: - Thumbnail Cache Methods
    
    private func localThumbnailURL(for item: VaultItem) -> URL {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDirectory.appendingPathComponent("\(item.id)_thumbnail.enc")
    }
    
    func cacheEncryptedThumbnail(_ image: UIImage, for item: VaultItem) throws {
        guard let currentUser = currentUser, let userId = currentUser.id else { return }
        
        // Convert UIImage to Data (PNG for best quality)
        guard let imageData = image.pngData() else { return }
        
        // Encrypt the thumbnail data
        let encryptedData = try encryptionService.encryptFile(
            data: imageData,
            userId: userId,
            keyId: item.metadata.encryptionKeyId
        )
        
        // Write encrypted data to local file
        let url = localThumbnailURL(for: item)
        try encryptedData.write(to: url, options: .atomic)
        
        // Store a reference in memory
        thumbnailCache.setObject(image, forKey: item.id as NSString)
        
        logger.info("Successfully cached encrypted thumbnail for item: \(item.id)")
    }

    // Set a limit to the cache
    

    // Optionally, clear cache when receiving memory warnings
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(clearMemoryCaches),
        name: UIApplication.didReceiveMemoryWarningNotification,
        object: nil
    )

    @objc private func clearMemoryCaches() {
        thumbnailCache.removeAllObjects()
        fileDataCache.removeAll()
        logger.info("Memory caches cleared due to memory warning")
    }
    
    func loadEncryptedThumbnail(for item: VaultItem) throws -> UIImage? {
        guard !isLocked else {
            logger.info("Cannot load thumbnail: vault is locked")
            return nil
        }
        
        guard let currentUser = currentUser, let userId = currentUser.id else {
            logger.error("Cannot load thumbnail: no authenticated user")
            return nil
        }
        
        let url = localThumbnailURL(for: item)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.info("No cached thumbnail found for item: \(item.id)")
            return nil
        }
        
        let encryptedData = try Data(contentsOf: url)
        let decryptedData = try encryptionService.decryptFile(
            encryptedData: encryptedData,
            userId: userId,
            keyId: item.metadata.encryptionKeyId
        )
        
        guard let image = UIImage(data: decryptedData) else {
            throw VaultError.invalidData("Could not create image from decrypted data")
        }
        
        return image
    }
    
    // Add method to clear disk cache if needed
    func clearDiskCache() {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for url in contents where url.lastPathComponent.hasSuffix("_thumbnail.enc") {
                try FileManager.default.removeItem(at: url)
            }
            logger.info("Disk cache cleared successfully")
        } catch {
            logger.error("Failed to clear disk cache: \(error.localizedDescription)")
        }
    }
}
