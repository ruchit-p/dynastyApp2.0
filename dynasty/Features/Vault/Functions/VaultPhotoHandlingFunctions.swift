import SwiftUI
import os.log
import PhotosUI

class VaultPhotoHandlingFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "PhotoHandling")
    
    static func handleSelectedPhotos(_ items: [PhotosPickerItem], vaultManager: VaultManager, authManager: AuthManager) async {
        guard let _ = await authManager.user?.id else {
            logger.error("Cannot import photos: No authenticated user")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("VaultPhotoError"),
                    object: VaultError.authenticationFailed("Please sign in to import photos")
                )
            }
            return
        }
        
        do {
            let userId = await authManager.user?.id ?? ""
            logger.info("Processing selected photos for user: \(userId)")
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let filename = "\(UUID().uuidString).jpg"
                    let encryptionKeyId = try await vaultManager.generateEncryptionKey(for: authManager.user?.id ?? "")
                    
                    let metadata = await VaultItemMetadata(
                        originalFileName: filename,
                        fileSize: Int64(data.count),
                        mimeType: "image/jpeg",
                        encryptionKeyId: encryptionKeyId,
                        hash: vaultManager.generateFileHash(for: data)
                    )
                    
                    try await vaultManager.importData(
                        data,
                        filename: filename,
                        fileType: .image,
                        metadata: metadata,
                        userId: authManager.user?.id ?? "",
                        parentFolderId: nil
                    )
                }
            }
            logger.info("Successfully imported photos")
        } catch {
            logger.error("Failed to import photos: \(error.localizedDescription)")
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("VaultPhotoError"), object: error)
            }
        }
    }
} 
