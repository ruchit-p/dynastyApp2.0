import SwiftUI
import os.log

struct TrashView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var isSelecting = false
    @State private var selectedItems = Set<VaultItem>()
    @State private var showError = false
    @State private var error: Error?
    
    private let logger = Logger(subsystem: "com.dynasty.TrashView", category: "UI")
    
    private var trashedItems: [VaultItem] {
        vaultManager.items.filter { $0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        VStack {
            // Top Header
            HStack {
                Text("Trash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Text("\(trashedItems.count) Items")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if !isSelecting {
                    Menu {
                        Button("Select") {
                            isSelecting = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .padding(.leading, 8)
                    }
                    .padding(.trailing)
                } else {
                    Menu {
                        Button("Select All") {
                            for item in trashedItems {
                                selectedItems.insert(item)
                            }
                        }
                        if !selectedItems.isEmpty {
                            Button("Restore") {
                                Task {
                                    await restoreSelectedItems()
                                }
                            }
                            Button("Delete Permanently", role: .destructive) {
                                Task {
                                    await deleteSelectedItemsPermanently()
                                }
                            }
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
            
            if trashedItems.isEmpty {
                VStack {
                    Spacer()
                    Text("Trash is empty")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Text("Items in trash will be automatically deleted after 30 days")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else {
                List {
                    ForEach(trashedItems) { item in
                        HStack(spacing: 12) {
                            VaultItemThumbnailView(item: item)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body)
                                    .lineLimit(1)
                                
                                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isSelecting {
                                Image(systemName: selectedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItems.contains(item) ? .blue : .gray)
                                    .font(.title3)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelecting {
                                toggleSelection(item)
                            }
                        }
                        .contextMenu {
                            Button {
                                Task {
                                    await restoreItem(item)
                                }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    await deleteItemPermanently(item)
                                }
                            } label: {
                                Label("Delete Permanently", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func toggleSelection(_ item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func restoreSelectedItems() async {
        do {
            for item in selectedItems {
                try await vaultManager.restoreItem(item)
            }
            selectedItems.removeAll()
            isSelecting = false
        } catch {
            self.error = error
            self.showError = true
        }
    }
    
    private func deleteSelectedItemsPermanently() async {
        do {
            for item in selectedItems {
                try await vaultManager.permanentlyDeleteItem(item)
            }
            selectedItems.removeAll()
            isSelecting = false
        } catch {
            self.error = error
            self.showError = true
        }
    }
    
    private func restoreItem(_ item: VaultItem) async {
        do {
            try await vaultManager.restoreItem(item)
        } catch {
            self.error = error
            self.showError = true
        }
    }
    
    private func deleteItemPermanently(_ item: VaultItem) async {
        do {
            try await vaultManager.permanentlyDeleteItem(item)
        } catch {
            self.error = error
            self.showError = true
        }
    }
} 