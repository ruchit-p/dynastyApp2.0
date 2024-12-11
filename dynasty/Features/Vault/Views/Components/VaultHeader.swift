import Foundation
import SwiftUI

struct VaultHeader: View {
    @Binding var searchText: String
    @Binding var selectedType: VaultItemType?
    var currentFolderId: String?

    var body: some View {
        VStack {
            SearchBar(searchText: $searchText)
            FilterBar(selectedType: $selectedType, searchText: $searchText, currentFolderId: currentFolderId)
        }
        .padding(.top, 10)
    }
}
