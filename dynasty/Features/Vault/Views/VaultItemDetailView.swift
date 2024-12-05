import SwiftUI
import os.log

struct VaultItemDetailView: View {
    let document: VaultItem
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    @State private var showShareSheet = false
    @State private var tempFileURL: URL?
    @State private var showDeleteConfirmation = false
    private let logger = Logger(subsystem: "com.dynasty.VaultItemDetailView", category: "UI")
    
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
                
                Button(action: shareDocument) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(isLoading)
                
                Button(role: .destructive, action: deleteDocument) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(isLoading)
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
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
    }
    
    private func downloadDocument() {
        isLoading = true
        Task {
            do {
                logger.info("Starting download for document: \(document.id)")
                let data = try await vaultManager.downloadFile(document)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(document.title)
                try data.write(to: tempURL, options: .atomic)
                
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [tempURL],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                        rootVC.present(activityVC, animated: true)
                    }
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
                let data = try await vaultManager.downloadFile(document)
                
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
}
