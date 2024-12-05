import Foundation

enum VaultItemType: String, Codable {
    case document
    case image
    case video
    case audio
    
    var maxFileSize: Int64 {
        switch self {
        case .document:
            return 50 * 1024 * 1024  // 50MB
        case .image:
            return 20 * 1024 * 1024  // 20MB
        case .video:
            return 500 * 1024 * 1024 // 500MB
        case .audio:
            return 100 * 1024 * 1024 // 100MB
        }
    }
    
    var allowedMimeTypes: [String] {
        switch self {
        case .document:
            return ["application/pdf", "text/plain", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
        case .image:
            return ["image/jpeg", "image/png", "image/heic"]
        case .video:
            return ["video/mp4", "video/quicktime"]
        case .audio:
            return ["audio/mpeg", "audio/mp4", "audio/x-m4a"]
        }
    }
}

struct VaultItemMetadata: Codable {
    let originalFileName: String
    let fileSize: Int64
    let mimeType: String
    let encryptionKeyId: String
    var iv: Data
    let hash: String
}

struct VaultItem: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let description: String?
    let fileType: VaultItemType
    let encryptedFileName: String
    let storagePath: String
    let thumbnailURL: String?
    var metadata: VaultItemMetadata
    let createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    
    init(id: String, userId: String, title: String, description: String?, fileType: VaultItemType, 
         encryptedFileName: String, storagePath: String, thumbnailURL: String?, metadata: VaultItemMetadata, 
         createdAt: Date, updatedAt: Date, isDeleted: Bool = false) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.fileType = fileType
        self.encryptedFileName = encryptedFileName
        self.storagePath = storagePath
        self.thumbnailURL = thumbnailURL
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
} 