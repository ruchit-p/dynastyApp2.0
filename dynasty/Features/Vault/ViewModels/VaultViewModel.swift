import SwiftUI
import Combine
import PhotosUI

@MainActor
class VaultViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published var selectedImageData: Data?
    @Published var selectedImage: Image?
    @Published var vaultItems: [VaultItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    @EnvironmentObject var vaultManager: VaultManager
    
    init() {
        setupSubscribers()
    }
    
    private func setupSubscribers() {
        $selectedItem
            .compactMap { $0 }
            .sink { [weak self] item in
                Task {
                    await self?.loadImageData(from: item)
                }
            }
            .store(in: &cancellables)
        
        $selectedImageData
            .compactMap { $0 }
            .sink { [weak self] data in
                self?.selectedImage = UIImage(data: data).map { Image(uiImage: $0) }
            }
            .store(in: &cancellables)
    }
    
    func loadImageData(from item: PhotosPickerItem) async {
        guard let imageData = try? await item.loadTransferable(type: Data.self) else {
            displayError("Failed to load image data.")
            return
        }
        await MainActor.run {
            selectedImageData = imageData
        }
    }
    
    func loadVaultItems(forUser user: User) async {
        guard let userId = user.id else {
            displayError("User ID not found.")
            return
        }
        
        isLoading = true
        do {
            vaultItems = try await vaultManager.loadItems(for: userId)
        } catch {
            displayError(error.localizedDescription)
        }
        isLoading = false
    }
    
    func addVaultItem(forUser user: User) async {
        guard let data = selectedImageData, let userId = user.id else {
            displayError("Invalid image data or user ID.")
            return
        }
        
        isLoading = true
        do {
            let vaultItem = try await vaultManager.importData(
                data,
                filename: "\(UUID().uuidString).jpg",
                fileType: .image,
                metadata: metadata,
                userId: userId,
                parentFolderId: nil
            )
            vaultItems.append(vaultItem)
            selectedImageData = nil
            selectedImage = nil
        } catch {
            displayError(error.localizedDescription)
        }
        isLoading = false
    }
    
    func deleteVaultItem(_ item: VaultItem, forUser user: User) async {
        guard let userId = user.id else {
            displayError("User ID not found.")
            return
        }
        
        isLoading = true
        do {
            try await vaultManager.moveToTrash(item)
            vaultItems.removeAll(where: { $0.id == item.id })
        } catch {
            displayError(error.localizedDescription)
        }
        isLoading = false
    }
    
    func importPhoto() async {
        guard let selectedItem = selectedItem else { return }
        isLoading = true
        do {
            guard let itemData = try await selectedItem.loadTransferable(type: Data.self) else { return }
            selectedImageData = itemData
            if let image = UIImage(data: itemData) {
                self.selectedImage = Image(uiImage: image)
            }
            
            let filename = selectedItem.itemIdentifier ?? "photo.jpg"
            let fileType: VaultItemType = .image
            
            guard let userId = vaultManager.currentUser?.id else {
                displayError("User not authenticated.")
                return
            }
            
            let metadata = VaultItemMetadata(
                originalFileName: filename,
                fileSize: Int64(itemData.count),
                mimeType: "image/jpeg",
                encryptionKeyId: try await vaultManager.generateEncryptionKey(for: userId),
                hash: vaultManager.generateFileHash(for: itemData)
            )
            
            try await vaultManager.importData(
                itemData,
                filename: filename,
                fileType: fileType,
                metadata: metadata,
                userId: userId,
                parentFolderId: nil
            )
            
            try await refreshItems()
            
        } catch {
            displayError(error.localizedDescription)
        }
        isLoading = false
    }
    
    func refreshItems() async {
        isLoading = true
        do {
            try await vaultManager.refreshVault()
        } catch {
            // Display a system error image if refresh fails
            if let image = UIImage(systemName: "exclamationmark.triangle.fill") {
                self.selectedImage = Image(uiImage: image)
            }
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }
    
    private func displayError(_ message: String) {
        errorMessage = message
        showError = true
    }
} 