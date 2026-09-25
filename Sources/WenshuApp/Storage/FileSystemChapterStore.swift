//
//  FileSystemChapterStore.swift · Wenshu · v2.0 (2026-09-25)
//
//  Per-Book chapter storage layer.
//
//  Storage path (= per spec v5):
//    <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//      chapters/<chapter-uuid>.md   <- free-form chapter body
//      chapters.json                <- index = [Document]
//
//  Book-private (= each Book has its own chapters/ folder; no cross-
//  book sharing). Uses the existing `Document` domain struct (= the
//  canonical metadata shape that powers the chapter card UI) with
//  `category = .chapter`. Reuses the existing FileSystemLibraryStore
//  where possible; this store is a thin dedicated entry point that
//  mirrors World/Character's storage shape (1 .md + 1 index.json).
//
//  Implementation pattern matches FileSystemWorldStore (ticket 004)
//  and FileSystemCharacterStore (ticket 005) — atomic writes via
//  tmp + replaceItemAt, Codable JSON for the index, id-based
//  filesystem identity per Apple HIG document-based convention.
//

import Foundation

// MARK: - Protocol

protocol ChapterStoring: Sendable {
    var bookDirectory: URL { get }

    func loadChapters() throws -> [Document]

    /// Persist a Document (= creates the .md body + appends to the
    /// chapters.json index). The Document.category is forced to
    /// `.chapter` so callers can't accidentally persist a setting or
    /// research doc into the chapter index.
    func saveChapter(_ chapter: Document, bodyMarkdown: String) throws

    func replaceChapter(_ chapter: Document, bodyMarkdown: String) throws

    func deleteChapter(id: UUID) throws

    func loadChapterBody(id: UUID) -> String?

    func chapterExists(id: UUID) -> Bool
}

// MARK: - Errors

enum ChapterStoreError: Error, LocalizedError {
    case chapterAlreadyExists(id: UUID)
    case chapterNotFound(id: UUID)
    case bookDirectoryMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .chapterAlreadyExists(let id):
            return "Chapter \(id.uuidString) already exists on disk."
        case .chapterNotFound(let id):
            return "Chapter \(id.uuidString) not found on disk."
        case .bookDirectoryMissing(let path):
            return "Book directory does not exist: \(path). Cannot save chapters."
        }
    }
}

// MARK: - FileSystem implementation

struct FileSystemChapterStore: ChapterStoring {
    let bookDirectory: URL

    private var chaptersDirectory: URL {
        bookDirectory.appendingPathComponent("chapters", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("chapters.json")
    }

    // MARK: ChapterStoring

    func loadChapters() throws -> [Document] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            // Match the FileSystemReferenceStore forgiving-date
            // strategy so chapter indexes written by either style
            // round-trip cleanly.
            decoder.dateDecodingStrategy = .custom { dec in
                let container = try dec.singleValueContainer()
                if let double = try? container.decode(Double.self) {
                    return Date(timeIntervalSince1970: double)
                }
                let raw = try container.decode(String.self)
                let isoStyleWithFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
                let isoStyleNoFrac = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
                if let d = try? Date(raw, strategy: isoStyleWithFrac) { return d }
                if let d = try? Date(raw, strategy: isoStyleNoFrac) { return d }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Date string '\(raw)' is neither ISO8601 nor numeric"
                )
            }
            return try decoder.decode([Document].self, from: data)
        } catch {
            // Apple HIG forgiving reset.
            return []
        }
    }

    func saveChapter(_ chapter: Document, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw ChapterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureChaptersDirectoryExists()

        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chapter.onDiskPath(under: bookDirectory)
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw ChapterStoreError.chapterAlreadyExists(id: chapter.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        var current = (try? loadChapters()) ?? []
        current.append(chapter)
        try writeIndex(current)
    }

    func replaceChapter(_ chapter: Document, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw ChapterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureChaptersDirectoryExists()

        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chapter.onDiskPath(under: bookDirectory)
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw ChapterStoreError.chapterNotFound(id: chapter.id)
        }

        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        var current = (try? loadChapters()) ?? []
        guard let idx = current.firstIndex(where: { $0.id == chapter.id }) else {
            throw ChapterStoreError.chapterNotFound(id: chapter.id)
        }
        current[idx] = chapter
        try writeIndex(current)
    }

    func deleteChapter(id: UUID) throws {
        // Find the .md file matching the UUID; remove it; then drop
        // the index row. Mirrors FileSystemWorldStore.deleteEntry.
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }
        var current = (try? loadChapters()) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try writeIndex(current)
        }
    }

    func loadChapterBody(id: UUID) -> String? {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        return try? String(contentsOf: chapterURL, encoding: .utf8)
    }

    func chapterExists(id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: chaptersDirectory.appendingPathComponent("\(id.uuidString).md").path)
    }

    // MARK: Private helpers

    private func ensureChaptersDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: chaptersDirectory.path) {
            try FileManager.default.createDirectory(at: chaptersDirectory, withIntermediateDirectories: true)
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

    private func writeIndex(_ chapters: [Document]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chapters)
        try atomicWrite(data, to: indexURL)
    }
}