import SwiftUI
import os.log
import PhotosUI
import AVFoundation

struct VaultView: View {
    @StateObject private var vaultManager = VaultManager.shared
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var error: Error?
    @State private var showError = false
    @Environment(\.scenePhase) private var scenePhase
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "UI")
    
    var body: some View {
        Group {
            if vaultManager.isLocked {
                LockScreenView(
                    isAuthenticating: vaultManager.isAuthenticating,
                    onAuthenticate: authenticate,
                    biometricLabel: getBiometricButtonLabel(),
                    biometricIcon: getBiometricButtonIcon()
                )
            } else {
                VaultContentView(selectedPhotos: $selectedPhotos)
            }
        }
        .environmentObject(vaultManager)
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: selectedPhotos) { _, newItems in
            handleSelectedPhotos(newItems)
        }
        .onChange(of: authManager.user) { _, newUser in
            vaultManager.setCurrentUser(newUser)
        }
        .onAppear {
            vaultManager.setCurrentUser(authManager.user)
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .inactive, .background:
            if !vaultManager.isAuthenticating && !vaultManager.isDocumentPickerPresented {
                logger.info("App entering background, locking vault")
                lockVault()
            }
        case .active:
            if vaultManager.isLocked && oldPhase == .background && !vaultManager.isAuthenticating {
                logger.info("App becoming active, authenticating vault")
                authenticate()
            }
        @unknown default:
            break
        }
    }
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        logger.info("Processing \(items.count) selected photos")
        Task {
            do {
                guard let user = vaultManager.currentUser,
                      let userId = user.id else {
                    throw VaultError.authenticationFailed("User not authenticated or invalid user ID")
                }
                
                for item in items {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        try await importPhoto(data: data, userId: userId)
                    }
                }
                
                selectedPhotos.removeAll()
                
            } catch {
                logger.error("Failed to import photos: \(error.localizedDescription)")
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func importPhoto(data: Data, userId: String) async throws {
        logger.info("Loading photo data: \(ByteCountFormatter().string(fromByteCount: Int64(data.count)))")
        
        let filename = "\(UUID().uuidString).jpg"
        let fileType = VaultItemType.image
        
        let metadata = VaultItemMetadata(
            originalFileName: filename,
            fileSize: Int64(data.count),
            mimeType: "image/jpeg",
            encryptionKeyId: try vaultManager.encryptionService.generateEncryptionKey(for: userId),
            iv: Data(),
            hash: vaultManager.encryptionService.generateFileHash(for: data)
        )
        
        try await vaultManager.importData(
            data,
            filename: filename,
            fileType: fileType,
            metadata: metadata,
            userId: userId
        )
        
        logger.info("Successfully imported photo: \(filename)")
    }
    
    private func authenticate() {
        guard !vaultManager.isAuthenticating else { return }
        
        logger.info("Starting vault authentication")
        
        Task {
            do {
                try await vaultManager.unlock()
            } catch VaultError.authenticationCancelled {
                logger.info("Authentication cancelled by user")
            } catch {
                logger.error("Authentication failed: \(error.localizedDescription)")
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func lockVault() {
        logger.info("Locking vault")
        vaultManager.lock()
    }
    
    private func getBiometricButtonLabel() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        default:
            return "Unlock with Passcode"
        }
    }
    
    private func getBiometricButtonIcon() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "key.fill"
        }
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

struct VaultContentView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @Binding var selectedPhotos: [PhotosPickerItem]
    @State private var showTrash = false
    @State private var searchText = ""
    @State private var selectedType: VaultItemType?
    @State private var showFilePicker = false
    @State private var showVideoPicker = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var filteredItems: [VaultItem] {
        vaultManager.items.filter { item in
            let matchesSearch = searchText.isEmpty || 
                item.title.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || item.fileType == selectedType
            return !item.isDeleted && matchesSearch && matchesType
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search files", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterChip(title: "All", isSelected: selectedType == nil) {
                                selectedType = nil
                            }
                            FilterChip(title: "Documents", isSelected: selectedType == .document) {
                                selectedType = .document
                            }
                            FilterChip(title: "Photos", isSelected: selectedType == .image) {
                                selectedType = .image
                            }
                            FilterChip(title: "Videos", isSelected: selectedType == .video) {
                                selectedType = .video
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Content Grid
                ScrollView {
                    if filteredItems.isEmpty {
                        EmptyStateView(
                            icon: "doc.fill",
                            title: "No Files Found",
                            message: searchText.isEmpty ? "Add files to your vault" : "No files match your search"
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredItems) { item in
                                VaultItemView(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Button {
                                showFilePicker = true
                            } label: {
                                Label("Import Document", systemImage: "doc.badge.plus")
                            }
                            
                            PhotosPicker(selection: $selectedPhotos,
                                       matching: .images,
                                       photoLibrary: .shared()) {
                                Label("Import Photos", systemImage: "photo.badge.plus")
                            }
                            
                            Button {
                                showVideoPicker = true
                            } label: {
                                Label("Import Video", systemImage: "video.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        
                        Button {
                            showTrash = true
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .sheet(isPresented: $showTrash) {
                NavigationView {
                    TrashView()
                        .navigationTitle("Recycling Bin")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, .image, .video],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .fileImporter(
                isPresented: $showVideoPicker,
                allowedContentTypes: [.movie, .video, .quickTimeMovie],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                do {
                    guard let userId = vaultManager.currentUser?.id else { return }
                    try await vaultManager.importItems(from: urls, userId: userId)
                } catch {
                    print("Failed to import files: \(error)")
                }
            }
        case .failure(let error):
            print("File import failed: \(error)")
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
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VaultItemView: View {
    let item: VaultItem
    @EnvironmentObject private var vaultManager: VaultManager
    @State private var thumbnail: UIImage?
    @State private var showDetail = false
    @State private var isLoading = false
    @State private var progress: Double = 0
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack {
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if item.fileType == .video {
                                    Image(systemName: "play.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 150, height: 150)
                            .overlay {
                                if isLoading {
                                    VStack {
                                        ProgressView()
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
            if item.fileType == .image || item.fileType == .video {
                loadThumbnail()
            }
        }
        .sheet(isPresented: $showDetail) {
            VaultItemDetailView(document: item)
        }
    }
    
    private var iconName: String {
        switch item.fileType {
        case .document:
            return "doc"
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        }
    }
    
    private func loadThumbnail() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                guard let user = vaultManager.currentUser,
                      let userId = user.id else { return }
                
                let data = try await vaultManager.downloadFile(item, userId: userId) { downloadProgress in
                    Task { @MainActor in
                        self.progress = downloadProgress
                    }
                }
                
                if item.fileType == .video {
                    if let image = await generateVideoThumbnail(from: data) {
                        await MainActor.run {
                            self.thumbnail = image
                            self.isLoading = false
                        }
                    }
                } else if let image = UIImage(data: data) {
                    let thumbnailSize = CGSize(width: 300, height: 300)
                    let thumbnailImage = await image.byPreparingThumbnail(ofSize: thumbnailSize)
                    await MainActor.run {
                        self.thumbnail = thumbnailImage
                        self.isLoading = false
                    }
                }
            } catch {
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
            let asset = AVAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            let cgImage = try await imageGenerator.image(at: time).image
            try? FileManager.default.removeItem(at: tempURL)
            
            return UIImage(cgImage: cgImage)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
}

#Preview {
    VaultView()
} 
