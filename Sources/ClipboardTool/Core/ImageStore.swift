import AppKit
import CryptoKit
import Foundation

/// Persists clipboard images to disk as PNG files under the app's Application
/// Support directory.  Filenames are the SHA-256 hash of the PNG data so
/// identical images are automatically deduplicated.
///
/// Layout on disk:
///   ~/Library/Application Support/com.niconi21.clipboardtool/images/
///     <hash>.png          ← full-size image
///     <hash>_thumb.png    ← thumbnail, max 120 px tall, same aspect ratio
///
/// The value stored in `ClipboardEntry.content` is the relative path
/// "images/<hash>.png", and `ClipboardEntry.contentType` is `.image`.
struct ImageStore {

    // MARK: - Constants

    static let thumbnailMaxHeight: CGFloat = 120

    // MARK: - Init

    private let imagesDir: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let base = appSupport.appendingPathComponent("com.niconi21.clipboardtool")
        imagesDir = base.appendingPathComponent("images")
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true
        )
    }

    // Allows tests to inject a custom directory.
    init(imagesDir: URL) {
        self.imagesDir = imagesDir
        try? FileManager.default.createDirectory(
            at: imagesDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public API

    /// Stores an image on disk and returns the relative path
    /// `"images/<hash>.png"`.
    ///
    /// Returns `nil` if the image was already stored (dedup by SHA-256).
    /// Throws if PNG encoding or file I/O fails.
    func store(image: NSImage) throws -> String? {
        let fullPNG = try pngData(from: image)
        let hash = sha256Hex(of: fullPNG)
        let filename = "\(hash).png"
        let fullURL = imagesDir.appendingPathComponent(filename)

        // Dedup: file already on disk means we have seen this image before.
        if FileManager.default.fileExists(atPath: fullURL.path) {
            return nil
        }

        // Write full-size PNG.
        try fullPNG.write(to: fullURL, options: Data.WritingOptions.atomic)

        // Generate and write thumbnail.
        let thumbURL = imagesDir.appendingPathComponent("\(hash)_thumb.png")
        let thumbnail = makeThumbnail(from: image, maxHeight: Self.thumbnailMaxHeight) ?? image
        let thumbPNG = try pngData(from: thumbnail)
        try thumbPNG.write(to: thumbURL, options: Data.WritingOptions.atomic)

        return "images/\(filename)"
    }

    /// Returns the URL of the thumbnail for a relative path such as
    /// `"images/<hash>.png"`.  Returns `nil` when the path is not an image
    /// relative path.
    func thumbnailURL(for relativePath: String) -> URL? {
        guard relativePath.hasPrefix("images/"), relativePath.hasSuffix(".png") else {
            return nil
        }
        let url = URL(fileURLWithPath: relativePath)
        let hash = url.deletingPathExtension().lastPathComponent
        return imagesDir.appendingPathComponent("\(hash)_thumb.png")
    }

    /// Returns the absolute URL for the full-size image at the given relative
    /// path.  Returns `nil` when the path is not an image relative path.
    func fullImageURL(for relativePath: String) -> URL? {
        guard relativePath.hasPrefix("images/"), relativePath.hasSuffix(".png") else {
            return nil
        }
        let url = URL(fileURLWithPath: relativePath)
        let filename = url.lastPathComponent
        return imagesDir.appendingPathComponent(filename)
    }

    /// Deletes PNG files in the images directory whose relative paths are not
    /// present in `referencedPaths`.
    ///
    /// Call this after deleting history entries to reclaim disk space.
    func cleanupOrphaned(referencedPaths: Set<String>) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: imagesDir,
            includingPropertiesForKeys: nil
        )
        for fileURL in contents where fileURL.pathExtension == "png" {
            let relativePath = "images/\(fileURL.lastPathComponent)"
            // Thumbnails are named "<hash>_thumb.png".  Derive the parent
            // relative path for the thumb so we keep thumbs whose originals
            // are referenced.
            let isThumb = fileURL.lastPathComponent.hasSuffix("_thumb.png")
            if isThumb {
                // Keep the thumb if its parent full-size path is referenced.
                let thumbName = fileURL.lastPathComponent
                let parentName = thumbName.replacingOccurrences(of: "_thumb.png", with: ".png")
                let parentRelative = "images/\(parentName)"
                if referencedPaths.contains(parentRelative) { continue }
            } else {
                if referencedPaths.contains(relativePath) { continue }
            }
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private helpers

    /// Encodes an NSImage as PNG data using NSBitmapImageRep.
    private func pngData(from image: NSImage) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw ImageStoreError.encodingFailed
        }
        return data
    }

    /// Returns the lowercase hex-encoded SHA-256 digest of `data`.
    private func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Creates a thumbnail of `image` with a height of at most `maxHeight`
    /// pixels, preserving the original aspect ratio.
    /// Returns `nil` if the CGContext cannot be created or the image has no
    /// valid CGImage representation.
    private func makeThumbnail(from image: NSImage, maxHeight: CGFloat) -> NSImage? {
        let originalSize = image.size
        guard originalSize.height > 0 else { return nil }
        let scale = min(maxHeight / originalSize.height, 1.0)
        let thumbSize = CGSize(
            width: (originalSize.width * scale).rounded(),
            height: (originalSize.height * scale).rounded()
        )

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(
            data: nil,
            width: Int(thumbSize.width),
            height: Int(thumbSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: thumbSize))
        guard let thumbCGImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: thumbCGImage, size: thumbSize)
    }
}

// MARK: - Errors

enum ImageStoreError: Error {
    case encodingFailed
}
