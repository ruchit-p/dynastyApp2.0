import SwiftUI
import PhotosUI

struct VaultItemGrid: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    
    let filteredItems: [VaultItem]
    let columns: [GridItem]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredItems, id: \.id) { item in
                if isSelecting {
                    SelectableItemView(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        toggleSelection: { toggleSelection(for: item) }
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
    let item: VaultItem
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            VaultItemThumbnailView(item: item)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    SelectionOverlay(isSelected: isSelected, action: toggleSelection)
                )
            Text(item.title)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleSelection)
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
