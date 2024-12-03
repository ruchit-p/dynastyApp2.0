import SwiftUI
import UniformTypeIdentifiers
import os.log

struct VaultItemDetailView: View {
    let document: VaultItem
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var error: Error?
    @State private var showError = false
    
    private let vaultManager = VaultManager.shared
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
                
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
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
        .confirmationDialog(
            "Are you sure you want to delete this document?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteDocument)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
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
                logger.info("Starting download for document: \(document.id)")
                let data = try await vaultManager.downloadFile(document, userId: userId)
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(document.title)
                try data.write(to: tempURL, options: .atomic)
                
                await MainActor.run {
                    let activityVC = UIActivityViewController(
                        activityItems: [tempURL],
                        applicationActivities: nil
                    )
                    
                    // Find the current window scene and present the activity view controller
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            // Clean up temp file after sharing
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                        rootVC.present(activityVC, animated: true)
                    }
                }
                
                logger.info("Successfully downloaded document: \(document.id)")
            } catch {
                logger.error("Failed to download document: \(error.localizedDescription)")
                self.error = error
                self.showError = true
            }
            isLoading = false
        }
    }
    
    private func deleteDocument() {
        isLoading = true
        Task {
            do {
                logger.info("Deleting document: \(document.id)")
                try await vaultManager.deleteItem(document)
                logger.info("Successfully deleted document: \(document.id)")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                logger.error("Failed to delete document: \(error.localizedDescription)")
                self.error = error
                self.showError = true
                isLoading = false
            }
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
