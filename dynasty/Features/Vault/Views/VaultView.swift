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
    
    // Add states for file handling
    @State private var scannedImages: [UIImage] = []
    @State private var scannedDocumentName = ""
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")
    
    @StateObject private var cameraService = CameraService()
    
    enum SortOption: String, CaseIterable, Identifiable {
        case name, kind, date, size
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VaultContentView(
                selectedPhotos: $selectedPhotos,
                currentFolderId: nil
            )
            .environmentObject(cameraService)
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: scenePhase) {
            handleScenePhaseChange(to: scenePhase)
        }
        .onChange(of: selectedPhotos) {
            Task {
                await handleSelectedPhotos(selectedPhotos)
            }
        }
        .onChange(of: authManager.user) {
            handleUserChange(authManager.user)
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
    }
    
    private func validateAndInitialize() {
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
    
    private func handleUserChange(_ user: User?) {
        guard let user = user, let userId = user.id else {
            vaultManager.lock()
            return
        }
        
        vaultManager.setCurrentUser(user)
        authenticate(userId: userId)
    }
    
    private func authenticate(userId: String) {
        guard !vaultManager.isAuthenticating else { return }
        
        logger.info("Starting vault authentication for user: \(userId)")
        
        Task {
            do {
                try await vaultManager.unlock()
            } catch VaultError.authenticationCancelled {
                logger.info("Authentication cancelled by user")
            } catch {
                logger.error("Authentication failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .inactive, .background:
            vaultManager.lock()
            logger.info("App moved to background. Vault locked.")
        case .active:
            break
        @unknown default:
            break
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard let _ = authManager.user?.id else {
            logger.error("Cannot import photos: No authenticated user")
            await MainActor.run {
                self.error = VaultError.authenticationFailed("Please sign in to import photos")
                self.showError = true
            }
            return
        }
        
        do {
            logger.info("Processing selected photos for user: \(authManager.user?.id ?? "")")
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let filename = "\(UUID().uuidString).jpg"
                    let encryptionKeyId = try await vaultManager.generateEncryptionKey(for: authManager.user?.id ?? "")
                    
                    let metadata = VaultItemMetadata(
                        originalFileName: filename,
                        fileSize: Int64(data.count),
                        mimeType: "image/jpeg",
                        encryptionKeyId: encryptionKeyId,
                        hash: vaultManager.generateFileHash(for: data)
                    )
                    
                    try await vaultManager.importData(
                        data,
                        filename: filename,
                        fileType: .image,
                        metadata: metadata,
                        userId: authManager.user?.id ?? "",
                        parentFolderId: nil
                    )
                }
            }
            logger.info("Successfully imported photos")
        } catch {
            logger.error("Failed to import photos: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func saveScannedDocumentAsPDF() {
        // Ensure you have a current user and scanned images
        guard let userId = vaultManager.currentUser?.id else { return }
        guard !scannedImages.isEmpty else { return }
        
        let pdfData = createPDFData(from: scannedImages)
        
        Task {
            do {
                let keyId = try await vaultManager.generateEncryptionKey(for: userId)
                
                let finalName = scannedDocumentName.isEmpty ? "Untitled.pdf" : "\(scannedDocumentName).pdf"
                let metadata = VaultItemMetadata(
                    originalFileName: finalName,
                    fileSize: Int64(pdfData.count),
                    mimeType: "application/pdf",
                    encryptionKeyId: keyId,
                    hash: vaultManager.generateFileHash(for: pdfData)
                )
                
                try await vaultManager.importData(
                    pdfData,
                    filename: UUID().uuidString + ".pdf",
                    fileType: .document,
                    metadata: metadata,
                    userId: userId,
                    parentFolderId: currentFolderId
                )
                
                // Reset state after successful import
                await MainActor.run {
                    scannedImages.removeAll()
                    scannedDocumentName = ""
                }
            } catch {
                logger.error("Failed to save scanned document as PDF: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    private func createPDFData(from images: [UIImage]) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "DynastyApp",
            kCGPDFContextAuthor: "DynastyApp"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 595.2 // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        return renderer.pdfData { (context) in
            for image in images {
                context.beginPage()
                let maxRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                let aspectRect = AVMakeRect(aspectRatio: image.size, insideRect: maxRect)
                image.draw(in: aspectRect)
            }
        }
    }
}

struct VaultSignInRequiredView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Vault is Locked")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please sign in to access your vault.")
                .font(.headline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: SignInView()) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
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
    
    // Enum for sorting options
    enum SortOption: String, CaseIterable, Identifiable {
        case name, kind, date, size
        var id: String { self.rawValue }
    }
    
    @State private var currentSortOption: SortOption = .date
    @State private var isSortAscending = false
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                do {
                    guard let userId = vaultManager.currentUser?.id else { return }
                    try await vaultManager.importItems(from: urls, userId: userId, parentFolderId: currentFolderId)
                } catch {
                    logger.error("Failed to import files: \(error)")
                    await MainActor.run {
                        self.error = error
                        self.showError = true
                    }
                }
            }
        case .failure(let error):
            logger.error("File import failed: \(error)")
            Task { @MainActor in
                self.error = error
                self.showError = true
            }
        }
        return nil
    }
        private var currentFolderName: String? {
        if let currentFolderId = currentFolderId,
           let currentFolder = vaultManager.items.first(where: { $0.id == currentFolderId && $0.fileType == .folder }) {
            return currentFolder.title
        }
        return nil
    }
    
    private var filteredItems: [VaultItem] {
        // Filter out deleted items
        let notDeletedItems = vaultManager.items.filter { !$0.isDeleted }
        
        // Filter by current folder
        let itemsInCurrentFolder = notDeletedItems.filter { item in
            if let folderId = currentFolderId {
                return item.parentFolderId == folderId
            } else {
                return item.parentFolderId == nil // Root level items
            }
        }
        
        // Filter by search text
        let itemsMatchingSearch = itemsInCurrentFolder.filter { item in
            searchText.isEmpty ||
            item.title.localizedCaseInsensitiveContains(searchText) ||
            (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        // Filter by selected type
        let itemsMatchingType = itemsMatchingSearch.filter { item in
            selectedType == nil || item.fileType == selectedType
        }
        
        let sorted: [VaultItem]
        switch currentSortOption {
        case .name:
            sorted = itemsMatchingType.sorted {
                isSortAscending ? $0.title < $1.title : $0.title > $1.title
            }
        case .kind:
            sorted = itemsMatchingType.sorted { a, b in
                if a.fileType != b.fileType {
                    return isSortAscending ? a.fileType.rawValue < b.fileType.rawValue : a.fileType.rawValue > b.fileType.rawValue
                } else {
                    return isSortAscending ? a.title < b.title : a.title > b.title
                }
            }
        case .date:
            sorted = itemsMatchingType.sorted {
                isSortAscending ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt
            }
        case .size:
            sorted = itemsMatchingType.sorted {
                isSortAscending ? $0.metadata.fileSize < $1.metadata.fileSize : $0.metadata.fileSize > $1.metadata.fileSize
            }
        }
        
        return sorted
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack {
                    SearchBar(searchText: $searchText)
                    
                    FilterBar(selectedType: $selectedType)
                    
                    VaultItemGrid(
                        selectedPhotos: $selectedPhotos,
                        isSelecting: $isSelecting,
                        selectedItems: $selectedItems,
                        filteredItems: filteredItems,
                        columns: columns
                    )
                }
                .padding(.top, 10)
            }
            .refreshable {
                Task {
                    await refreshItems()
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true,
                onCompletion: handleFileImport
            )
            .photosPicker(
                isPresented: $showPhotoPickerSheet,
                selection: $selectedPhotos,
                matching: .images,
                photoLibrary: .shared()
            )
            .fullScreenCover(isPresented: $showCameraScannerSheet) {
                DocumentScannerView { images in
                    self.scannedImages = images
                    self.showScannedDocumentNamePrompt = true
                }
                .alert("Document Name", isPresented: $showScannedDocumentNamePrompt) {
                    TextField("Document Name", text: $scannedDocumentName)
                    Button("Save") {
                        saveScannedDocumentAsPDF()
                    }
                    Button("Cancel", role: .cancel) {
                        scannedImages.removeAll()
                    }
                } message: {
                    Text("Enter a name for your document")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VaultToolbar(
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
                                Menu("Sort") {
                                    ForEach(SortOption.allCases) { option in
                                        Button {
                                            if currentSortOption == option {
                                                isSortAscending.toggle()
                                            } else {
                                                currentSortOption = option
                                                isSortAscending = true
                                            }
                                        } label: {
                                            HStack {
                                                Text(option.rawValue.capitalized)
                                                if currentSortOption == option {
                                                    Image(systemName: isSortAscending ? "arrow.up" : "arrow.down")
                                                }
                                            }
                                        }
                                    }
                                }
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentFolderId != nil {
                        Button {
                            navigationPath.removeLast()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                        }
                    }
                }
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
                if item.fileType == .folder {
                    VaultContentView(selectedPhotos: $selectedPhotos, currentFolderId: item.id)
                } else {
                    VaultItemDetailView(document: item)
                }
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
    
    private func downloadSelectedItems() async {
        do {
            var tempFiles: [URL] = []
            for item in selectedItems {
                let data = try await vaultManager.downloadFile(item)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(item.title)
                try data.write(to: tempURL, options: .atomic)
                tempFiles.append(tempURL)
            }
            
            await MainActor.run {
                self.shareSheetItems = tempFiles
                self.showShareSheet = true
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func saveScannedDocumentAsPDF() {
        // Ensure you have a current user and scanned images
        guard let userId = vaultManager.currentUser?.id else { return }
        guard !scannedImages.isEmpty else { return }
        
        let pdfData = createPDFData(from: scannedImages)
        
        Task {
            do {
                let keyId = try await vaultManager.generateEncryptionKey(for: userId)
                
                let finalName = scannedDocumentName.isEmpty ? "Untitled.pdf" : "\(scannedDocumentName).pdf"
                let metadata = VaultItemMetadata(
                    originalFileName: finalName,
                    fileSize: Int64(pdfData.count),
                    mimeType: "application/pdf",
                    encryptionKeyId: keyId,
                    hash: vaultManager.generateFileHash(for: pdfData)
                )
                
                try await vaultManager.importData(
                    pdfData,
                    filename: UUID().uuidString + ".pdf",
                    fileType: .document,
                    metadata: metadata,
                    userId: userId,
                    parentFolderId: currentFolderId
                )
                
                // Reset state after successful import
                await MainActor.run {
                    scannedImages.removeAll()
                    scannedDocumentName = ""
                }
            } catch {
                logger.error("Failed to save scanned document as PDF: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    private func createPDFData(from images: [UIImage]) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "DynastyApp",
            kCGPDFContextAuthor: "DynastyApp"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 595.2 // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        return renderer.pdfData { (context) in
            for image in images {
                context.beginPage()
                let maxRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                let aspectRect = AVMakeRect(aspectRatio: image.size, insideRect: maxRect)
                image.draw(in: aspectRect)
            }
        }
    }
    
    private func shareSelectedItems() async {
        do {
            var tempFiles: [URL] = []
            for item in selectedItems {
                let data = try await vaultManager.downloadFile(item)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(item.title)
                try data.write(to: tempURL, options: .atomic)
                tempFiles.append(tempURL)
            }
            
            await MainActor.run {
                self.shareSheetItems = tempFiles
                self.showShareSheet = true
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func deleteSelectedItems() async {
        do {
            for item in selectedItems {
                try await vaultManager.moveToTrash(item)
            }
            selectedItems.removeAll()
            isSelecting = false
        } catch {
            self.error = error
            self.showError = true
        }
    }
    
    private func createNewFolder() async {
        guard !newFolderName.isEmpty else {
            self.error = VaultError.invalidData("Folder name cannot be empty")
            self.showError = true
            return
        }
        
        guard let userId = vaultManager.currentUser?.id else {
            self.error = VaultError.authenticationFailed("User not authenticated")
            self.showError = true
            return
        }
        
        do {
            let keyId = try await vaultManager.generateEncryptionKey(for: userId)
            
            let metadata = VaultItemMetadata(
                originalFileName: newFolderName,
                fileSize: 0,
                mimeType: "application/vnd.folder",
                encryptionKeyId: keyId,
                hash: ""
            )
            
            let folderItem = VaultItem(
                id: UUID().uuidString,
                userId: userId,
                title: newFolderName,
                description: nil,
                fileType: .folder,
                encryptedFileName: "",
                storagePath: "",
                thumbnailURL: nil,
                metadata: metadata,
                createdAt: Date(),
                updatedAt: Date(),
                isDeleted: false,
                parentFolderId: currentFolderId
            )
            
            try await vaultManager.createFolder(folderItem)
            
            await MainActor.run {
                newFolderName = ""
                showNewFolderPrompt = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func refreshItems() async {
        do {
            guard let userId = vaultManager.currentUser?.id else {
                logger.error("Cannot refresh: No authenticated user")
                self.error = VaultError.authenticationFailed("Please sign in to access your vault")
                self.showError = true
                return
            }
            try await vaultManager.loadItems(for: userId)
        } catch {
            self.error = error
            self.showError = true
            logger.error("Failed to refresh vault items: \(error.localizedDescription)")
        }
    }
}

#Preview {
    VaultView()
} 
