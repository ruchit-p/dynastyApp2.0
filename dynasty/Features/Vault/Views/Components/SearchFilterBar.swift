import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search files", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    isSearchFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct FilterBar: View {
    @Binding var selectedType: VaultItemType?
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
} 