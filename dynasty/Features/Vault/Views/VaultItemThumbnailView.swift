import SwiftUI
import AVKit
import os.log

struct VaultItemThumbnailView: View {
    let item: VaultItem
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    @EnvironmentObject var vaultManager: VaultManager
    
    private let logger = Logger(subsystem: "com.dynasty.app", category: "VaultItemThumbnailView")
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if error != nil {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: getSystemImageName())
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                Text(item.title)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
        guard thumbnail == nil, !isLoading else { return }
        
        // Check cache first
        if let cachedThumbnail = vaultManager.cachedThumbnail(for: item) {
            self.thumbnail = cachedThumbnail
            return
        }
        
        Task {
            do {
                isLoading = true
                error = nil
                
                // Check if vault is locked
                guard !vaultManager.isLocked else {
                    throw VaultError.vaultLocked
                }
                
                let data = try await vaultManager.downloadFile(item)
                
                switch item.fileType {
                case .image:
                    if let image = UIImage(data: data) {
                        let finalImage: UIImage
                        if #available(iOS 15.0, *),
                           let resizedImage = await image.byPreparingThumbnail(ofSize: CGSize(width: 300, height: 300)) {
                            finalImage = resizedImage
                        } else {
                            finalImage = image.resize(to: CGSize(width: 300, height: 300))
                        }
                        
                        await MainActor.run {
                            self.thumbnail = finalImage
                            self.isLoading = false
                            // Cache the encrypted thumbnail
                            vaultManager.cacheThumbnail(finalImage, for: item)
                        }
                    }
                case .video:
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                    
                    try data.write(to: tempURL)
                    
                    do {
                        let thumbnailImage = try await generateVideoThumbnail(from: tempURL)
                        let finalImage = thumbnailImage.resize(to: CGSize(width: 300, height: 300))
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        await MainActor.run {
                            self.thumbnail = finalImage
                            self.isLoading = false
                            // Cache the encrypted thumbnail
                            vaultManager.cacheThumbnail(finalImage, for: item)
                        }
                    } catch {
                        try? FileManager.default.removeItem(at: tempURL)
                        throw error
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
                logger.error("Failed to load thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    private func generateVideoThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: .init(seconds: 0, preferredTimescale: 1)) { cgImage, time, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let cgImage = cgImage else {
                    continuation.resume(throwing: NSError(domain: "VideoThumbnail", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"]))
                    return
                }
                
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }
} 
