import UIKit

extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return resized
    }
    
    func scaleToFit(within maxSize: CGSize) -> UIImage {
        let scale = min(
            maxSize.width / size.width,
            maxSize.height / size.height
        )
        
        if scale >= 1 {
            return self // Image is smaller than maxSize, no need to scale
        }
        
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        return resize(to: newSize)
    }
} 