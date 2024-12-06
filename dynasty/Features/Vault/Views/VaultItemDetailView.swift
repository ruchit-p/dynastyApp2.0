import SwiftUI
import AVKit
import os.log
import QuickLook

struct VaultItemDetailView: View {
    @State var document: VaultItem
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    @State private var showShareSheet = false
    @State private var tempFileURL: URL?
    @State private var showDeleteConfirmation = false
    @State private var showRenameSheet = false
    @State private var newName: String = ""
    
    @State private var fileData: Data?
    @State private var previewURL: URL?
    @State private var previewImage: UIImage?
    @State private var showQuickLook = true
    
    private let logger = Logger(subsystem: "com.dynasty.VaultItemDetailView", category: "UI")
    
    var body: some View {
        Group {
            if showQuickLook, let url = previewURL {
                QuickLookPreview(url: url, displayName: fileNameWithoutExtension(document.title))
                    .edgesIgnoringSafeArea(.all)
            } else {
                List {
                    if let previewImage = previewImage, document.fileType == .image {
                        Section {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 300)
                                .background(Color.clear)
                                .clipped()
                        }
                    } else if document.fileType == .video, let previewURL = previewURL {
                        Section {
                            VideoPlayer(player: AVPlayer(url: previewURL))
                                .frame(maxHeight: 300)
                        }
                    } else {
                        Section {
                            Image(systemName: iconForType(document.fileType))
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                                .frame(width: 100, height: 100)
                                .padding()
                        }
                    }
                    
                    Section("Details") {
                        LabeledContent("Name", value: document.title)
                        LabeledContent("Type", value: document.fileType.rawValue.capitalized)
                        LabeledContent("Size", value: formatFileSize(document.metadata.fileSize))
                        if let description = document.description {
                            LabeledContent("Description", value: description)
                        }
                        LabeledContent("Added", value: document.createdAt.formatted())
                        LabeledContent("Modified", value: document.updatedAt.formatted())
                    }
                    
                    Section {
                        Button(action: downloadDocument) {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                        .disabled(isLoading)
                        
                        Button(action: shareDocument) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isLoading)
                        
                        Button(action: { 
                            newName = document.title
                            showRenameSheet = true 
                        }) {
                            Label("Rename", systemImage: "pencil")
                        }
                        .disabled(isLoading)
                        
                        Button(role: .destructive, action: deleteDocument) {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
        .navigationTitle(showQuickLook ? fileNameWithoutExtension(document.title) : "Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showQuickLook.toggle() }) {
                        Label(showQuickLook ? "Show Details" : "Show Preview", 
                              systemImage: showQuickLook ? "list.bullet" : "eye")
                    }
                    Button(action: { 
                        newName = document.title
                        showRenameSheet = true 
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(action: shareDocument) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this item?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: confirmDelete)
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = tempFileURL {
                ShareSheet(
                    activityItems: [url],
                    completion: { _, _, _, _ in
                        try? FileManager.default.removeItem(at: url)
                        tempFileURL = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            NavigationView {
                Form {
                    Section {
                        TextField("New Name", text: $newName)
                    }
                }
                .navigationTitle("Rename Item")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showRenameSheet = false
                    },
                    trailing: Button("Save") {
                        Task {
                            await renameItem()
                        }
                    }
                    .disabled(newName.isEmpty || newName == document.title)
                )
            }
            .presentationDetents([.medium])
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .onAppear {
            Task {
                await loadPreview()
            }
        }
        .onChange(of: vaultManager.items) { newItems in
            if let updatedItem = newItems.first(where: { $0.id == document.id }) {
                document = updatedItem
            }
        }
    }
    
    private func fileNameWithoutExtension(_ fileName: String) -> String {
        return (fileName as NSString).deletingPathExtension
    }
    
    private func loadPreview() async {
        do {
            let data: Data
            if let cached = vaultManager.cachedFileData(for: document) {
                data = cached
            } else {
                data = try await vaultManager.downloadFile(document)
            }
            
            fileData = data
            
            switch document.fileType {
            case .image:
                if let image = UIImage(data: data) {
                    let maxSize = CGSize(width: UIScreen.main.bounds.width, height: 300)
                    let scaledImage = image.scaleToFit(within: maxSize)
                    previewImage = scaledImage
                }
            case .video:
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                try data.write(to: tempURL)
                previewURL = tempURL
            default:
                break
            }
        } catch {
            logger.error("Failed to load preview: \(error.localizedDescription)")
        }
    }
    
    private func renameItem() async {
        guard !newName.isEmpty else { return }
        isLoading = true
        do {
            try await vaultManager.renameItem(document, to: newName)
            showRenameSheet = false
        } catch {
            self.error = error
            self.showError = true
        }
        isLoading = false
    }
    
    private func downloadDocument() {
        isLoading = true
        Task {
            do {
                logger.info("Starting download for document: \(document.id)")
                let data: Data
                if let cached = vaultManager.cachedFileData(for: document) {
                    data = cached
                } else {
                    data = try await vaultManager.downloadFile(document)
                }
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(document.title)
                try data.write(to: tempURL, options: .atomic)
                
                await MainActor.run {
                    self.tempFileURL = tempURL
                    self.showShareSheet = true
                }
                
                logger.info("Successfully downloaded document: \(document.id)")
            } catch {
                logger.error("Failed to download document: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
            isLoading = false
        }
    }
    
    private func shareDocument() {
        isLoading = true
        Task {
            do {
                logger.info("Starting share for document: \(document.id)")
                let data: Data
                if let cached = vaultManager.cachedFileData(for: document) {
                    data = cached
                } else {
                    data = try await vaultManager.downloadFile(document)
                }
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(document.title)
                try data.write(to: tempURL, options: .atomic)
                self.tempFileURL = tempURL
                
                await MainActor.run {
                    showShareSheet = true
                }
                
                logger.info("Successfully prepared document for sharing: \(document.id)")
            } catch {
                logger.error("Failed to share document: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
            isLoading = false
        }
    }
    
    private func deleteDocument() {
        showDeleteConfirmation = true
    }
    
    private func confirmDelete() {
        guard let userId = authManager.user?.id else { return }
        
        isLoading = true
        Task {
            do {
                logger.info("Deleting document: \(document.id)")
                try await vaultManager.permanentlyDeleteItem(document)
                logger.info("Successfully deleted document: \(document.id)")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                logger.error("Failed to delete document: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
            isLoading = false
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func iconForType(_ fileType: VaultItemType) -> String {
        switch fileType {
        case .document:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note.fill"
        case .folder:
            return "folder.fill"
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    let displayName: String
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return PreviewItem(url: parent.url, title: parent.displayName)
        }
    }
}

class PreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?
    
    init(url: URL, title: String) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}
