import SwiftUI

struct VaultContentView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @Binding var selectedItems: Set<VaultItem>
    @Binding var isSelecting: Bool
    @Binding var error: Error?
    @Binding var showError: Bool
    let selectedType: VaultItemType?
    let currentFolderId: String?
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 2)
    ]
    
    private var filteredItems: [VaultItem] {
        vaultManager.items
            .filter { item in
                !item.isDeleted &&
                (selectedType == nil || item.fileType == selectedType) &&
                (currentFolderId == item.parentFolderId)
            }
    }
    
    var body: some View {
        RefreshableView(
            isRefreshing: vaultManager.isRefreshing,
            onRefresh: handleRefresh
        ) {
            ZStack {
                if filteredItems.isEmpty && vaultManager.isInitializing {
                    ProgressView("Loading vault...")
                        .progressViewStyle(.circular)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No items found")
                            .font(.headline)
                        Text("Add files to your vault to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(filteredItems) { item in
                            VaultItemThumbnailView(item: item)
                                .onTapGesture {
                                    handleItemTap(item)
                                }
                        }
                    }
                }
            }
        }
    }
    
    private func handleItemTap(_ item: VaultItem) {
        if isSelecting {
            if selectedItems.contains(item) {
                selectedItems.remove(item)
            } else {
                selectedItems.insert(item)
            }
        } else {
            vaultManager.previewItem = item
            vaultManager.isPreviewPresented = true
        }
    }
    
    private func handleRefresh() async {
        do {
            try await vaultManager.refreshVault()
        } catch {
            self.error = error
            showError = true
        }
    }
}