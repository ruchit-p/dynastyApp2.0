// Features/Vault/Views/Components/VaultToolbar.swift

import SwiftUI

struct VaultToolbar: View {
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
        HStack {
            if isSelecting {
                SelectionModeButton(
                    isSelecting: $isSelecting,
                    selectedItems: $selectedItems,
                    filteredItems: filteredItems,
                    navigationPath: navigationPath
                )
            } else {
                NavigationMenu(
                    isSelecting: $isSelecting,
                    showNewFolderPrompt: $showNewFolderPrompt
                )
                Spacer()
                SortMenu(filteredItems: filteredItems)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .confirmationDialog("Create New Folder", isPresented: $showNewFolderPrompt) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                createNewFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new folder.")
        }
    }
}

struct VaultToolbarButtons: View {
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>

    var body: some View {
        Group {
            Button(action: { showPhotoPickerSheet = true }) {
                Label("Import Photos", systemImage: "photo.stack")
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

struct SelectionModeButton: View {
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    var filteredItems: [VaultItem]
    var navigationPath: NavigationPath

    var body: some View {
        Button(action: {
            isSelecting = false
            selectedItems.removeAll()
        }) {
            Text("Cancel")
        }
    }
}

struct NavigationMenu: View {
    @Binding var isSelecting: Bool
    @Binding var showNewFolderPrompt: Bool

    var body: some View {
        Menu {
            Button(action: {
                isSelecting = true
            }) {
                Label("Select Items", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                showNewFolderPrompt = true
            }) {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

struct SortMenu: View {
    var filteredItems: [VaultItem]

    var body: some View {
        Menu {
            Text("Sorting options")
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
}

