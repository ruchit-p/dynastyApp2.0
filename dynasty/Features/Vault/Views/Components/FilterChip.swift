import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct FilterBar: View {
    @Binding var selectedType: VaultItemType?
    @Binding var searchText: String
    var currentFolderId: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                    isSearchFocused = false
                }
                FilterChip(title: "Documents", isSelected: selectedType == .document) {
                    selectedType = .document
                    isSearchFocused = false
                }
                FilterChip(title: "Photos", isSelected: selectedType == .image) {
                    selectedType = .image
                    isSearchFocused = false
                }
                FilterChip(title: "Videos", isSelected: selectedType == .video) {
                    selectedType = .video
                    isSearchFocused = false
                }
                FilterChip(title: "Audio", isSelected: selectedType == .audio) {
                    selectedType = .audio
                    isSearchFocused = false
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func filterItemsByFolder(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            if let folderId = currentFolderId {
                return item.parentFolderId == folderId
            } else {
                return item.parentFolderId == nil
            }
        }
    }

    private func filterItemsBySearchText(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            searchText.isEmpty ||
            item.title.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func filterItemsByType(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            selectedType == nil || item.fileType == selectedType
        }
    }
} 