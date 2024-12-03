import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @State private var showingFilePicker = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var selectedItem: VaultItem?
    @State private var showingItemDetail = false
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading documents...")
            } else {
                content
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker(
                types: viewModel.supportedTypes,
                allowsMultipleSelection: false
            ) { urls in
                Task {
                    await viewModel.uploadFiles(urls)
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $selectedItem) { item in
            NavigationView {
                VaultItemDetailView(item: item)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadDocuments()
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.items) { item in
                    VaultItemCell(item: item, thumbnail: viewModel.thumbnails[item.id])
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDocuments()
        }
    }
}

struct VaultItemCell: View {
    let item: VaultItem
    let thumbnail: UIImage?
    
    var body: some View {
        VStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
            } else {
                defaultThumbnail
            }
            
            Text(item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            
            Text(item.metadata.fileSize.formatFileSize())
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var defaultThumbnail: some View {
        Image(systemName: item.fileType.iconName)
            .font(.system(size: 40))
            .foregroundColor(.accentColor)
            .frame(height: 120)
    }
}

class DocumentsViewModel: ObservableObject {
    @Published var items: [VaultItem] = []
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let vaultManager = VaultManager.shared
    private let thumbnailService = ThumbnailService.shared
    
    var supportedTypes: [UTType] {
        [.pdf, .plainText, .image, .movie, .audio, .spreadsheet, .presentation]
    }
    
    @MainActor
    func loadDocuments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await vaultManager.fetchItems(for: "currentUserId") // Replace with actual user ID
            items = vaultManager.items
            await loadThumbnails()
        } catch {
            self.error = error
        }
    }
    
    @MainActor
    private func loadThumbnails() async {
        for item in items {
            do {
                let data = try await vaultManager.downloadFile(item: item)
                let thumbnail = try await thumbnailService.generateThumbnail(for: item, data: data)
                thumbnails[item.id] = thumbnail
            } catch {
                print("Failed to load thumbnail for item \(item.id): \(error)")
            }
        }
    }
    
    @MainActor
    func uploadFiles(_ urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }
        
        for url in urls {
            do {
                let type = try determineFileType(from: url)
                let item = try await vaultManager.uploadFile(
                    userId: "currentUserId", // Replace with actual user ID
                    fileURL: url,
                    title: url.lastPathComponent,
                    description: nil,
                    type: type
                )
                items.append(item)
                
                // Generate thumbnail
                if let data = try? Data(contentsOf: url) {
                    let thumbnail = try await thumbnailService.generateThumbnail(for: item, data: data)
                    thumbnails[item.id] = thumbnail
                }
            } catch {
                self.error = error
            }
        }
    }
    
    private func determineFileType(from url: URL) throws -> VaultItemType {
        let typeIdentifier = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier ?? ""
        
        if UTType(typeIdentifier)?.conforms(to: .image) ?? false {
            return .image
        } else if UTType(typeIdentifier)?.conforms(to: .movie) ?? false {
            return .video
        } else if UTType(typeIdentifier)?.conforms(to: .audio) ?? false {
            return .audio
        } else {
            return .document
        }
    }
}

extension VaultItemType {
    var iconName: String {
        switch self {
        case .document:
            return "doc.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "waveform"
        }
    }
}

extension Int64 {
    func formatFileSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
        }
    }
} 