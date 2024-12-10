import SwiftUI

struct VaultToolbar: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool

    var body: some View {
        Menu {
            Button {
                showPhotoPickerSheet = true
            } label: {
                Label("Upload from Photos", systemImage: "photo.on.rectangle")
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Upload from Files", systemImage: "folder")
            }

            Button {
                showCameraScannerSheet = true
            } label: {
                Label("Scan Documents", systemImage: "camera")
            }

            Button {
                showNewFolderPrompt = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            
            Button {
                showCameraPicker = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus")
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
} 