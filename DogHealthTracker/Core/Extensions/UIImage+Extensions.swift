import UIKit

// MARK: - UIImage Extensions

extension UIImage {
    
    /// Compresses and base64-encodes the image, targeting a max file size in KB.
    /// Tries multiple quality levels to stay under the limit.
    func compressedBase64(maxSizeKB: Int) -> String? {
        let maxBytes = maxSizeKB * 1024
        var quality: CGFloat = 0.9
        var imageData: Data?
        
        while quality >= 0.1 {
            if let data = jpegData(compressionQuality: quality), data.count <= maxBytes {
                imageData = data
                break
            }
            quality -= 0.1
        }
        
        // If still too large, resize first then try again
        if imageData == nil {
            if let resized = resized(toMaxDimension: 1024),
               let data = resized.jpegData(compressionQuality: 0.8) {
                imageData = data
            }
        }
        
        return imageData?.base64EncodedString()
    }
    
    /// Resizes the image so its longest dimension does not exceed `maxDimension`.
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Returns the approximate JPEG file size in bytes at the given compression quality.
    func approximateJPEGSize(quality: CGFloat = 0.8) -> Int {
        jpegData(compressionQuality: quality)?.count ?? 0
    }
}
