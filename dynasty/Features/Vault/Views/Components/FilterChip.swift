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