import SwiftUI

struct VaultItemThumbnailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let item: VaultItem
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                // Default icon if no thumbnail loaded yet
                Image(systemName: iconForItem(item))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .padding(20)
            }
        }
        .frame(width: 100, height: 100)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil, !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                if let thumbnailURL = item.thumbnailURL {
                    // Load thumbnail from URL if available
                    if let url = URL(string: thumbnailURL),
                       let (data, _) = try? await URLSession.shared.data(from: url),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            self.thumbnail = image
                            self.isLoading = false
                        }
                        return
                    }
                }
                
                // If no thumbnail URL or failed to load, try to generate from the actual file
                if item.fileType == .image {
                    let data = try await vaultManager.downloadFile(item)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.thumbnail = image
                        }
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("Failed to load thumbnail: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func iconForItem(_ item: VaultItem) -> String {
        switch item.fileType {
        case .document:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note"
        }
    }
} 