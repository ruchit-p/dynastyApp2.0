import Foundation
import os.log
import SwiftUI

@MainActor
class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [VaultItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUploading = false
    @Published private(set) var uploadProgress: Double = 0
    @Published var error: Error?
    @Published var showError = false
    
    private let vaultManager = VaultManager.shared
    private let logger = Logger(subsystem: "com.dynasty.DocumentsViewModel", category: "Documents")
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
    init() {
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func loadDocuments(userId: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        do {
            logger.info("Loading documents for user: \(userId)")
            documents = try await vaultManager.loadItems()
            logger.info("Successfully loaded \(self.documents.count) documents")
        } catch {
            logger.error("Failed to load documents: \(error.localizedDescription)")
            self.error = error
            self.showError = true
        }
        isLoading = false
    }
    
    func importDocuments(from urls: [URL], userId: String) async {
        guard !isUploading else { return }
        
        isUploading = true
        uploadProgress = 0
        
        do {
            logger.info("Importing \(urls.count) documents for user: \(userId)")
            try await vaultManager.importItems(from: urls, userId: userId)
            // Reload documents after import
            await loadDocuments(userId: userId)
            logger.info("Successfully imported documents")
        } catch {
            logger.error("Failed to import documents: \(error.localizedDescription)")
            self.error = error
            self.showError = true
        }
        
        isUploading = false
        uploadProgress = 0
    }
    
    func deleteDocuments(at offsets: IndexSet, userId: String) async {
        do {
            logger.info("Deleting documents at offsets: \(offsets)")
            try await vaultManager.deleteItems(at: offsets)
            // Reload documents after deletion
            await loadDocuments(userId: userId)
            logger.info("Successfully deleted documents")
        } catch {
            logger.error("Failed to delete documents: \(error.localizedDescription)")
            self.error = error
            self.showError = true
        }
    }
    
    func downloadDocument(_ document: VaultItem, userId: String) async throws -> Data {
        logger.info("Downloading document: \(document.id)")
        do {
            let data = try await vaultManager.getDecryptedData(for: document, userId: userId)
            logger.info("Successfully downloaded document: \(document.id)")
            return data
        } catch {
            logger.error("Failed to download document: \(error.localizedDescription)")
            throw error
        }
    }
    
    func clearCache() {
        logger.info("Clearing thumbnail cache")
        thumbnailCache.removeAllObjects()
    }
} 
