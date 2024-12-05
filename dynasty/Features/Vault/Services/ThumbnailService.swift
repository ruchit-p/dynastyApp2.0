import Foundation
import UIKit
import QuickLookThumbnailing
import CoreGraphics
import AVFoundation

actor ThumbnailService {
    static let shared = ThumbnailService()
    
    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()
    
    private let fileManager = FileManager.default
    private let thumbnailSize = CGSize(width: 120, height: 120)
    private let processingQueue = DispatchQueue(label: "com.dynasty.thumbnailService", qos: .userInitiated)
    
    private var ongoingOperations: [String: Task<UIImage, Error>] = [:]
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.clearCache()
            }
        }
    }
    
    private func clearCache() {
        cache.removeAllObjects()
        ongoingOperations.values.forEach { $0.cancel() }
        ongoingOperations.removeAll()
    }
    
    func generateThumbnail(for item: VaultItem, data: Data) async throws -> UIImage {
        let cacheKey = NSString(string: item.id)
        
        // Check cache first
        if let cachedThumbnail = cache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Check for existing operation
        if let existingOperation = ongoingOperations[item.id] {
            return try await existingOperation.value
        }
        
        // Create new operation
        let operation = Task.detached { [weak self] in
            guard let self = self else {
                throw ThumbnailError.thumbnailGenerationFailed
            }
            
            let thumbnail: UIImage
            
            switch item.fileType {
            case .image:
                thumbnail = try await self.generateImageThumbnail(from: data)
            case .document:
                thumbnail = try await self.generateDocumentThumbnail(from: data, mimeType: item.metadata.mimeType)
            case .video:
                thumbnail = try await self.generateVideoThumbnail(from: data)
            case .audio:
                thumbnail = try await self.generateAudioThumbnail()
            }
            
            // Cache the result if not cancelled
            if !Task.isCancelled {
                await self.cacheResult(thumbnail, forKey: cacheKey)
            }
            
            return thumbnail
        }
        
        ongoingOperations[item.id] = operation
        
        do {
            let result = try await operation.value
            ongoingOperations.removeValue(forKey: item.id)
            return result
        } catch {
            ongoingOperations.removeValue(forKey: item.id)
            throw error
        }
    }
    
    private func generateImageThumbnail(from data: Data) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                autoreleasepool {
                    do {
                        guard let image = UIImage(data: data) else {
                            continuation.resume(throwing: ThumbnailError.thumbnailGenerationFailed)
                            return
                        }
                        
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = UIScreen.main.scale
                        format.opaque = true
                        
                        let renderer = UIGraphicsImageRenderer(size: self.thumbnailSize, format: format)
                        let thumbnail = renderer.image { context in
                            let rect = CGRect(origin: .zero, size: self.thumbnailSize)
                            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
                            context.cgContext.fill(rect)
                            
                            let size = AVMakeRect(aspectRatio: image.size, insideRect: rect).size
                            image.draw(in: CGRect(
                                origin: CGPoint(
                                    x: (self.thumbnailSize.width - size.width) / 2,
                                    y: (self.thumbnailSize.height - size.height) / 2
                                ),
                                size: size
                            ))
                        }
                        
                        continuation.resume(returning: thumbnail)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
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
        do {
            let tempURL = try createTemporaryFile(with: data, mimeType: "video/mp4")
            defer { try? fileManager.removeItem(at: tempURL) }
            
            let asset = AVAsset(url: tempURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = thumbnailSize
            
            return try await withCheckedThrowingContinuation { continuation in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: 1, preferredTimescale: 60))]) { _, image, _, result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let image = image, result == .succeeded {
                        continuation.resume(returning: UIImage(cgImage: image))
                    } else {
                        continuation.resume(throwing: ThumbnailError.thumbnailGenerationFailed)
                    }
                }
            }
        } catch {
            throw ThumbnailError.thumbnailGenerationFailed
        }
    }
    
    private func generateAudioThumbnail() -> UIImage {
        UIImage(systemName: "waveform") ?? UIImage()
    }
    
    private func createTemporaryFile(with data: Data, mimeType: String) throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = UUID().uuidString
        let fileExtension = mimeType.split(separator: "/").last.map(String.init) ?? "tmp"
        let tempURL = tempDir.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        
        try data.write(to: tempURL)
        return tempURL
    }
    
    private func cacheResult(_ thumbnail: UIImage, forKey key: NSString) {
        cache.setObject(thumbnail, forKey: key)
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
