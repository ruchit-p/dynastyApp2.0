import Foundation
import UIKit
import QuickLookThumbnailing
import CoreGraphics
import AVFoundation

class ThumbnailService {
    static let shared = ThumbnailService()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let thumbnailSize = CGSize(width: 120, height: 120)
    
    private init() {
        cache.countLimit = 100 // Maximum number of thumbnails to keep in memory
    }
    
    func generateThumbnail(for item: VaultItem, data: Data) async throws -> UIImage {
        // Check memory cache first
        let cacheKey = NSString(string: item.id)
        if let cachedThumbnail = cache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Generate thumbnail based on file type
        let thumbnail: UIImage
        
        switch item.fileType {
        case .image:
            thumbnail = try await generateImageThumbnail(from: data)
        case .document:
            thumbnail = try await generateDocumentThumbnail(from: data, mimeType: item.metadata.mimeType)
        case .video:
            thumbnail = try await generateVideoThumbnail(from: data)
        case .audio:
            thumbnail = generateAudioThumbnail()
        }
        
        // Cache the thumbnail
        cache.setObject(thumbnail, forKey: cacheKey)
        
        return thumbnail
    }
    
    private func generateImageThumbnail(from data: Data) async throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw ThumbnailError.thumbnailGenerationFailed
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: thumbnailSize)
            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            context.cgContext.fill(rect)
            
            let size = AVMakeRect(aspectRatio: image.size, insideRect: rect).size
            image.draw(in: CGRect(origin: CGPoint(x: (thumbnailSize.width - size.width) / 2,
                                                y: (thumbnailSize.height - size.height) / 2),
                                size: size))
        }
    }
    
    private func generateDocumentThumbnail(from data: Data, mimeType: String) async throws -> UIImage {
        let tempURL = try createTemporaryFile(with: data, mimeType: mimeType)
        defer { try? fileManager.removeItem(at: tempURL) }
        
        let request = QLThumbnailGenerator.Request(
            fileAt: tempURL,
            size: thumbnailSize,
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )
        
        let generator = QLThumbnailGenerator.shared
        let thumbnail = try await generator.generateBestRepresentation(for: request)
        return thumbnail.uiImage
    }
    
    private func generateVideoThumbnail(from data: Data) async throws -> UIImage {
        let tempURL = try createTemporaryFile(with: data, mimeType: "video/mp4")
        defer { try? fileManager.removeItem(at: tempURL) }
        
        let asset = AVAsset(url: tempURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        let cgImage = try await generator.image(at: time).image
        return UIImage(cgImage: cgImage)
    }
    
    private func generateAudioThumbnail() -> UIImage {
        // Return a default audio icon
        return UIImage(systemName: "waveform") ?? UIImage()
    }
    
    private func createTemporaryFile(with data: Data, mimeType: String) throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = UUID().uuidString
        let fileExtension = mimeType.split(separator: "/").last.map(String.init) ?? "tmp"
        let tempURL = tempDir.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

enum ThumbnailError: Error {
    case thumbnailGenerationFailed
    case invalidData
    case fileCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        case .invalidData:
            return "Invalid file data"
        case .fileCreationFailed:
            return "Failed to create temporary file"
        }
    }
} 
