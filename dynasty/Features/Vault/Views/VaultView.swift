import SwiftUI
import os.log
import PhotosUI
import AVFoundation
import VisionKit

struct VaultView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var error: Error?
    @State private var showError = false
    @State private var searchText = ""
    @State private var selectedType: VaultItemType?
    @State private var currentFolderId: String?
    @State private var isSelecting = false
    @State private var selectedItems = Set<VaultItem>()
    @State private var showPhotoPickerSheet = false
    @State private var showFilePicker = false
    @State private var showCameraScannerSheet = false
    @State private var showNewFolderPrompt = false
    @State private var showCameraPicker = false
    @State private var newFolderName = ""
    @State private var navigationPath = NavigationPath()
    @State private var sortOption: VaultSortOption = .date
    @State private var isAscending = false
    @StateObject private var viewModel = VaultViewModel()
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3)

    var body: some View {
        if vaultManager.isLocked {
            VaultLockedView(error: $error, showError: $showError)
        } else {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Text("Vault")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer()
                        
                        if vaultManager.isInitializing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading vault...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if vaultManager.isUploading {
                            UploadProgressView()
                        }
                        
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
                                showNewFolderPrompt: $showNewFolderPrompt,
                                navigationPath: navigationPath
                            )
                            SortMenu(filteredItems: filteredItems)
                        }
                    }
                    .padding(.horizontal)
                    .confirmationDialog("Create New Folder", isPresented: $showNewFolderPrompt) {
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
                                    self.error = error
                                    showError = true
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Enter a name for the new folder.")
                    }
                    
                    VaultHeader(searchText: $searchText, selectedType: $selectedType, currentFolderId: currentFolderId)
                        .padding(.top, 4)
                    
                    VaultContentView(
                        selectedItems: $selectedItems,
                        isSelecting: $isSelecting,
                        error: $error,
                        showError: $showError,
                        selectedType: selectedType,
                        currentFolderId: currentFolderId
                    )
                }
                .navigationBarHidden(true)
                .navigationTitle(currentFolderName ?? "Vault")
                .navigationBarTitleDisplayMode(currentFolderId == nil ? .large : .inline)
                .overlay(alignment: .bottomTrailing) {
                    AddButton(
                        actions: [
                            AddButtonAction(
                                title: "Take Photo",
                                systemImage: "camera",
                                action: {
                                    showCameraPicker = true
                                }
                            ),
                            AddButtonAction(
                                title: "Scan Document",
                                systemImage: "doc.viewfinder",
                                action: {
                                    showCameraScannerSheet = true
                                }
                            ),
                            AddButtonAction(
                                title: "Upload File",
                                systemImage: "folder",
                                action: {
                                    showFilePicker = true
                                }
                            ),
                            AddButtonAction(
                                title: "Choose from Library",
                                systemImage: "photo.on.rectangle",
                                action: {
                                    showPhotoPickerSheet = true
                                }
                            )
                        ]
                    )
                }
                .sheet(isPresented: $showPhotoPickerSheet) {
                    NavigationView {
                        List {
                            PhotosPicker(selection: $selectedPhotos,
                                       matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                            }
                        }
                        .navigationTitle("Upload")
                        .navigationBarItems(trailing: Button("Cancel") {
                            showPhotoPickerSheet = false
                        })
                    }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
                Task {
                    switch result {
                    case .success(let url):
                        do {
                            try await VaultFileManagementFunctions.handleFileImport(.success([url]), vaultManager: vaultManager, currentFolderId: currentFolderId)
                        } catch {
                            self.error = VaultError.fileOperationFailed("Failed to import file: \(error.localizedDescription)")
                            showError = true
                        }
                    case .failure(let error):
                        self.error = VaultError.fileOperationFailed("Failed to import file: \(error.localizedDescription)")
                        showError = true
                    }
                }
            }
            .onChange(of: selectedPhotos) { oldValue, newValue in
                Task {
                    await VaultPhotoHandlingFunctions.handleSelectedPhotos(newValue, vaultManager: vaultManager, authManager: authManager)
                }
            }
            .onChange(of: authManager.user) { oldUser, newUser in
                if let newUser = newUser {
                    Task {
                        await viewModel.loadVaultItems(forUser: newUser)
                    }
                }
            }
            .errorOverlay(error: error, isPresented: $showError)
            .overlay {
                PreviewView(isPresented: $vaultManager.isPreviewPresented)
                    .ignoresSafeArea()
            }
            .onChange(of: vaultManager.isPreviewPresented) { oldValue, newValue in
                if !newValue {
                    vaultManager.closePreview()
                }
            }
        }
    }
    
    private var currentFolderName: String? {
        if let currentFolderId = currentFolderId,
           let currentFolder = vaultManager.items.first(where: { $0.id == currentFolderId && $0.fileType == .folder }) {
            return currentFolder.title
        }
        return nil
    }
    
    private var filteredItems: [VaultItem] {
        vaultManager.items.filter { item in
            selectedType == nil || item.fileType == selectedType
        }
    }
    
    private func handleRefresh() async {
        do {
            try await vaultManager.refreshVault()
        } catch {
            self.error = error
            showError = true
        }
    }
}

struct PreviewView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @Binding var isPresented: Bool
    
    var body: some View {
        Group {
            if let url = vaultManager.previewURL, isPresented {
                QuickLookPreview(url: url, isPresented: $isPresented)
            }
        }
    }
}

#Preview {
    VaultView()
}
