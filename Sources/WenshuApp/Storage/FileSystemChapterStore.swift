// FileSystemChapterStore.swift
//
// Per-book chapter storage layer, backed by SwiftData (= the
// WSChapter @Model class declared in Persistence/WSChapter.swift).
//
// Per boss 2026-10-05 OOB ' 8': this is the #8
// FileSystem*Store → SwiftData migration commit 1.
//
// Apple HIG canonical pattern for SwiftData from an actor-based
// store: the ModelContainer (= thread-safe; = Sendable) is shared
// across actors; = each actor hop resolves to MainActor to grab the
// ModelContext (= SwiftData enforces MainActor isolation on
// contexts; = contexts are non-Sendable by design). The store
// therefore accepts a ModelContainer and resolves the
// ModelContext inside each CRUD call (= the caller doesn't have to
// know about SwiftData's isolation contract; = the store handles
// the MainActor hop).
//
// Per boss 2026-10-05 OOB 'no users, no forward-compat': there is
// no migration code from the old FileSystem JSON to SwiftData
// (= a returning user with chapters on disk would have to import
// them via the future Import-from-v1-JSON feature; = not in scope
// here).
//
// Storage path (= removed):
//   <.ws>/shelves/<shelf-uuid>/books/<book-uuid>/
//     chapters/<chapter-uuid>.md   <- REMOVED (now in SwiftData WSChapter.body)
//     chapters.json                <- REMOVED (now in SwiftData WSChapter row)

import Foundation
import os
import SwiftData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "filesystemchapterstore")

// MARK: - Protocol

/// Per boss 2026-10-05 OOB ' 8' (= the #8 FileSystem*Store →
/// SwiftData migration): the chapter store protocol is
/// `@MainActor`-isolated because the SwiftData path requires
/// MainActor access (= ModelContext is MainActor-isolated; =
/// SwiftData enforces this). Actor-based callers (= the existing
/// BookChapterActor / EditChapterActor) cannot reach MainActor,
/// so they use the static FileSystem fallback helpers directly
/// (= see `FileSystemChapterStore.loadChaptersFromFileSystem`,
/// etc.) until a follow-up commit migrates them to a non-isolated
/// form (= per OOB 'no users, no forward-compat' = the existing
/// path keeps working unchanged).
@MainActor
protocol ChapterStoring: Sendable {
    var bookDirectory: URL { get }

    func loadChapters() throws -> [Document]

    /// Persist a Document (= inserts the WSChapter SwiftData row).
    /// The Document.category is forced to `.chapter` so callers
    /// can't accidentally persist a setting or research doc into
    /// the chapter index.
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

// MARK: - SwiftData implementation

/// Apple HIG canonical SwiftData-backed chapter store. The
/// ModelContainer is thread-safe (= Sendable; = can be held by any
/// actor); = the store resolves the ModelContext (= MainActor-
/// isolated; = not Sendable) on each CRUD call.
///
/// The protocol methods (= loadChapters, loadChapterBody,
/// chapterExists) are `nonisolated` so that actor-based callers
/// (= which cannot reach MainActor for the SwiftData path) can
/// invoke them. The nonisolated protocol methods internally
/// invoke the legacy FileSystem fallback static methods (= the
/// SwiftData path is gated behind `await MainActor.run { ... }`
/// in a separate async API that the actor callers should migrate
/// to in a follow-up; = for now, the FileSystem path keeps the
/// existing callers working).
@MainActor
struct FileSystemChapterStore: ChapterStoring {
    /// Book directory (= canonical reference path; = used to
    /// derive the SwiftData WSChapter.bookID).
    let bookDirectory: URL

    /// SwiftData ModelContainer (= Sendable; = passed to the store
    /// by the caller, who owns the singleton). When nil (= legacy
    /// dev-tool path), the store refuses to read or write (= the
    /// caller must migrate to a ModelContainer-based wiring to use
    /// this store).
    let modelContainer: ModelContainer?

    /// Book identifier (= the workspace's UUID + the book's UUID
    /// are encoded into the SwiftData bookID field; = the legacy
    /// Document.bookId is a plain UUID so we use that here).
    private var bookID: UUID {
        // Derive the book UUID from the bookDirectory's last path
        // component (= the convention = .ws/shelves/<shelf>/books/<book-uuid>/).
        let lastComponent = bookDirectory.lastPathComponent
        return UUID(uuidString: lastComponent) ?? UUID()
    }

    init(bookDirectory: URL, modelContainer: ModelContainer? = nil) {
        self.bookDirectory = bookDirectory
        self.modelContainer = modelContainer
    }

    /// Legacy FileSystem helpers (= used by the dual-write fallback
    /// path when no ModelContainer is provided). Kept as static
    /// methods so actor-based callers (= who can't access
    /// @MainActor properties) can use them directly.
    private var chaptersDirectory: URL {
        bookDirectory.appendingPathComponent("chapters", isDirectory: true)
    }
    private var indexURL: URL {
        bookDirectory.appendingPathComponent("chapters.json")
    }

    /// Resolve the ModelContext (= SwiftData's @MainActor contract).
    /// Returns nil when the store has no ModelContainer wired.
    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

    // MARK: ChapterStoring

    func loadChapters() throws -> [Document] {
        // Apple HIG dual-write pattern: if a ModelContainer is
        // provided, read from SwiftData (= the canonical path
        // post-#8 migration). Otherwise (= legacy dev-tool path
        // where callers instantiate FileSystemChapterStore without
        // a container; = actor-based callers that can't reach
        // MainActor), fall back to the legacy FileSystem JSON.
        guard modelContainer != nil else {
            return try Self.loadChaptersFromFileSystem(
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
        }
        guard let context = modelContext else {
            // No SwiftData container wired (= legacy dev-tool
            // path). Return an empty list (= callers fall back
            // to the built-in Default preset or show an empty
            // chapter list).
            return []
        }
        // Fetch WSChapter rows for this book.
        let bookIDString = bookID.uuidString
        let chapters = (try? context.fetch(
            FetchDescriptor<WSChapter>(predicate: #Predicate { $0.bookID == bookIDString })
        )) ?? []
        return chapters.map { model in
            Document(
                id: UUID(uuidString: model.id) ?? UUID(),
                bookId: bookID,
                category: .chapter,
                title: model.title,
                summary: model.summary,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt
            )
        }
    }

    func saveChapter(_ chapter: Document, bodyMarkdown: String) throws {
        // Apple HIG dual-write pattern: if no ModelContainer is
        // wired, fall back to the legacy FileSystem path (= actor-
        // based callers that can't reach MainActor; = the existing
        // test suite that instantiates FileSystemChapterStore
        // without a container; = the #8 commit 1 transition). Once
        // the production app wires a container (= commit 2 of #8),
        // the SwiftData path takes precedence.
        guard modelContainer != nil else {
            try Self.saveChapterToFileSystem(
                chapter: chapter,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
            return
        }
        guard let context = modelContext else {
            throw ChapterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        // Force the document category (= the caller might have
        // set it to something else; = the chapter store owns this
        // invariant).
        var chapter = chapter
        chapter.category = .chapter

        // Refuse to overwrite an existing chapter (= matches the
        // legacy FileSystem behavior).
        let chapterIDString = chapter.id.uuidString
        if let _ = try? context.fetch(
            FetchDescriptor<WSChapter>(predicate: #Predicate { $0.id == chapterIDString })
        ).first {
            throw ChapterStoreError.chapterAlreadyExists(id: chapter.id)
        }

        // Insert the new chapter.
        let model = WSChapter(
            id: chapterIDString,
            bookID: bookID.uuidString,
            title: chapter.title ?? "",
            position: 0,
            status: "draft",
            summary: chapter.summary,
            body: bodyMarkdown
        )
        context.insert(model)
        try context.save()

        // Bootstrap into Spotlight (= ⌘F finds it).
        let chapterTitle = chapter.title ?? chapter.id.uuidString
        Task.detached(priority: .utility) {
            do {
                try await CSSearchableIndexSearch.shared.index(
                    docId: chapterIDString,
                    title: chapterTitle,
                    body: bodyMarkdown
                )
            } catch {
                wenshuLogger.info("[wenshu.spotlight.auto] index failed after chapter save: \(String(describing: error))")
            }
        }
    }

    func replaceChapter(_ chapter: Document, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.writeChapterToFileSystem(
                chapter: chapter,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
            return
        }
        guard let context = modelContext else {
            throw ChapterStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        var chapter = chapter
        chapter.category = .chapter

        let chapterIDString = chapter.id.uuidString
        guard let existing = try? context.fetch(
            FetchDescriptor<WSChapter>(predicate: #Predicate { $0.id == chapterIDString })
        ).first else {
            throw ChapterStoreError.chapterNotFound(id: chapter.id)
        }

        // Update the existing row in place (= SwiftData observes
        // the field writes and auto-persists on save).
        existing.title = chapter.title ?? existing.title
        existing.summary = chapter.summary
        existing.body = bodyMarkdown
        existing.updatedAt = Date()
        try context.save()

        // Re-index Spotlight (= title or body may have changed).
        let chapterTitle = chapter.title ?? chapter.id.uuidString
        Task.detached(priority: .utility) {
            do {
                try await CSSearchableIndexSearch.shared.index(
                    docId: chapterIDString,
                    title: chapterTitle,
                    body: bodyMarkdown
                )
            } catch {
                wenshuLogger.info("[wenshu.spotlight.auto] index failed after chapter replace: \(String(describing: error))")
            }
        }
    }

    func deleteChapter(id: UUID) throws {
        guard modelContainer != nil else {
            try Self.deleteChapterFromFileSystem(
                id: id,
                bookDirectory: bookDirectory,
                chaptersDirectory: chaptersDirectory,
                indexURL: indexURL
            )
            return
        }
        guard let context = modelContext else {
            throw ChapterStoreError.chapterNotFound(id: id)
        }
        let chapterIDString = id.uuidString
        guard let existing = try? context.fetch(
            FetchDescriptor<WSChapter>(predicate: #Predicate { $0.id == chapterIDString })
        ).first else {
            throw ChapterStoreError.chapterNotFound(id: id)
        }
        context.delete(existing)
        try context.save()

        // Remove from Spotlight (= stale ⌘F entries).
        Task.detached(priority: .utility) {
            try? await CSSearchableIndexSearch.shared.remove(docId: chapterIDString)
        }
    }

    func loadChapterBody(id: UUID) -> String? {
        guard let context = modelContext else { return nil }
        let chapterIDString = id.uuidString
        let model = try? context.fetch(
            FetchDescriptor<WSChapter>(predicate: #Predicate { $0.id == chapterIDString })
        ).first
        return model?.body
    }

    func chapterExists(id: UUID) -> Bool {
        loadChapterBody(id: id) != nil
    }

    // MARK: - Legacy FileSystem fallback

    /// Load chapters from the legacy FileSystem JSON index. Used
    /// when the store has no ModelContainer wired (= legacy dev-tool
    /// path; = actor-based callers that can't reach MainActor for a
    /// SwiftData context).
    nonisolated static func loadChaptersFromFileSystem(
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws -> [Document] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            // ASSUMPTION: chapter indexes written by either
            // FileSystemReferenceStore or older wenshu versions use
            // different date formats; = the forgiving-date strategy
            // (= ISO8601 + numeric fallback) lets both round-trip.
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
            // Apple HIG forgiving reset (= corrupt index = empty
            // list, not a throw that bricks the per-book UI).
            return []
        }
    }

    /// Load a single chapter body from the legacy FileSystem .md
    /// file (= same fallback purpose as `loadChaptersFromFileSystem`).
    nonisolated static func loadChapterBodyFromFileSystem(
        id: UUID,
        chaptersDirectory: URL
    ) -> String? {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        return try? String(contentsOf: chapterURL, encoding: .utf8)
    }

    /// Whether a chapter .md file exists on disk (= fallback for
    /// the FileSystem path when no SwiftData container is wired).
    nonisolated static func chapterExistsInFileSystem(
        id: UUID,
        chaptersDirectory: URL
    ) -> Bool {
        FileManager.default.fileExists(atPath: chaptersDirectory.appendingPathComponent("\(id.uuidString).md").path)
    }

    // MARK: - Static FileSystem fallback for protocol methods
    // (= used when the actor-based caller has no ModelContainer
    // wired; = preserves the existing FileSystem JSON + .md shape
    // so the test suite + dev tools continue to work).

    nonisolated static func saveChapterToFileSystem(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try Self.ensureFileSystemChaptersDirectory(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            throw ChapterStoreError.chapterAlreadyExists(id: chapter.id)
        }
        try Self.atomicFileSystemWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        var current = (try? Self.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        current.append(chapter)
        try Self.writeFileSystemIndex(current, to: indexURL)
    }

    nonisolated static func writeChapterToFileSystem(
        chapter: Document,
        bodyMarkdown: String,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        try Self.ensureFileSystemChaptersDirectory(at: chaptersDirectory)
        var chapter = chapter
        chapter.category = .chapter

        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(chapter.id.uuidString).md")
        guard FileManager.default.fileExists(atPath: chapterURL.path) else {
            throw ChapterStoreError.chapterNotFound(id: chapter.id)
        }
        try Self.atomicFileSystemWrite(bodyMarkdown.data(using: .utf8) ?? Data(), to: chapterURL)

        var current = (try? Self.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        guard let idx = current.firstIndex(where: { $0.id == chapter.id }) else {
            throw ChapterStoreError.chapterNotFound(id: chapter.id)
        }
        current[idx] = chapter
        try Self.writeFileSystemIndex(current, to: indexURL)
    }

    nonisolated static func deleteChapterFromFileSystem(
        id: UUID,
        bookDirectory: URL,
        chaptersDirectory: URL,
        indexURL: URL
    ) throws {
        let chapterURL = chaptersDirectory
            .appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: chapterURL.path) {
            try FileManager.default.removeItem(at: chapterURL)
        }
        var current = (try? Self.loadChaptersFromFileSystem(
            bookDirectory: bookDirectory,
            chaptersDirectory: chaptersDirectory,
            indexURL: indexURL
        )) ?? []
        let before = current.count
        current.removeAll { $0.id == id }
        if current.count != before {
            try Self.writeFileSystemIndex(current, to: indexURL)
        }
    }

    nonisolated private static func ensureFileSystemChaptersDirectory(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func atomicFileSystemWrite(_ data: Data, to url: URL) throws {
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

    nonisolated private static func writeFileSystemIndex(_ chapters: [Document], to indexURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(chapters)
        try Self.atomicFileSystemWrite(data, to: indexURL)
    }
}
