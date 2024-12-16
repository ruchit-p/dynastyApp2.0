import SwiftUI
import OSLog

struct VaultGrid: View {
    let items: [VaultItem]
    @Binding var selectedItems: Set<VaultItem>
    @Binding var isSelecting: Bool
    @Binding var error: Error?
    @Binding var showError: Bool
    @EnvironmentObject var vaultManager: VaultManager
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    private let logger = Logger(subsystem: "com.dynasty.app", category: "VaultGrid")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    ItemViewContent(
                        item: item,
                        isSelecting: $isSelecting,
                        selectedItems: $selectedItems,
                        error: $error,
                        showError: $showError
                    )
                }
            }
            .padding()
        }
    }
}

struct ItemViewContent: View {
    let item: VaultItem
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    @Binding var error: Error?
    @Binding var showError: Bool
    @EnvironmentObject var vaultManager: VaultManager
    
    private let logger = Logger(subsystem: "com.dynasty.app", category: "VaultGrid")
    
    var body: some View {
        VStack(spacing: 8) {
            VaultItemThumbnailView(item: item)
                .aspectRatio(1, contentMode: .fill)
                .onTapGesture {
                    if isSelecting {
                        if selectedItems.contains(item) {
                            selectedItems.remove(item)
                        } else {
                            selectedItems.insert(item)
                        }
                    } else {
                        Task {
                            do {
                                try await vaultManager.previewFile(item)
                            } catch {
                                logger.error("Failed to preview file: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    isSelecting ? SelectionOverlay(
                        selectedItems: $selectedItems,
                        isSelecting: $isSelecting,
                        error: $error,
                        showError: $showError,
                        refreshItems: { /* No refresh needed here */ },
                        isSelected: selectedItems.contains(item),
                        action: {
                            if selectedItems.contains(item) {
                                selectedItems.remove(item)
                            } else {
                                selectedItems.insert(item)
                            }
                        }
                    ) : nil
                )
            Text(item.title)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
