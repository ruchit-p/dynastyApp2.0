import Foundation
import SwiftUI

struct VaultFooter: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    @Binding var newFolderName: String
    var createNewFolder: () -> Void
    var filteredItems: [VaultItem]
    var navigationPath: NavigationPath

    var body: some View {
        VaultToolbar(
            showPhotoPickerSheet: $showPhotoPickerSheet,
            showFilePicker: $showFilePicker,
            showCameraScannerSheet: $showCameraScannerSheet,
            showNewFolderPrompt: $showNewFolderPrompt,
            showCameraPicker: $showCameraPicker,
            isSelecting: $isSelecting,
            selectedItems: $selectedItems,
            newFolderName: $newFolderName,
            createNewFolder: createNewFolder,
            filteredItems: filteredItems,
            navigationPath: navigationPath
        )
    }
}
