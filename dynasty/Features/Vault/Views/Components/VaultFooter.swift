import Foundation
import SwiftUI

struct VaultFooter: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @Binding var showPhotoPickerSheet: Bool
    @Binding var showFilePicker: Bool
    @Binding var showCameraScannerSheet: Bool
    @Binding var showNewFolderPrompt: Bool
    @Binding var showCameraPicker: Bool
    @Binding var isSelecting: Bool
    @Binding var selectedItems: Set<VaultItem>
    @State private var newFolderName = ""
    var currentFolderId: String?
    
    var body: some View {
        HStack {
            if isSelecting {
                SelectionModeButton(
                    isSelecting: $isSelecting,
                    selectedItems: $selectedItems,
                    filteredItems: filteredItems,
                    navigationPath: NavigationPath()
                )
            } else {
                Menu {
                    Button(action: { showCameraPicker = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    
                    Button(action: { showCameraScannerSheet = true }) {
                        Label("Scan Document", systemImage: "doc.viewfinder")
                    }
                    
                    Button(action: { showFilePicker = true }) {
                        Label("Upload File", systemImage: "folder")
                    }
                    
                    Button(action: { showPhotoPickerSheet = true }) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: { showNewFolderPrompt = true }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.blue)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
        }
        .confirmationDialog(
            "Create New Folder",
            isPresented: $showNewFolderPrompt,
            titleVisibility: .visible
        ) {
            TextField("Folder Name", text: $newFolderName)
            Button("Create") {
                Task {
                    do {
                        try await VaultFileManagementFunctions.createNewFolder(
                            name: newFolderName,
                            currentFolderId: currentFolderId,
                            vaultManager: vaultManager
                        )
                        newFolderName = ""
                    } catch {
                        // Handle error if needed
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder")
        }
    }
    
    private var filteredItems: [VaultItem] {
        vaultManager.items.filter { item in
            !item.isDeleted
        }
    }
}
