import SwiftUI

struct SelectionOverlay: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)

            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .position(x: 20, y: 20)
        }
        .onTapGesture(perform: action)
    }

        private func downloadSelectedItems() async {
        do {
            var tempFiles: [URL] = []
            for item in selectedItems {
                let data = try await vaultManager.downloadFile(item)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(item.title)
                try data.write(to: tempURL, options: .atomic)
                tempFiles.append(tempURL)
            }
            
            await MainActor.run {
                self.shareSheetItems = tempFiles
                self.showShareSheet = true
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }

       private func shareSelectedItems() async {
        do {
            var tempFiles: [URL] = []
            for item in selectedItems {
                let data = try await vaultManager.downloadFile(item)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(item.title)
                try data.write(to: tempURL, options: .atomic)
                tempFiles.append(tempURL)
            }
            
            await MainActor.run {
                self.shareSheetItems = tempFiles
                self.showShareSheet = true
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.showError = true
            }
        }
    }

       private func deleteSelectedItems() async {
        do {
            for item in selectedItems {
                    try await vaultManager.moveToTrash(item)
            }
            selectedItems.removeAll()
            vaultManager.clearItemsCache()
            isSelecting = false
            await refreshItems()
        } catch {
            self.error = error
            self.showError = true
        }
    }
} 