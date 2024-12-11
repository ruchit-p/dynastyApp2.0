import SwiftUI
import os.log
import AVFoundation

class VaultDocumentScanningFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "DocumentScanning")
    
    static func saveScannedDocumentAsPDF(images: [UIImage], documentName: String, vaultManager: VaultManager) async throws {
        guard let userId = vaultManager.currentUser?.id else {
            throw VaultError.authenticationFailed("User not authenticated")
        }
        guard !images.isEmpty else {
            throw VaultError.invalidData("No scanned images to save")
        }
        
        let pdfData = createPDFData(from: images)
        let keyId = try await vaultManager.generateEncryptionKey(for: userId)
        
        let finalName = documentName.isEmpty ? "Untitled.pdf" : "\(documentName).pdf"
        let metadata = VaultItemMetadata(
            originalFileName: finalName,
            fileSize: Int64(pdfData.count),
            mimeType: "application/pdf",
            encryptionKeyId: keyId,
            hash: vaultManager.generateFileHash(for: pdfData)
        )
        
        try await vaultManager.importData(
            pdfData,
            filename: UUID().uuidString + ".pdf",
            fileType: .document,
            metadata: metadata,
            userId: userId,
            parentFolderId: nil
        )
    }
    
    private static func createPDFData(from images: [UIImage]) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "DynastyApp",
            kCGPDFContextAuthor: "DynastyApp"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 595.2 // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        return renderer.pdfData { (context) in
            for image in images {
                context.beginPage()
                let maxRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                let aspectRect = AVMakeRect(aspectRatio: image.size, insideRect: maxRect)
                image.draw(in: aspectRect)
            }
        }
    }
} 