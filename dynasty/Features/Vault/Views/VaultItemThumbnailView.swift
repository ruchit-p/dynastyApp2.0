import SwiftUI
import AVFoundation
import _Concurrency

struct VaultItemThumbnailView: View {
    @EnvironmentObject var vaultManager: VaultManager
    let item: VaultItem
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: getSystemImageName())
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                    }
            }
            
            if error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func getSystemImageName() -> String {
        switch item.fileType {
        case .document:
            return "doc.text.fill"
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .audio:
            return "music.note"
        case .folder:
            return "folder.fill"
        }
    }
    
    private func loadThumbnail() {
        guard thumbnail == nil, !isLoading, item.fileType != .folder else { return }
        
        // Check cache first
        if let cachedThumbnail = vaultManager.cachedThumbnail(for: item) {
            self.thumbnail = cachedThumbnail
            return
        }
        
        isLoading = true
        
        Task {
            do {
                if vaultManager.isLocked {
                    throw VaultError.vaultLocked
                }
                
                let data = try await vaultManager.downloadFile(item)
                
                switch item.fileType {
                case .image:
                    if let image = UIImage(data: data) {
                        let finalImage: UIImage
                        if #available(iOS 15.0, *),
                           let resizedImage = await image.byPreparingThumbnail(ofSize: CGSize(width: 150, height: 150)) {
                            finalImage = resizedImage
                        } else {
                            finalImage = image.resize(to: CGSize(width: 150, height: 150))
                        }
                        
                        await MainActor.run {
                            self.thumbnail = finalImage
                            self.isLoading = false
                            // Cache the encrypted thumbnail
                            vaultManager.cacheThumbnail(finalImage, for: item)
                        }
                    }
                case .video:
                    if let thumbnailImage = await generateVideoThumbnail(from: data) {
                        await MainActor.run {
                            self.thumbnail = thumbnailImage
                            self.isLoading = false
                            // Cache the encrypted thumbnail
                            vaultManager.cacheThumbnail(thumbnailImage, for: item)
                        }
                    }
                default:
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from data: Data) async -> UIImage? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        do {
            try data.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 150, height: 150)
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            try? FileManager.default.removeItem(at: tempURL)
            
            let thumbnail = UIImage(cgImage: cgImage)
            return thumbnail.resize(to: CGSize(width: 150, height: 150))
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
} 
