import Foundation

struct VaultFooter: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool

    var body: some View {
        VaultToolbar(
            showPhotoPickerSheet: $showPhotoPickerSheet,
            showFilePicker: $showFilePicker,
            showCameraScannerSheet: $showCameraScannerSheet,
            showNewFolderPrompt: $showNewFolderPrompt,
            showCameraPicker: $showCameraPicker
        )
    }
}