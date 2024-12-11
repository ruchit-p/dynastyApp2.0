import SwiftUI
import os.log

class VaultFileManagementFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "FileManagement")
    
    static func handleFileImport(_ result: Result<[URL], Error>, vaultManager: VaultManager, currentFolderId: String?) async {
        switch result {
        case .success(let urls):
            do {
                guard let userId = await vaultManager.currentUser?.id else { return }
                try await vaultManager.importItems(from: urls, userId: userId, parentFolderId: currentFolderId)
            } catch {
                logger.error("Failed to import files: \(error)")
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("VaultFileError"), object: error)
                }
            }
        case .failure(let error):
            logger.error("File import failed: \(error)")
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("VaultFileError"), object: error)
            }
        }
    }
    
    static func createNewFolder(name: String, currentFolderId: String?, vaultManager: VaultManager) async throws {
        guard !name.isEmpty else {
            throw VaultError.invalidData("Folder name cannot be empty")
        }
        
        guard let userId = await vaultManager.currentUser?.id else {
            throw VaultError.authenticationFailed("User not authenticated")
        }
        
        let keyId = try await vaultManager.generateEncryptionKey(for: userId)
        
        let metadata = VaultItemMetadata(
            originalFileName: name,
            fileSize: 0,
            mimeType: "application/vnd.folder",
            encryptionKeyId: keyId,
            hash: ""
        )
        
        try await vaultManager.createFolder(named: name, parentFolderId: currentFolderId)
        await vaultManager.clearItemsCache()
        try await refreshItems(vaultManager: vaultManager)
    }
    
    static func refreshItems(vaultManager: VaultManager, sortOption: SortOption = .date, isAscending: Bool = false) async throws {
        guard let userId = await vaultManager.currentUser?.id else {
            logger.error("Cannot refresh: No authenticated user")
            throw VaultError.authenticationFailed("Please sign in to access your vault")
        }
        try await vaultManager.loadItems(for: userId, sortOption: sortOption, isAscending: isAscending)
    }
} 
