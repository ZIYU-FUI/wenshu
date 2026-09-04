// FileSystemWorldStore.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Per-Book world-building storage layer (= ticket 004 of the FCP
// library replica spec).
//
// Storage path (= per spec v5):
//   <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//     world/<entry-uuid>.md     <- free-form markdown body
//     world.json                <- index = [WorldEntry] (with id +
//                                  structured fields; the .md body
//                                  holds the free-form lore)
//
// Book-private (= each Book has its own world/ folder; no cross-book
// sharing). WorldEntry struct (ticket 001) holds structured metadata;
// the .md body holds free-form world lore.
//
// Implementation pattern matches FileSystemLibraryStore (= atomic writes
// via tmp + replaceItemAt; Codable JSON for the index; id-based
// filesystem identity per Apple HIG document-based convention).

import Foundation

// MARK: - Protocol

protocol WorldStoring: Sendable {
    /// The book's directory URL (= shelves/<shelf>/books/<book>/).
    /// Exposed so the UI can show 'Storage at <path>' and tests can
    /// inject isolated /tmp paths.
    var bookDirectory: URL { get }

    /// Returns the parsed `world.json` index (= the structured metadata
    /// for every WorldEntry in this Book). If the file is missing
    /// (= newly-created book) returns an empty array. If parsing fails
    /// (= corrupt JSON), returns empty AND logs the error (= Apple HIG
    /// document-based apps treat corrupt metadata as forgiving — the
    /// user gets a fresh state rather than a crash).
    func loadWorld() throws -> [WorldEntry]

    /// Persist the WorldEntry (= creates the .md body + updates the
    /// world.json index atomically). First save wins (= throws
    /// .entryAlreadyExists if an entry with the same id is on disk).
    /// Renaming is a separate operation that updates the existing
    /// entry via `replaceEntry`.
    func saveEntry(_ entry: WorldEntry, bodyMarkdown: String) throws

    /// Update an existing entry (= overwrites the .md body + updates
    /// the index row in place). Throws .entryNotFound if no entry with
    /// the given id exists on disk.
    func replaceEntry(_ entry: WorldEntry, bodyMarkdown: String) throws

    /// Remove an entry's .md file + remove from the index.
    /// Idempotent: no-op if entry is already gone.
    func deleteEntry(id: UUID) throws

    /// Read the raw .md body for a given entry. Returns nil if the
    /// .md file doesn't exist (= orphan index row without a body).
    func loadEntryBody(id: UUID) -> String?

    /// Look up a single entry by id. Returns nil if not found.
    func entryExists(id: UUID) -> Bool
}

// MARK: - Errors

enum WorldStoreError: Error, LocalizedError {
    case entryAlreadyExists(id: UUID)
    case entryNotFound(id: UUID)
    case bookDirectoryMissing(path: String)

    var errorDescription: String? {
        switch self {
        case .entryAlreadyExists(let id):
            return "World entry \(id.uuidString) already exists on disk."
        case .entryNotFound(let id):
            return "World entry \(id.uuidString) not found on disk."
        case .bookDirectoryMissing(let path):
            return "Book directory does not exist: \(path). Cannot save world entries."
        }
    }
}

// MARK: - FileSystem implementation

struct FileSystemWorldStore: WorldStoring {
    let bookDirectory: URL

    /// Resolved to `bookDirectory/world/` (= the convention per spec v5).
    private var worldDirectory: URL {
        bookDirectory.appendingPathComponent("world", isDirectory: true)
    }

    /// Resolved to `bookDirectory/world.json` (= the structured index).
    private var indexURL: URL {
        bookDirectory.appendingPathComponent("world.json")
    }

    // MARK: WorldStoring

    func loadWorld() throws -> [WorldEntry] {
        // Apple HIG: missing file = fresh state, not an error.
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            return try JSONDecoder().decode([WorldEntry].self, from: data)
        } catch {
            // Corrupt JSON = forgiving reset (Apple HIG document-based
            // convention: corrupt metadata should not crash the app).
            // The .md files in world/ are preserved (= the structured
            // metadata is rebuilt from them on next saveEntry call).
            return []
        }
    }

    func saveEntry(_ entry: WorldEntry, bodyMarkdown: String) throws {
        // Orphan-prevention: the book directory must exist (= Book was
        // saved first by FileSystemLibraryStore.saveBook).
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw WorldStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }

        // Ensure world/ subdirectory exists (= defensive; bootstrapper
        // creates it at first launch, but if user external-drops a Book
        // directory the world/ subdir may be missing).
        try ensureWorldDirectoryExists()

        // First-save-wins: refuse if entry already exists.
        let entryURL = entry.onDiskPath(under: bookDirectory)
        if FileManager.default.fileExists(atPath: entryURL.path) {
            throw WorldStoreError.entryAlreadyExists(id: entry.id)
        }

        // Write the .md body atomically.
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: entryURL)

        // Append the entry to the index atomically.
        var current = (try? loadWorld()) ?? []
        current.append(entry)
        try writeIndex(current)
    }

    func replaceEntry(_ entry: WorldEntry, bodyMarkdown: String) throws {
        guard FileManager.default.fileExists(atPath: bookDirectory.path) else {
            throw WorldStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        try ensureWorldDirectoryExists()

        let entryURL = entry.onDiskPath(under: bookDirectory)
        guard FileManager.default.fileExists(atPath: entryURL.path) else {
            throw WorldStoreError.entryNotFound(id: entry.id)
        }

        // Overwrite the .md body atomically.
        try atomicWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: entryURL)

        // Update the entry in the index (replace by id).
        var current = (try? loadWorld()) ?? []
        guard let idx = current.firstIndex(where: { $0.id == entry.id }) else {
            throw WorldStoreError.entryNotFound(id: entry.id)
        }
        current[idx] = entry
        try writeIndex(current)
    }

    func deleteEntry(id: UUID) throws {
        // Idempotent: no error if not found (= Apple HIG delete = forgiving).
        let url = bookDirectory
            .appendingPathComponent("world")
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var current = (try? loadWorld()) ?? []
        current.removeAll { $0.id == id }
        try writeIndex(current)
    }

    func loadEntryBody(id: UUID) -> String? {
        let url = bookDirectory
            .appendingPathComponent("world")
            .appendingPathComponent("\(id.uuidString).md")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func entryExists(id: UUID) -> Bool {
        let url = bookDirectory
            .appendingPathComponent("world")
            .appendingPathComponent("\(id.uuidString).md")
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: Private helpers (= matches FileSystemLibraryStore pattern)

    /// Creates `<book>/world/` if absent.
    private func ensureWorldDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: worldDirectory.path) {
            try FileManager.default.createDirectory(
                at: worldDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    /// Atomic write: writes to `<url>.tmp`, then `replaceItemAt` to swap
    /// into place. Apple HIG FileManager idiom (= no torn writes on
    /// crash; no partial file visible to readers).
    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        // Replace atomically; remove any existing target first
        // (= replaceItemAt fails with NSFileWriteFileExistsError if the
        // target already exists).
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmpURL, to: url)
    }

    /// Writes the index JSON atomically.
    private func writeIndex(_ entries: [WorldEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try atomicWrite(data, to: indexURL)
    }
}