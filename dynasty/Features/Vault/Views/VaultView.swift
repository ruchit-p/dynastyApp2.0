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
    @Environment(\.scenePhase) private var scenePhase
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")

    var body: some View {
        if vaultManager.isLocked {
            VaultLockedView(error: $error, showError: $showError)
        } else {
            NavigationStack {
                VaultContentView(
                    selectedPhotos: $selectedPhotos,
                    currentFolderId: nil
                )
            }
            .alert("Error", isPresented: $showError, presenting: error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onChange(of: scenePhase) {
                VaultSceneHandlingFunctions.handleScenePhaseChange(to: scenePhase, vaultManager: vaultManager)
            }
            .onChange(of: selectedPhotos) {
                Task {
                    await VaultPhotoHandlingFunctions.handleSelectedPhotos(selectedPhotos, vaultManager: vaultManager, authManager: authManager)
                }
            }
            .onChange(of: authManager.user) {
                VaultAuthenticationFunctions.handleUserChange(authManager.user, vaultManager: vaultManager)
            }
            .onAppear {
                Task {
                    do {
                        try await authManager.validateSession()
                        
                        if let user = authManager.user {
                            vaultManager.setCurrentUser(user)
                        }
                    } catch {
                        self.error = error
                        self.showError = true
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VaultAuthenticationError"))) { notification in
                if let error = notification.object as? Error {
                    self.error = error
                    self.showError = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VaultPhotoError"))) { notification in
                if let error = notification.object as? Error {
                    self.error = error
                    self.showError = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VaultFileError"))) { notification in
                if let error = notification.object as? Error {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
}

struct VaultContentView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var cameraService: CameraService
    @Binding var selectedPhotos: [PhotosPickerItem]
    var currentFolderId: String?
    
    @State private var searchText = ""
    @State private var isSelecting = false
    @State private var selectedItems = Set<VaultItem>()
    @State private var showShareSheet = false
    @State private var shareSheetItems: [URL] = []
    @State private var showDeleteConfirmation = false
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""
    @State private var error: Error?
    @State private var showError = false
    @State private var showPhotoPickerSheet = false
    @State private var showFilePicker = false
    @State private var showCameraScannerSheet = false
    @State private var showCameraPicker = false
    @State private var showScannedDocumentNamePrompt = false
    @State private var scannedDocumentName = ""
    @State private var scannedImages: [UIImage] = []
    @State private var selectedType: VaultItemType? = nil
    @State private var navigationPath = NavigationPath()
    @State private var currentSortOption: SortOption = .date
    @State private var isSortAscending = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3)
    private let logger = Logger(subsystem: "com.dynasty.VaultContentView", category: "UI")
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        Task {
            await VaultFileManagementFunctions.handleFileImport(result, vaultManager: vaultManager, currentFolderId: currentFolderId)
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
        let notDeletedItems = vaultManager.items.filter { !$0.isDeleted }
        let itemsInCurrentFolder = filterItemsByFolder(notDeletedItems)
        let itemsMatchingSearch = filterItemsBySearchText(itemsInCurrentFolder)
        let itemsMatchingType = filterItemsByType(itemsMatchingSearch)
        return itemsMatchingType
    }

    
    // View to handle navigation destination
    struct ItemDestinationView: View {
        @Binding var selectedPhotos: [PhotosPickerItem]
        let item: VaultItem

        var body: some View {
            Group {
                if item.fileType == .folder {
                    VaultContentView(selectedPhotos: $selectedPhotos, currentFolderId: item.id)
                } else {
                    VaultItemDetailView(document: item)
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                VaultHeader(searchText: $searchText, selectedType: $selectedType)
                VaultGrid(
                    selectedPhotos: $selectedPhotos,
                    selectedItems: $selectedItems,
                    filteredItems: filteredItems,
                    columns: columns
                )
            }
            .overlay(alignment: .bottomTrailing) {
                VaultFooter(
                    showPhotoPickerSheet: $showPhotoPickerSheet,
                    showFilePicker: $showFilePicker,
                    showCameraScannerSheet: $showCameraScannerSheet,
                    showNewFolderPrompt: $showNewFolderPrompt,
                    showCameraPicker: $showCameraPicker
                )
            }
            .navigationTitle(currentFolderName ?? "Vault")
            .navigationBarTitleDisplayMode(currentFolderId == nil ? .large : .inline)
            .toolbar {
                TrailingToolbarContent(
                    isSelecting: $isSelecting,
                    showNewFolderPrompt: $showNewFolderPrompt,
                    newFolderName: $newFolderName,
                    selectedItems: $selectedItems,
                    currentSortOption: $currentSortOption,
                    isSortAscending: $isSortAscending,
                    filteredItemsCount: filteredItems.count,
                    navigationPath: $navigationPath,
                    createNewFolder: createNewFolder
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareSheetItems) { _, _, _, _ in
                    // Cleanup temporary files
                    for url in shareSheetItems {
                        try? FileManager.default.removeItem(at: url)
                    }
                    shareSheetItems.removeAll()
                }
            }
            .confirmationDialog("Select Action", isPresented: $isSelecting) {
                if !selectedItems.isEmpty {
                    Button("Download") {
                        Task {
                            await downloadSelectedItems()
                        }
                    }
                    Button("Share") {
                        Task {
                            await shareSelectedItems()
                        }
                    }
                    Button("Move to Trash", role: .destructive) {
                        Task {
                            await deleteSelectedItems()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        isSelecting = false
                        selectedItems.removeAll()
                    }
                }
            } message: {
                Text("\(selectedItems.count) items selected")
            }
            .onChange(of: isSelecting) {
                if !isSelecting {
                    selectedItems.removeAll()
                }
            }
            .navigationDestination(for: VaultItem.self) { item in
                ItemDestinationView(selectedPhotos: $selectedPhotos, item: item)
            }
            .navigationDestination(for: String.self) { value in
                if value == "TrashView" {
                    TrashView()
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                ImagePicker(sourceType: .camera, currentFolderId: currentFolderId) { image in
                    cameraService.handleImage(
                        image: image,
                        vaultManager: vaultManager,
                        currentFolderId: currentFolderId
                    )
                }
            }
            .overlay {
                if cameraService.isProcessing {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                        .overlay {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
                }
            }
            .alert("Error", isPresented: $cameraService.showError, presenting: cameraService.error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}



#Preview {
    VaultView()
} 
