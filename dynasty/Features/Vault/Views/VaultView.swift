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
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: UIDevice.current.userInterfaceIdiom == .pad ? 4 : 3)

    var body: some View {
        if vaultManager.isLocked {
            VaultLockedView(error: $error, showError: $showError)
        } else {
            NavigationStack {
                VStack(spacing: 0) {
                    VaultHeader(searchText: $searchText, selectedType: $selectedType, currentFolderId: currentFolderId)
                    
                    VaultItemGrid(
                        selectedPhotos: $selectedPhotos,
                        isSelecting: $isSelecting,
                        selectedItems: $selectedItems,
                        error: $error,
                        showError: $showError,
                        refreshItems: {
                            do {
                                try await VaultFileManagementFunctions.refreshItems(
                                    vaultManager: vaultManager,
                                    sortOption: sortOption,
                                    isAscending: isAscending
                                )
                            } catch {
                                self.error = error
                                showError = true
                            }
                        },
                        filteredItems: filteredItems,
                        columns: columns
                    )
                }
                .overlay(alignment: .bottom) {
                    VaultToolbar(
                        showPhotoPickerSheet: $showPhotoPickerSheet,
                        showFilePicker: $showFilePicker,
                        showCameraScannerSheet: $showCameraScannerSheet,
                        showNewFolderPrompt: $showNewFolderPrompt,
                        showCameraPicker: $showCameraPicker,
                        isSelecting: $isSelecting,
                        selectedItems: $selectedItems,
                        newFolderName: $newFolderName,
                        createNewFolder: {
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
                        },
                        filteredItems: filteredItems,
                        navigationPath: navigationPath
                    )
                }
                .navigationTitle(currentFolderName ?? "Vault")
                .navigationBarTitleDisplayMode(currentFolderId == nil ? .large : .inline)
            }
            .photosPicker(isPresented: $showPhotoPickerSheet, selection: $selectedPhotos)
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
                Task {
                    switch result {
                    case .success(let url):
                        await VaultFileManagementFunctions.handleFileImport(.success([url]), vaultManager: vaultManager, currentFolderId: currentFolderId)
                        case .failure(let error):
                        await VaultFileManagementFunctions.handleFileImport(.failure(error), vaultManager: vaultManager, currentFolderId: currentFolderId)
                    }
                }
            }
            .onChange(of: selectedPhotos) {
                Task {
                    await VaultPhotoHandlingFunctions.handleSelectedPhotos(selectedPhotos, vaultManager: vaultManager, authManager: authManager)
                }
            }
            .errorOverlay(error: error, isPresented: $showError)
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
        var items = vaultManager.items.filter { !$0.isDeleted }
        items = filterItemsByFolder(items)
        items = filterItemsBySearchText(items)
        items = filterItemsByType(items)
        return items
    }
    
    private func filterItemsByFolder(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            if let folderId = currentFolderId {
                return item.parentFolderId == folderId
            } else {
                return item.parentFolderId == nil
            }
        }
    }

    private func filterItemsBySearchText(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            searchText.isEmpty ||
            item.title.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func filterItemsByType(_ items: [VaultItem]) -> [VaultItem] {
        items.filter { item in
            selectedType == nil || item.fileType == selectedType
        }
    }
}

#Preview {
    VaultView()
} 
