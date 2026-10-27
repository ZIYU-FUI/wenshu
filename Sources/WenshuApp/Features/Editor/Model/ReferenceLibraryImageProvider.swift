// Sources/WenshuApp/Features/Editor/Model/ReferenceLibraryImageProvider.swift
//
// EmbeddedImageProvider conformance that resolves Obsidian-style
// ![[name]] embeds by searching the active book's characters/ + world/
// folders first, then the library's reference-library/raw/ as fallback.
// Engine calls synchronously from the image-embed render path.
//
// Real API (verified from swift-markdown-engine 0.12.0 source):
//   protocol EmbeddedImageProvider: Sendable {
//     func image(for reference: EmbeddedImageRequest) -> NSImage?
//     func fingerprint() -> AnyHashable
//   }
//   struct EmbeddedImageRequest: Sendable, Equatable {
//     let name: String                   // part before any |
//     let id: String?                    // optional explicit id
//     let requestedWidth: CGFloat?       // optional explicit width
//   }
// The engine parses `![[name|optional-id|optional-width]]` into an
// EmbeddedImageRequest and asks the provider for an image.

import AppKit
import CryptoKit
import MarkdownEngine

struct ReferenceLibraryImageProvider: EmbeddedImageProvider {
    let activeBookRoot: URL           // = shelves/<shelf>/books/<book>/
    let referenceLibraryRoot: URL     // = library's reference-library/

    /// The folders the provider searches, in order: the active book's
    /// `characters/` folder, the active book's `world/` folder, then the
    /// library's `reference-library/raw/` layer. One list, so the image
    /// lookup and the fingerprint can never cover different folders (= a
    /// fingerprint over a different folder set never invalidates the
    /// engine's image cache).
    private var searchFolders: [URL] {
        [
            activeBookRoot.appendingPathComponent("characters"),
            // The book's world folder takes its on-disk name from the
            // folder catalogue (= the SSOT for the book folder names); a
            // name spelled out here is what made world-folder pictures
            // invisible to the editor.
            activeBookRoot.appendingPathComponent(BookFolderCatalog.world.directoryName),
            referenceLibraryRoot.appendingPathComponent("raw"),
        ]
    }

    func image(for reference: EmbeddedImageRequest) -> NSImage? {
        // Search order: characters/, world/, reference-library/raw/.
        // If explicit id is provided, match by id (= entity UUID stored
        // in entity metadata). Otherwise match by file basename.
        let trimmed = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)

        for dir in searchFolders {
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
        let candidates = searchFolders
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
