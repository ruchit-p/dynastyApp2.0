import Foundation

enum VaultItemType: String, Codable {
    case document
    case image
    case video
    case audio
    case folder
    
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
        case .folder:
            return 0 // Folders don't have a file size
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
        case .folder:
            return ["application/vnd.folder"]
        }
    }
}

struct VaultItemMetadata: Codable {
    let originalFileName: String
    let fileSize: Int64
    let mimeType: String
    let encryptionKeyId: String
    let hash: String
}

struct VaultItem: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    var title: String
    let description: String?
    let fileType: VaultItemType
    let encryptedFileName: String
    let storagePath: String
    let thumbnailURL: String?
    var metadata: VaultItemMetadata
    let createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    let parentFolderId: String?
    
    init(id: String, userId: String, title: String, description: String?, fileType: VaultItemType, 
         encryptedFileName: String, storagePath: String, thumbnailURL: String?, metadata: VaultItemMetadata, 
         createdAt: Date, updatedAt: Date, isDeleted: Bool = false, parentFolderId: String? = nil) {
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
        self.parentFolderId = parentFolderId
    }
}

extension VaultItem {
    static func == (lhs: VaultItem, rhs: VaultItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 