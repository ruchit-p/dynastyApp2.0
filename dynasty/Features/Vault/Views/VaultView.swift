import SwiftUI
import os.log
import PhotosUI
import AVFoundation
import VisionKit


extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                     to: nil, from: nil, for: nil)
    }
}

struct VaultView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var error: Error?
    @State private var showError = false
    @Environment(\.scenePhase) private var scenePhase
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")
    
    var body: some View {
        Group {
            if let user = authManager.user, let userId = user.id {
                if vaultManager.isLocked {
                    VStack {
                        Text("Vault is Locked")
                            .font(.title2)
                            .padding()
                        
                        Text("Press the button below to authenticate with Face ID or passcode.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                do {
                                    try await vaultManager.unlock()
                                } catch {
                                    self.error = error
                                    self.showError = true
                                }
                            }
                        }) {
                            Label("Authenticate to Unlock", systemImage: getBiometricButtonIcon())
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        .disabled(vaultManager.isAuthenticating)
                    }
                } else {
                    VaultContentView(selectedPhotos: $selectedPhotos)
                }
            } else {
                VaultSignInRequiredView()
            }
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(to: newPhase)
        }
        .onChange(of: selectedPhotos) { newItems in
            Task {
                await handleSelectedPhotos(newItems)
            }
        }
        .onChange(of: authManager.user) { newUser in
            handleUserChange(newUser)
        }
        .onAppear {
            validateAndInitialize()
        }
    }
    
    private func validateAndInitialize() {
        Task {
            do {
                // Validate user session
                try await authManager.validateSession()
                
                if let user = authManager.user, let userId = user.id {
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
            // When app becomes active, vault stays locked until user explicitly authenticates
            break
        @unknown default:
            break
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard let userId = authManager.user?.id else {
            logger.error("Cannot import photos: No authenticated user")
            await MainActor.run {
                self.error = VaultError.authenticationFailed("Please sign in to import photos")
                self.showError = true
            }
            return
        }
        
        do {
            logger.info("Processing selected photos for user: \(userId)")
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let filename = "\(UUID().uuidString).jpg"
                    let encryptionKeyId = try await vaultManager.generateEncryptionKey(for: userId)
                    
                    let metadata = VaultItemMetadata(
                        originalFileName: filename,
                        fileSize: Int64(data.count),
                        mimeType: "image/jpeg",
                        encryptionKeyId: encryptionKeyId,
                        iv: Data(),
                        hash: vaultManager.generateFileHash(for: data)
                    )
                    
                    try await vaultManager.importData(
                        data,
                        filename: filename,
                        fileType: .image,
                        metadata: metadata,
                        userId: userId
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
    
    private func getBiometricButtonIcon() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "key.fill"
        }
    }
}

struct VaultSignInRequiredView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please sign in to access your secure vault")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct VaultContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Binding var selectedPhotos: [PhotosPickerItem]
    @State private var searchText = ""
    @State private var selectedType: VaultItemType?
    @State private var showFilePicker = false
    @State private var showPhotoPickerSheet = false
    @State private var showCameraScannerSheet = false
    @State private var showTrashView = false
    @State private var error: Error?
    @State private var showError = false
    @State private var isSelecting = false
    @State private var selectedItems = Set<VaultItem>()
    
    private let logger = Logger(subsystem: "com.dynasty.VaultContentView", category: "UI")
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    private var filteredItems: [VaultItem] {
        vaultManager.items.filter { item in
            guard !item.isDeleted else { return false }
            
            let matchesSearch = searchText.isEmpty || 
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesType = selectedType == nil || item.fileType == selectedType
            
            return matchesSearch && matchesType
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Top Header
                HStack {
                    Text("Vault")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(filteredItems.count) Items")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if !isSelecting {
                        Menu {
                            Button("Select") {
                                isSelecting = true
                            }
                            Button("New Folder") {
                                // TODO: Implement folder creation
                            }
                            Button("Scan Documents") {
                                showCameraScannerSheet = true
                            }
                            Button("View Trash") {
                                showTrashView = true
                            }
                            
                     
                            
                            Menu("Filter/Sort") {
                                Button("Name") {
                                    // Implement sort by name
                                }
                                Button("Kind") {
                                    // Implement sort by kind
                                }
                                Button("Date") {
                                    // Implement sort by date
                                }
                                Button("Size") {
                                    // Implement sort by size
                                }
                                Button("Tags") {
                                    // Implement sort by tags
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .padding(.leading, 8)
                        }
                        .padding(.trailing)
                    } else {
                        Menu {
                            Button("Download") {
                                downloadSelectedItems()
                            }
                            Button("Share") {
                                shareSelectedItems()
                            }
                            Button("Delete") {
                                deleteSelectedItems()
                            }
                            Button("Cancel Selection") {
                                isSelecting = false
                                selectedItems.removeAll()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .padding(.leading, 8)
                        }
                        .padding(.trailing)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Search and Filter Bar
                SearchFilterBar(searchText: $searchText, selectedType: $selectedType)
                
                // Vertical Grid Layout
                if filteredItems.isEmpty {
                    VStack {
                        Spacer()
                        Text("No items yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Add your first item by clicking the plus button!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredItems) { item in
                                NavigationLink(destination: VaultItemDetailView(document: item)) {
                                    VStack(spacing: 8) {
                                        VaultItemThumbnailView(item: item)
                                            .frame(height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                isSelecting ? SelectionOverlay(isSelected: selectedItems.contains(item)) {
                                                    toggleSelection(for: item)
                                                } : nil
                                            )
                                        
                                        Text(item.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onTapGesture {
                                    if isSelecting {
                                        toggleSelection(for: item)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshItems()
                    }
                }
            }
            
            // Add Button Menu
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
        .navigationBarHidden(true)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf, .plainText, .image, .video],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showPhotoPickerSheet) {
            PhotosPicker(
                selection: $selectedPhotos,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Select Photos")
            }
        }
        .sheet(isPresented: $showCameraScannerSheet) {
            DocumentScannerView { scannedImages in
                handleScannedDocuments(scannedImages)
            }
        }
        .sheet(isPresented: $showTrashView) {
            TrashView()
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                do {
                    guard let userId = vaultManager.currentUser?.id else { return }
                    try await vaultManager.importItems(from: urls, userId: userId)
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
    }
    
    private func toggleSelection(for item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func downloadSelectedItems() {
        // Implement download logic for selected items
    }
    
    private func shareSelectedItems() {
        // Implement share logic for selected items
    }
    
    private func deleteSelectedItems() {
        Task {
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
    }
    
    private func createNewFolder() {
        // Implement folder creation logic
    }
    
    private func handleScannedDocuments(_ images: [UIImage]) {
        // Implement logic to process and upload scanned documents
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

// Keep only one SelectionOverlay implementation
struct SelectionOverlay: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .position(x: 20, y: 20)
        }
        .onTapGesture(perform: action)
    }
}

// Document Scanner View
struct DocumentScannerView: UIViewControllerRepresentable {
    var completion: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator
        return scannerVC
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        
        init(parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images = [UIImage]()
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            parent.completion(images)
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

enum VaultViewStyle {
    case icons
    case list
}

// Helper Views
struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedType: VaultItemType?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search files", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChip(title: "All", isSelected: selectedType == nil) {
                        selectedType = nil
                        isSearchFocused = false
                    }
                    FilterChip(title: "Documents", isSelected: selectedType == .document) {
                        selectedType = .document
                        isSearchFocused = false
                    }
                    FilterChip(title: "Photos", isSelected: selectedType == .image) {
                        selectedType = .image
                        isSearchFocused = false
                    }
                    FilterChip(title: "Videos", isSelected: selectedType == .video) {
                        selectedType = .video
                        isSearchFocused = false
                    }
                    FilterChip(title: "Audio", isSelected: selectedType == .audio) {
                        selectedType = .audio
                        isSearchFocused = false
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct VaultToolbar: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var showFilePicker: Bool
    
    var body: some View {
        HStack {
            PhotosPicker(selection: $selectedPhotos,
                        matching: .images,
                        photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
            }
            
            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "doc")
            }
            
            Spacer()
            
            NavigationLink(destination: TrashView()) {
                Image(systemName: "trash")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LockScreenView: View {
    let isAuthenticating: Bool
    let onAuthenticate: () -> Void
    let biometricLabel: String
    let biometricIcon: String
    
    var body: some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("Vault is Locked")
                .font(.title)
                .padding()
            
            Text("Authenticate to access your secure vault")
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            if isAuthenticating {
                ProgressView()
                    .padding()
            } else {
                Button(action: onAuthenticate) {
                    Label(biometricLabel, systemImage: biometricIcon)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
    }
}
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct VaultItemView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let item: VaultItem
    
    @State private var thumbnail: UIImage? = nil
    @State private var isLoading = false
    @State private var progress: Double = 0.0
    
    private let logger = Logger(subsystem: "com.dynasty.VaultItemView", category: "UI")
    
    var body: some View {
        NavigationLink(destination: VaultItemDetailView(document: item)) {
            VStack {
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .overlay {
                                if isLoading {
                                    VStack {
                                        ProgressView(value: progress)
                                            .progressViewStyle(LinearProgressViewStyle())
                                            .padding(.horizontal)
                                        if progress > 0 {
                                            Text("\(Int(progress * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                } else {
                                    Image(systemName: iconName)
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                            }
                    }
                }
                
                Text(item.title)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private var iconName: String {
        switch item.fileType {
        case .document:
            return "doc.text"
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil, !isLoading else { return }
        
        isLoading = true
        Task {
            do {
                let data = try await vaultManager.downloadFile(item)
                switch item.fileType {
                case .image:
                    if let image = UIImage(data: data) {
                        let resizedImage = image.resize(to: CGSize(width: 150, height: 150))
                        await MainActor.run {
                            self.thumbnail = resizedImage
                            self.isLoading = false
                        }
                    }
                case .video:
                    if let image = await generateVideoThumbnail(from: data) {
                        await MainActor.run {
                            self.thumbnail = image
                            self.isLoading = false
                        }
                    }
                case .document:
                    await MainActor.run {
                        self.thumbnail = UIImage(systemName: "doc.text")?.resize(to: CGSize(width: 150, height: 150))
                        self.isLoading = false
                    }
                case .audio:
                    await MainActor.run {
                        self.thumbnail = UIImage(systemName: "waveform")?.resize(to: CGSize(width: 150, height: 150))
                        self.isLoading = false
                    }
                }
            } catch {
                logger.error("Failed to load thumbnail for item \(item.id): \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from data: Data) async -> UIImage? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        do {
            try data.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 150, height: 150)
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            try? FileManager.default.removeItem(at: tempURL)
            
            return UIImage(cgImage: cgImage).resize(to: CGSize(width: 150, height: 150))
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            logger.error("Failed to generate video thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}

extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    VaultView()
} 
