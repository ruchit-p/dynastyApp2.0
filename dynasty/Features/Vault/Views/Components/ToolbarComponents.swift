// Features/Vault/Views/Components/VaultToolbar.swift

import SwiftUI

struct VaultToolbar: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool
    
    var body: some View {
        Menu {
            VaultToolbarButtons(
                showPhotoPickerSheet: $showPhotoPickerSheet,
                showFilePicker: $showFilePicker,
                showCameraScannerSheet: $showCameraScannerSheet,
                showNewFolderPrompt: $showNewFolderPrompt,
                showCameraPicker: $showCameraPicker
            )
        } label: {
            AddButton(systemName: "plus", color: .black)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

// Trailing toolbar content
    @ToolbarContentBuilder
    private func TrailingToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Text("\(filteredItems.count) Items")
                    .font(.footnote)
                    .foregroundColor(.gray)
                if !isSelecting {
                    Menu {
                        Button("Select") {
                            isSelecting = true
                        }
                        Button("New Folder") {
                            showNewFolderPrompt = true
                        }
                        Button("View Trash") {
                            navigationPath.append("TrashView")
                        }
                        SortMenu()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                    }
                    .alert("New Folder", isPresented: $showNewFolderPrompt) {
                        TextField("Folder Name", text: $newFolderName)
                        Button("Create") {
                            Task {
                                await createNewFolder()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Enter a name for the new folder")
                    }
                } else {
                    Button("Cancel Selection") {
                        isSelecting = false
                        selectedItems.removeAll()
                    }
                }
            }
        }
    }

private struct VaultToolbarButtons: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool
    
    var body: some View {
        Group {
            Button(action: { showPhotoPickerSheet = true }) {
                Label("Upload from Photos", systemImage: "photo.rectangle.stack")
            }
            Button(action: { showFilePicker = true }) {
                Label("Upload from Files", systemImage: "folder")
            }
            Button(action: { showCameraScannerSheet = true }) {
                Label("Scan Documents", systemImage: "doc.viewfinder")
            }
            Button(action: { showNewFolderPrompt = true }) {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            Button(action: { showCameraPicker = true }) {
                Label("Take Photo", systemImage: "camera")
            }
        }
    }
}

