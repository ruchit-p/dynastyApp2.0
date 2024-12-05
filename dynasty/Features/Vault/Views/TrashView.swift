import SwiftUI
import os.log

struct TrashView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var selectedItem: VaultItem?
    @State private var showDetail = false
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: VaultItem?
    @State private var error: Error?
    @State private var showError = false
    
    private let logger = Logger(subsystem: "com.dynasty.TrashView", category: "UI")
    
    var deletedItems: [VaultItem] {
        vaultManager.items.filter { $0.isDeleted }
    }
    
    var body: some View {
        List {
            ForEach(deletedItems) { item in
                VaultItemRow(item: item)
                    .onTapGesture {
                        selectedItem = item
                        showDetail = true
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Permanently", systemImage: "trash")
                        }
                        
                        Button {
                            restoreItem(item)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                    }
            }
        }
        .navigationTitle("Trash")
        .confirmationDialog("Are you sure you want to permanently delete this item?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Permanently", role: .destructive) {
                if let item = itemToDelete {
                    permanentlyDeleteItem(item)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(item: $selectedItem) { item in
            VaultItemDetailView(document: item)
                .environmentObject(vaultManager)
        }
    }
    
    private func restoreItem(_ item: VaultItem) {
        Task {
            do {
                logger.info("Attempting to restore item: \(item.id)")
                try await vaultManager.restoreItem(item)
                logger.info("Successfully restored item: \(item.id)")
            } catch {
                logger.error("Failed to restore item: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
    
    private func permanentlyDeleteItem(_ item: VaultItem) {
        Task {
            do {
                logger.info("Attempting to permanently delete item: \(item.id)")
                try await vaultManager.permanentlyDeleteItem(item)
                logger.info("Successfully permanently deleted item: \(item.id)")
            } catch {
                logger.error("Failed to permanently delete item: \(error.localizedDescription)")
                await MainActor.run {
                    self.error = error
                    self.showError = true
                }
            }
        }
    }
}

struct VaultItemRow: View {
    let item: VaultItem
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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
    
    private var formattedDate: String {
        item.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
} 