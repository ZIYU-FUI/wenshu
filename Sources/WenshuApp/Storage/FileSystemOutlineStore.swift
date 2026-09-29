// FileSystemOutlineStore.swift · WenshuApp · v2.0
//
// Per-book outline storage layer.
//
// Storage path:
//   <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//     outlines/<outline-uuid>.md   <- free-form outline body
//     outlines.json                <- index = [OutlineEntry]
//
// Book-private (= each Book has its own outlines/ folder; no
// cross-book sharing).

import Foundation

protocol OutlineStoring: Sendable {
    var bookDirectory: URL { get }

    func loadOutlines() throws -> [OutlineEntry]
    func saveOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws
    func replaceOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws
    func deleteOutline(id: UUID) throws
    func loadOutlineBody(id: UUID) -> String?
    func outlineExists(id: UUID) -> Bool
}

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

struct FileSystemOutlineStore: OutlineStoring {
    let bookDirectory: URL

    private var outlinesDirectory: URL {
        bookDirectory.appendingPathComponent("outlines", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("outlines.json")
    }

    func loadOutlines() throws -> [OutlineEntry] {
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

    func saveOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureOutlinesDirectoryExists()

        let url = entry.onDiskPath(under: bookDirectory)
        if FileManager.default.fileExists(atPath: url.path) {
            throw OutlineStoreError.outlineAlreadyExists(id: entry.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

        var current = (try? loadOutlines()) ?? []
        current.append(entry)
        try writeIndex(current)
    }

    func replaceOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureOutlinesDirectoryExists()

        let url = entry.onDiskPath(under: bookDirectory)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OutlineStoreError.outlineNotFound(id: entry.id)
        }
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

        var current = (try? loadOutlines()) ?? []
        guard let idx = current.firstIndex(where: { $0.id == entry.id }) else {
            throw OutlineStoreError.outlineNotFound(id: entry.id)
        }
        current[idx] = entry
        try writeIndex(current)
    }

    func deleteOutline(id: UUID) throws {
        let url = outlinesDirectory.appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadOutlines()) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try writeIndex(current)
        }
    }

    func loadOutlineBody(id: UUID) -> String? {
        let url = outlinesDirectory.appendingPathComponent("\(id.uuidString).md")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func outlineExists(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: outlinesDirectory.appendingPathComponent("\(id.uuidString).md").path)
    }

    private func ensureOutlinesDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: outlinesDirectory.path) {
            try FileManager.default.createDirectory(at: outlinesDirectory, withIntermediateDirectories: true)
        }
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 {
            fsync(fd)
            close(fd)
        }
    }

    private func writeIndex(_ entries: [OutlineEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try atomicWrite(data, to: indexURL)
    }
}