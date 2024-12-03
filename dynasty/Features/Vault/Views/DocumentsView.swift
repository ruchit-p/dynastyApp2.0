import SwiftUI
import UniformTypeIdentifiers
import os.log

struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @State private var isShowingDocumentPicker = false
    @State private var selectedDocument: VaultItem?
    @State private var isRefreshing = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if viewModel.isLoading && !isRefreshing {
                loadingView
            } else {
                contentView
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { isShowingDocumentPicker = true }) {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.isUploading)
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker(isPresented: $isShowingDocumentPicker) { urls in
                guard let userId = authManager.user?.id else { return }
                Task {
                    await viewModel.importDocuments(from: urls, userId: userId)
                    await viewModel.loadDocuments(userId: userId)
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            NavigationView {
                VaultItemDetailView(document: document)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
        }
        .task {
            guard let userId = authManager.user?.id else { return }
            await viewModel.loadDocuments(userId: userId)
        }
        .refreshable {
            guard let userId = authManager.user?.id else { return }
            isRefreshing = true
            await viewModel.loadDocuments(userId: userId)
            isRefreshing = false
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            
            if viewModel.isUploading {
                Text("Uploading... \(Int(viewModel.uploadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
            } else {
                Text("Loading documents...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.documents) { document in
                    DocumentCell(document: document) {
                        selectedDocument = document
                    }
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.documents.isEmpty && !viewModel.isLoading && !isRefreshing {
                ContentUnavailableView(
                    "No Documents",
                    systemImage: "doc.fill",
                    description: Text("Add documents to your vault by tapping the + button")
                )
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDocumentsPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .text, .pdf, .image])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        private let logger = Logger(subsystem: "com.dynasty.DocumentPicker", category: "UI")
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            logger.info("Documents picked: \(urls.map { $0.lastPathComponent }.joined(separator: ", "))")
            
            // Create security scoped URLs
            let secureURLs = urls.map { url in
                // Ensure we have a security scoped URL
                if url.startAccessingSecurityScopedResource() {
                    return url
                } else {
                    logger.error("Failed to access security-scoped resource: \(url.lastPathComponent)")
                    return url
                }
            }
            
            parent.onDocumentsPicked(secureURLs)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            logger.info("Document picker cancelled")
            parent.isPresented = false
        }
        
        deinit {
            // Clean up any remaining security-scoped resources
            logger.info("DocumentPicker coordinator deinit")
        }
    }
}

struct DocumentCell: View {
    let document: VaultItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .frame(height: 120)
                
                Text(document.title)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                
                Text(formatFileSize(document.metadata.fileSize))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    private var iconName: String {
        switch document.fileType {
        case .document:
            return "doc.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note"
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct DocumentDetailView: View {
    let document: VaultItem
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        List {
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
            }
        }
        .navigationTitle("Document Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
    }
    
    private func downloadDocument() {
        guard let userId = authManager.user?.id else { return }
        
        isLoading = true
        Task {
            do {
                let viewModel = DocumentsViewModel()
                let data = try await viewModel.downloadDocument(document, userId: userId)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(document.title)
                try data.write(to: tempURL)
                
                let activityVC = UIActivityViewController(
                    activityItems: [tempURL],
                    applicationActivities: nil
                )
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    await MainActor.run {
                        rootVC.present(activityVC, animated: true)
                    }
                }
            } catch {
                self.error = error
                self.showError = true
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
} 
