// Sources/WenshuApp/Editor/ReferenceLibraryImageProvider.swift
//
// v0.39 ticket 001 -- EmbeddedImageProvider conformance that resolves
// Obsidian-style ![[name]] embeds by searching the active book's
// characters/ + worlds/ folders first, then the library's reference-
// library/raw/ as fallback. Engine calls synchronously from the
// image-embed render path.
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   protocol EmbeddedImageProvider: Sendable {
//     func image(for reference: EmbeddedImageRequest) -> NSImage?
//     func fingerprint() -> AnyHashable
//   }
//   struct EmbeddedImageRequest: Sendable, Equatable {
//     let name: String                   // = part before any |
//     let id: String?                    // = optional explicit id
//     let requestedWidth: CGFloat?       // = optional explicit width
//   }
// The engine parses `![[name|optional-id|optional-width]]` into an
// EmbeddedImageRequest and asks the provider for an image.

import AppKit
import CryptoKit
import MarkdownEngine

struct ReferenceLibraryImageProvider: EmbeddedImageProvider {
    let activeBookRoot: URL           // = shelves/<shelf>/books/<book>/
    let referenceLibraryRoot: URL     // = library's reference-library/

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        // Search order: characters/, worlds/, reference-library/raw/.
        // If explicit id is provided, match by id (= entity UUID stored
        // in entity metadata). Otherwise match by file basename.
        let candidates: [URL] = [
            activeBookRoot.appendingPathComponent("characters"),
            activeBookRoot.appendingPathComponent("worlds"),
            referenceLibraryRoot.appendingPathComponent("raw"),
        ]
        let trimmed = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)

        for dir in candidates {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }
            for entry in entries {
                let baseName = entry.deletingPathExtension().lastPathComponent
                let matchByName = baseName.caseInsensitiveCompare(trimmed) == .orderedSame
                let matchById: Bool = {
                    guard let id = reference.id else { return false }
                    return baseName.caseInsensitiveCompare(id) == .orderedSame
                }()
                if matchByName || matchById {
                    return NSImage(contentsOf: entry)
                }
            }
        }
        return nil
    }

    func fingerprint() -> AnyHashable {
        // Hash of all image file mtimes + paths. Engine invalidates its
        // image cache when this changes (= new image added, or existing
        // one edited).
        let candidates: [URL] = [
            activeBookRoot.appendingPathComponent("characters"),
            activeBookRoot.appendingPathComponent("worlds"),
            referenceLibraryRoot.appendingPathComponent("raw"),
        ]
        var hasher = SHA256()
        for dir in candidates {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                hasher.update(data: Data(entry.lastPathComponent.utf8))
                if let mtime = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate {
                    hasher.update(data: Data(String(mtime.timeIntervalSince1970).utf8))
                }
            }
        }
        return Data(hasher.finalize())
    }
}
