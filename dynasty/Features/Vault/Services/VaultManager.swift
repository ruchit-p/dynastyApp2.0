import Foundation
import FirebaseStorage
import FirebaseFirestore
import Combine

enum VaultError: LocalizedError {
    case fileTooLarge
    case encodingFailed
    case decodingFailed
    case uploadFailed
    case downloadFailed
    case deletionFailed
    case invalidFileType
    case fileNotFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "File size exceeds maximum allowed size"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode data"
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        case .deletionFailed:
            return "Failed to delete file"
        case .invalidFileType:
            return "Invalid file type"
        case .fileNotFound:
            return "File not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}

class VaultManager: ObservableObject {
    static let shared = VaultManager()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private let encryptionService = VaultEncryptionService.shared
    
    @Published var items: [VaultItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
    
    // Upload file to vault
    func uploadFile(userId: String, fileURL: URL, title: String, description: String?, type: VaultItemType) async throws -> VaultItem {
        isLoading = true
        defer { isLoading = false }
        
        // Validate file size
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard Int64(fileSize) <= type.maxFileSize else {
            throw VaultError.fileTooLarge
        }
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        
        // Generate encryption key
        let keyId = try encryptionService.generateEncryptionKey(for: userId)
        
        // Encrypt file
        let (encryptedData, iv) = try encryptionService.encryptFile(data: fileData, userId: userId, keyId: keyId)
        
        // Generate file hash
        let fileHash = encryptionService.generateFileHash(for: fileData)
        
        // Create storage reference
        let fileName = UUID().uuidString
        let storageRef = storage.reference().child("users/\(userId)/vault/\(fileName)")
        
        // Upload encrypted file
        let metadata = StorageMetadata()
        metadata.contentType = type.allowedMimeTypes.first
        
        _ = try await storageRef.putDataAsync(encryptedData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        // Create vault item
        let vaultItem = VaultItem(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            description: description,
            fileType: type,
            encryptedFileURL: downloadURL.absoluteString,
            thumbnailURL: nil,
            metadata: VaultItemMetadata(
                originalFileName: fileURL.lastPathComponent,
                fileSize: Int64(fileSize),
                mimeType: type.allowedMimeTypes.first ?? "application/octet-stream",
                encryptionKeyId: keyId,
                iv: iv,
                hash: fileHash
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save to Firestore
        try await db.collection("vaultItems").document(vaultItem.id).setData(try encodeToDict(vaultItem))
        
        return vaultItem
    }
    
    // Download and decrypt file
    func downloadFile(item: VaultItem) async throws -> Data {
        isLoading = true
        defer { isLoading = false }
        
        // Download encrypted file
        let storageRef = storage.reference(forURL: item.encryptedFileURL)
        let encryptedData = try await storageRef.data(maxSize: Int64.max)
        
        // Decrypt file
        let decryptedData = try encryptionService.decryptFile(
            encryptedData: encryptedData,
            userId: item.userId,
            keyId: item.metadata.encryptionKeyId,
            iv: item.metadata.iv
        )
        
        // Verify file integrity
        let fileHash = encryptionService.generateFileHash(for: decryptedData)
        guard fileHash == item.metadata.hash else {
            throw VaultEncryptionError.fileIntegrityCompromised
        }
        
        return decryptedData
    }
    
    // Fetch vault items for user
    func fetchItems(for userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let snapshot = try await db.collection("vaultItems")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        items = try snapshot.documents.compactMap { document in
            let data = document.data()
            return try decodeFromDict(data, type: VaultItem.self)
        }
    }
    
    // Delete vault item
    func deleteItem(_ item: VaultItem) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Delete from Storage
        let storageRef = storage.reference(forURL: item.encryptedFileURL)
        try await storageRef.delete()
        
        // Delete from Firestore
        try await db.collection("vaultItems").document(item.id).delete()
        
        // Delete encryption key
        _ = encryptionService.deleteEncryptionKey(for: item.userId, keyId: item.metadata.encryptionKeyId)
        
        // Remove from local array
        items.removeAll { $0.id == item.id }
    }
    
    // Helper functions for Firestore encoding/decoding
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VaultError.encodingFailed
        }
        return dict
    }
    
    private func decodeFromDict<T: Decodable>(_ dict: [String: Any], type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
} 