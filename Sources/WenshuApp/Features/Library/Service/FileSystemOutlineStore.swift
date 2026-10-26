// FileSystemOutlineStore.swift Per-book outline storage layer, backed by the
// filesystem. The outline body markdown lives on disk at
// <bookDir>/outlines/<uuid>.md and the outline index at
// <bookDir>/outlines.json; both are the canonical source. Storage paths
// (= unchanged at the public API level):
// <.ws>/shelves/<shelf>/books/<UUID>/outlines/<UUID>.md
// <.ws>/shelves/<shelf>/books/<UUID>/outlines.json
//
// A namespace (= no stored state): every operation names its book
// directory, so the type carries no instance state and no container.

import Foundation

// MARK: - Errors

enum OutlineStoreError: Error, LocalizedError {
    case outlineAlreadyExists(id: UUID)
    case outlineNotFound(id: UUID)
    case bookDirectoryMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .outlineAlreadyExists(let id):
            return "Outline entry \(id.uuidString) already exists on disk."
        case .outlineNotFound(let id):
            return "Outline entry \(id.uuidString) not found on disk."
        case .bookDirectoryMissing(let path):
            return "Book directory does not exist: \(path). Cannot save outlines."
        }
    }
}

// MARK: - FileSystem implementation

enum FileSystemOutlineStore {

    nonisolated static func loadOutlinesFromFileSystem(
        bookDirectory: URL
    ) throws -> [OutlineEntry] {
        let indexURL = bookDirectory.appendingPathComponent("outlines.json")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode([OutlineEntry].self, from: data)
        } catch {
            return []
        }
    }

    nonisolated static func loadOutlineBodyFromFileSystem(
        id: UUID,
        bookDirectory: URL
    ) -> String? {
        let url = bookDirectory
            .appendingPathComponent("outlines", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    nonisolated static func saveOutlineToFileSystem(
        entry: OutlineEntry,
        bodyMarkdown: String,
        bookDirectory: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let outlinesDir = bookDirectory.appendingPathComponent("outlines", isDirectory: true)
        try ensureOutlinesDirectoryExists(at: outlinesDir)

        let url = entry.onDiskPath(under: bookDirectory)
        if FileManager.default.fileExists(atPath: url.path) {
            throw OutlineStoreError.outlineAlreadyExists(id: entry.id)
        }
        try AtomicFileWrite.write(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

        var current = (try? loadOutlinesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        current.append(entry)
        try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
    }

    nonisolated static func replaceOutlineToFileSystem(
        entry: OutlineEntry,
        bodyMarkdown: String,
        bookDirectory: URL
    ) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let outlinesDir = bookDirectory.appendingPathComponent("outlines", isDirectory: true)
        try ensureOutlinesDirectoryExists(at: outlinesDir)

        let url = entry.onDiskPath(under: bookDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OutlineStoreError.outlineNotFound(id: entry.id)
        }
        try AtomicFileWrite.write(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

        var current = (try? loadOutlinesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        guard let idx = current.firstIndex(where: { $0.id == entry.id }) else {
            throw OutlineStoreError.outlineNotFound(id: entry.id)
        }
        current[idx] = entry
        try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
    }

    nonisolated static func deleteOutlineFromFileSystem(
        id: UUID,
        bookDirectory: URL
    ) throws {
        let url = bookDirectory
            .appendingPathComponent("outlines", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadOutlinesFromFileSystem(bookDirectory: bookDirectory)) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try writeIndexToFileSystem(current, bookDirectory: bookDirectory)
        }
    }

    nonisolated private static func writeIndexToFileSystem(
        _ entries: [OutlineEntry],
        bookDirectory: URL
    ) throws {
        let indexURL = bookDirectory.appendingPathComponent("outlines.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try AtomicFileWrite.write(data, to: indexURL)
    }

    nonisolated private static func ensureOutlinesDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
