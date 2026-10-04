// BookProjectConfigStore.swift
//
// Per-book project-level configuration JSON store. The file lives at:
//
//   <ws>/shelves/<shelf-uuid>/books/<book-uuid>/project-config.json
//
// Scope = per-book only (= no `.folder(...)` or `.referenceLibrary`
// variants). `BookProjectConfig` carries 4 user-tunable knobs:
//
//   1. autosaveCadenceSeconds  — debounce interval for auto-save
//                                (= default 60).
//   2. defaultChapterTemplate  — seed text injected on new chapter
//                                creation (= default empty string).
//   3. kanbanEnabled           — toggle the per-book kanban UI
//                                (= default true).
//   4. todoEnabled             — toggle the per-book todo UI
//                                (= default true).
//
// `updatedAt` is bumped on every save (= no external clock — the
// store sets it on write).

import Foundation

/// Per-book project-level configuration. Persisted as JSON inside
/// the book's directory (= `shelves/<shelf>/books/<book>/project-config.json`).
///
/// The fields are deliberately narrow: just the 4 knobs above.
/// New fields must have `Codable` defaults (= so older
/// `project-config.json` files on disk still decode against the
/// new struct).
struct BookProjectConfig: Codable, Sendable, Equatable {
    let bookId: UUID
    var autosaveCadenceSeconds: Int
    var defaultChapterTemplate: String
    var kanbanEnabled: Bool
    var todoEnabled: Bool
    var updatedAt: Date

    init(
        bookId: UUID,
        autosaveCadenceSeconds: Int = 60,
        defaultChapterTemplate: String = "",
        kanbanEnabled: Bool = true,
        todoEnabled: Bool = true,
        updatedAt: Date = .now
    ) {
        self.bookId = bookId
        self.autosaveCadenceSeconds = autosaveCadenceSeconds
        self.defaultChapterTemplate = defaultChapterTemplate
        self.kanbanEnabled = kanbanEnabled
        self.todoEnabled = todoEnabled
        self.updatedAt = updatedAt
    }
}

/// Per-book project-config JSON store.
///
/// Resolves `<projectRoot>/shelves/<shelf>/books/<book>/` on every
/// load / save by walking the shelves directory. The walk is
/// forgiving (= missing shelves dir, missing book folder, or
/// multiple matches = first match wins + log nothing — the
/// canonical wenshu invariant is one book in one shelf).
actor BookProjectConfigStore {
    private let projectRoot: URL
    private let fileManager: FileManager

    init(projectRoot: URL, fileManager: FileManager = .default) {
        self.projectRoot = projectRoot
        self.fileManager = fileManager
    }

    /// Load the config for a book. Returns `nil` if the file does
    /// not exist (= never saved for this book) or if the book
    /// directory cannot be resolved. Forgiving on corrupt JSON
    /// (= returns `nil` instead of throwing) so a bad file never
    /// bricks the per-book UI surface.
    func loadConfig(bookId: UUID) async throws -> BookProjectConfig? {
        guard let bookDir = resolveBookDirectory(bookId: bookId) else {
            return nil
        }
        let url = bookDir.appendingPathComponent("project-config.json")
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BookProjectConfig.self, from: data)
        } catch {
            return nil
        }
    }

    /// Save (= or upsert) the config for a book. Creates the book
    /// directory if missing (= covers the edge case where a config
    /// is written before the book's content folders exist —
    /// shouldn't happen in normal flow but is defensive against
    /// orphan book IDs). `updatedAt` is bumped to `.now` on every
    /// write regardless of what the caller passed.
    func saveConfig(_ config: BookProjectConfig) async throws {
        var stamped = config
        stamped.updatedAt = Date()
        guard let bookDir = resolveBookDirectory(bookId: stamped.bookId) else {
            throw BookProjectConfigError.bookDirectoryNotFound(bookId: stamped.bookId)
        }
        if !fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        }
        let url = bookDir.appendingPathComponent("project-config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stamped)
        try atomicWrite(data, to: url)
    }

    /// Delete the config file for a book. No-op (= success) when
    /// the file does not exist — matches the canonical
    /// `BookTodoStore`-style forgiving delete where the absence of
    /// a config is indistinguishable from a successful delete.
    func deleteConfig(bookId: UUID) async throws {
        guard let bookDir = resolveBookDirectory(bookId: bookId) else {
            return
        }
        let url = bookDir.appendingPathComponent("project-config.json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Internals

    /// Walk `shelves/<shelf>/books/<book>/` to find the book.
    /// Returns the first matching directory. Returns nil if the
    /// `shelves/` root is missing or the book is not found.
    ///
    /// Also checks the legacy `books/<book>/` path (= single-book
    /// `projectRoot` setups that pass a per-book or per-tool
    /// directory as `projectRoot`).
    private func resolveBookDirectory(bookId: UUID) -> URL? {
        // First try the canonical shelves-rooted layout.
        if let shelvesURL = resolveShelvesLayout(bookId: bookId) {
            return shelvesURL
        }
        // Fallback: `books/<bookId>/` directly under projectRoot.
        let directCandidate = projectRoot
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: directCandidate.path) {
            return directCandidate
        }
        return nil
    }

    /// Canonical shelves-rooted lookup. Walks
    /// `shelves/<shelf>/books/<book>/` and returns the first match.
    private func resolveShelvesLayout(bookId: UUID) -> URL? {
        let shelvesRoot = projectRoot.appendingPathComponent("shelves", isDirectory: true)
        guard fileManager.fileExists(atPath: shelvesRoot.path) else {
            return nil
        }
        guard let shelfDirs = try? fileManager.contentsOfDirectory(
            at: shelvesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        for shelfDir in shelfDirs {
            let booksRoot = shelfDir.appendingPathComponent("books", isDirectory: true)
            let candidate = booksRoot.appendingPathComponent(bookId.uuidString, isDirectory: true)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Atomic write (= tmp file → rename). A crash mid-save never
    /// leaves a half-written config.
    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.moveItem(at: tmpURL, to: url)
    }
}

/// Errors thrown by `BookProjectConfigStore`.
enum BookProjectConfigError: Error, LocalizedError, Sendable {
    case bookDirectoryNotFound(bookId: UUID)

    var errorDescription: String? {
        switch self {
        case .bookDirectoryNotFound(let bookId):
            return "BookProjectConfigStore: book directory not found for id \(bookId.uuidString)"
        }
    }
}