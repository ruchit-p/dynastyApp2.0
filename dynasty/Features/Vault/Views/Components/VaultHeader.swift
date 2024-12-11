import Foundation
struct VaultHeader: View {
    @Binding var searchText: String
    @Binding var selectedType: VaultItemType?

    var body: some View {
        VStack {
            SearchBar(searchText: $searchText)
            FilterBar(selectedType: $selectedType)
        }
        .padding(.top, 10)
    }
}