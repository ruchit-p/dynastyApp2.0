import SwiftUI
import os.log

struct TrashView: View {
    @EnvironmentObject private var vaultManager: VaultManager
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
        .sheet(isPresented: $showDetail, content: {
            if let item = selectedItem {
                VaultItemDetailView(document: item)
            }
        })
        .alert("Delete Permanently?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    permanentlyDeleteItem(item)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func restoreItem(_ item: VaultItem) {
        Task {
            do {
                try await vaultManager.restoreItem(item)
            } catch {
                self.error = error
                self.showError = true
            }
        }
    }
    
    private func permanentlyDeleteItem(_ item: VaultItem) {
        Task {
            do {
                try await vaultManager.permanentlyDeleteItem(item)
            } catch {
                self.error = error
                self.showError = true
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