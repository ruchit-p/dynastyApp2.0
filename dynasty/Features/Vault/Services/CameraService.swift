import SwiftUI
import AVFoundation
import os.log

class CameraService: ObservableObject {
    @Published var error: Error?
    @Published var showError = false
    @Published private(set) var isProcessing = false

    private let logger = Logger(subsystem: "com.dynasty.CameraService", category: "Camera")

    @MainActor
    func handleImage(image: UIImage, vaultManager: VaultManager, currentFolderId: String?) async {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            logger.error("Could not get JPEG representation of image")
            self.error = VaultError.invalidData("Could not process image")
            self.showError = true
            return
        }

        do {
            guard let userId = vaultManager.currentUser?.id else {
                logger.error("No authenticated user")
                self.error = VaultError.authenticationFailed("Please sign in to upload photos")
                self.showError = true
                return
            }

            let filename = "\(UUID().uuidString).jpg"
            let encryptionKeyId = try  vaultManager.generateEncryptionKey(for: userId)

            let metadata = VaultItemMetadata(
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
                userId: userId,
                parentFolderId: currentFolderId
            )

            logger.info("Successfully uploaded photo: \(filename)")
        } catch {
            logger.error("Failed to upload photo: \(error.localizedDescription)")
            self.error = error
            self.showError = true
        }
    }
} 
