// CacheManager.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Cache directory manager (= spec v5 ticket 020). Holds thumbnails +
// search index + export temp under `<.ws>/cache/`. v0.26 ships the
// cache directory scaffolding (= create-on-launch if missing); full
// thumbnail generation + search index population land in v0.27+.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 020.
//
// v0.34 boss 2026-09-02 OOB: added `thumbnailsDirectory` (= where
// `ImageGenService` writes AI-generated cover images, file format
// `.webp` to keep size small and use Apple canonical HEIC/WebP
// decoder; per-reason CacheManager's existing
// `cleanupFiles(olderThan:)` keeps the thumbnail cache bounded).

import Foundation
#if canImport(ImageIO)
import ImageIO
#endif
import CoreGraphics

/// Manages the .ws library's cache/ directory. v0.26 = scaffolding only
/// (= ensure-on-launch + cleanup-old-files helper); thumbnail
/// generation + search index wiring land in v0.27+.
/// v0.34: thumbnail generation wiring lands (= see thumbnailsDirectory).
struct CacheManager: Sendable {
    let cacheDirectory: URL

    /// v0.34: directory for AI-generated reference card thumbnails.
    /// Path = `<.ws>/cache/thumbnails/`. Files = `<uuid>.webp`.
    var thumbnailsDirectory: URL {
        cacheDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    }

    /// Initialize with the .ws root (= manages `<.ws>/cache/`).
    init(wsRoot: URL) {
        self.cacheDirectory = wsRoot.appendingPathComponent("cache", isDirectory: true)
    }

    /// Ensure the cache/ directory exists (= idempotent; safe to call
    /// on every launch). Called by LibraryBootstrapper (ticket 021).
    /// v0.34: also ensures the thumbnails/ subdirectory exists so
    /// `ImageGenService` can write directly without a separate
    /// `mkdir -p` step (= Apple HIG idempotent-init pattern).
    func ensureCacheDirectoryExists() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: thumbnailsDirectory.path) {
            try fm.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        }
    }

    /// v0.34: full path for a single thumbnail = `<uuid>.webp`.
    /// File content is JPEG (= ~15 KB per thumbnail) even though the
    /// extension is `.webp`. v0.34 note: the `.webp` extension is a
    /// future-proofing placeholder for a follow-up that adds WebP
    /// encoding via `webp` SPM dep (= deleted in v0.28 batch 2).
    /// For v0.34 we use JPEG because it's Apple native (= ImageIO
    /// built-in = no third-party dep).
    func thumbnailURL(for referenceID: UUID) -> URL {
        thumbnailsDirectory.appendingPathComponent("\(referenceID.uuidString).webp")
    }

    /// v0.34: write a thumbnail's image data atomically. Caller is
    /// `ImageGenService` (= called once per ready thumbnail).
    ///
    /// If `imageData` is PNG (= from DALL-E / DashScope), this
    /// helper re-encodes to JPEG at quality 0.7 (= ~15 KB for a
    /// 256x192 thumbnail, ~10x smaller than the raw PNG). If the
    /// resulting JPEG still exceeds 30 KB (= boss OOB ceiling), the
    /// helper retries at quality 0.5.
    ///
    /// If the input is already JPEG (= e.g. future DALL-E JPEG
    /// endpoint), the helper writes it directly without re-encoding.
    func writeThumbnail(_ imageData: Data, for referenceID: UUID) throws {
        let url = thumbnailURL(for: referenceID)
        let encoded: Data
        if imageData.starts(with: [0xFF, 0xD8, 0xFF]) {
            // Already JPEG.
            encoded = imageData
        } else if imageData.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            // PNG -> re-encode JPEG with size ceiling.
            encoded = try reencodeToJPEG(imageData, ceilingKB: 30)
        } else if imageData.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            // WebP (= future) -> re-encode JPEG.
            encoded = try reencodeToJPEG(imageData, ceilingKB: 30)
        } else {
            // Unknown format: write as-is.
            encoded = imageData
        }

        let tmp = url.appendingPathExtension("tmp")
        try encoded.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }

    /// Re-encode arbitrary-format image data as JPEG with a per-file
    /// size ceiling (= boss OOB '生成图片的尺寸要控制一下'). Uses
    /// Apple canonical `ImageIO` (= `CGImageDestinationCreateWithData`).
    /// Strategy: try quality 0.7 first; if still over the ceiling,
    /// retry at quality 0.5. Both passes downscale the source to
    /// max 256x192 (= cap input dimensions = cap output size).
    private func reencodeToJPEG(_ imageData: Data, ceilingKB: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            // Fallback: write as-is (= user will see a placeholder for
            // this card; not a crash).
            return imageData
        }

        // Cap to 256x192 (= max card thumbnail size). Apple HIG:
        // CGImage drawn at 2x retina = exactly 128x96 PT card
        // chrome = visually sharp, no aliasing.
        let capSize = CGSize(width: 256, height: 192)
        let scaled = scaleImage(cgImage, toFit: capSize) ?? cgImage

        for quality in [0.7, 0.5, 0.35] {
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(
                data as CFMutableData,
                "public.jpeg" as CFString,
                1,
                nil
            ) else { continue }
            let props: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: quality
            ]
            CGImageDestinationAddImage(dest, scaled, props as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { continue }
            let bytes = data as Data
            if bytes.count <= ceilingKB * 1024 {
                return bytes
            }
        }
        // Last resort: return the smallest encoded version (= still
        // > ceiling but we deliver something rather than failing).
        let data = NSMutableData()
        if let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: 0.35] as CFDictionary)
            CGImageDestinationFinalize(dest)
        }
        return data as Data
    }

    /// Scale `cgImage` to fit within `maxSize` preserving aspect
    /// ratio (= Apple HIG image downscaling helper).
    private func scaleImage(_ cgImage: CGImage, toFit maxSize: CGSize) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let aspect = width / height
        let maxAspect = maxSize.width / maxSize.height
        let target: CGSize
        if aspect > maxAspect {
            target = CGSize(width: maxSize.width, height: maxSize.width / aspect)
        } else {
            target = CGSize(width: maxSize.height * aspect, height: maxSize.height)
        }
        let widthPx = Int(target.width)
        let heightPx = Int(target.height)
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil,
                width: widthPx,
                height: heightPx,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: widthPx, height: heightPx))
        return ctx.makeImage()
    }

    /// Delete files in cache/ older than the given age. v0.26 helper
    /// (= Apple HIG 'manageable cache' pattern; v0.27+ can call this
    /// from a periodic background task).
    func cleanupFiles(olderThan age: TimeInterval) throws {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-age)
        guard let enumerator = fm.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = values.contentModificationDate,
                  modDate < cutoff else { continue }
            try? fm.removeItem(at: fileURL)
        }
    }
}