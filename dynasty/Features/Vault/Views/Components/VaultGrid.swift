import SwiftUI
import PhotosUI

struct VaultItemGrid: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    @Binding var error: Error?
    @Binding var showError: Bool
    var refreshItems: () async -> Void
    
    let filteredItems: [VaultItem]
    let columns: [GridItem]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredItems, id: \.id) { item in
                if isSelecting {
                    SelectableItemView(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        toggleSelection: { toggleSelection(for: item) },
                        error: $error,
                        showError: $showError,
                        refreshItems: refreshItems
                    )
                } else {
                    ItemNavigationLink(
                        item: item,
                        selectedPhotos: $selectedPhotos
                    )
                }
            }
        }
        .padding()
        .refreshable {
            Task {
                await refreshItems()
            }
        }
    }
    
    private func toggleSelection(for item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
}

struct SelectableItemView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let item: VaultItem
    let isSelected: Bool
    let toggleSelection: () -> Void
    @Binding var error: Error?
    @Binding var showError: Bool
    var refreshItems: () async -> Void
    
    var body: some View {
        ZStack {
            ItemViewContent(item: item)
                .allowsHitTesting(false)
            
            SelectionOverlay(
                selectedItems: .constant([]),
                isSelecting: .constant(false),
                error: $error,
                showError: $showError,
                refreshItems: refreshItems,
                isSelected: isSelected,
                action: toggleSelection
            )
        }
    }
}

struct ItemNavigationLink: View {
    @EnvironmentObject var vaultManager: VaultManager
    let item: VaultItem
    @Binding var selectedPhotos: [PhotosPickerItem]
    
    var body: some View {
        Group {
            if item.fileType == .folder {
                NavigationLink(value: item) {
                    ItemViewContent(item: item)
                }
            } else {
                NavigationLink(destination: VaultItemDetailView(document: item)) {
                    ItemViewContent(item: item)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ItemViewContent: View {
    let item: VaultItem
    
    var body: some View {
        VStack(spacing: 8) {
            VaultItemThumbnailView(item: item)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(item.title)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
} 
