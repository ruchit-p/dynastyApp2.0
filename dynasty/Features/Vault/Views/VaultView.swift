import SwiftUI
import os.log
import PhotosUI
import AVFoundation

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
            if let user = authManager.user {
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
            } else {
                VaultSignInRequiredView()
            }
        }
        .environmentObject(vaultManager)
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
    }
    
    private func handleUserChange(_ user: User?) {
        vaultManager.setCurrentUser(user)
        if user != nil {
            authenticate()
        } else {
            vaultManager.lock()
        }
    }
    
    private func authenticate() {
        guard !vaultManager.isAuthenticating else { return }
        guard let userId = authManager.user?.id else {
            logger.error("Cannot authenticate: No valid user ID")
            return
        }
        
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
            if let user = authManager.user, !vaultManager.isAuthenticating {
                logger.info("App became active. Re-authenticating vault.")
                authenticate()
            }
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
    
    private func getBiometricButtonLabel() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default: return "Unlock with Passcode"
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
    @State private var error: Error?
    @State private var showError = false
    
    private let logger = Logger(subsystem: "com.dynasty.VaultContentView", category: "UI")
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]
    
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
                SearchFilterBar(searchText: $searchText, selectedType: $selectedType)
                
                // Content Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredItems) { item in
                            VaultItemView(item: item)
                                .environmentObject(vaultManager)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    Task {
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
                
                // Bottom Toolbar
                VaultToolbar(
                    selectedPhotos: $selectedPhotos,
                    showFilePicker: $showFilePicker
                )
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText, .image, .video],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert("Error", isPresented: $showError, presenting: error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
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
}

// Helper Views
struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedType: VaultItemType?
    
    var body: some View {
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
            let asset = AVAsset(url: tempURL)
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
