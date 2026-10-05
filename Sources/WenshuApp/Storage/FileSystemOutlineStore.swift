//
//  FileSystemOutlineStore.swift
//
//  Per-book outline storage layer, backed by SwiftData (= the
//  WSOutlineEntry @Model class in Persistence/) with a FileSystem
//  fallback for actor callers.
//
//  Per boss 2026-10-05 OOB ' 8' (= complete the FileSystem*Store →
//  SwiftData migration). This is commit 4 of #8.
//
//  Apple HIG canonical pattern: WSOutlineEntry holds the indexed
//  metadata (= id, bookID, title, summary, parent, order,
//  createdAt, updatedAt) in one row. The body markdown stays on
//  the filesystem at <bookDir>/outlines/<uuid>.md (= too large +
//  filesystem is the canonical source for body content; matches
//  WSOutlineDocument's split-index pattern).
//
//  Storage paths (= unchanged at the public API level):
//    <.ws>/shelves/<shelf>/books/<UUID>/outlines/<UUID>.md
//    <.ws>/shelves/<shelf>/books/<UUID>/outlines.json
//
//  Apple HIG dual-write pattern: when no ModelContainer is wired
//  (= legacy dev-tool path), fall back to the legacy FileSystem
//  path (= per-outline .md body + outlines.json index).

import Foundation
import SwiftData

// MARK: - Protocol

@MainActor
protocol OutlineStoring: Sendable {
    var bookDirectory: URL { get }

    func loadOutlines() throws -> [OutlineEntry]
    func saveOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws
    func replaceOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws
    func deleteOutline(id: UUID) throws
    func loadOutlineBody(id: UUID) -> String?
    func outlineExists(id: UUID) -> Bool
}

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

// MARK: - SwiftData implementation

@MainActor
struct FileSystemOutlineStore: OutlineStoring {
    let bookDirectory: URL

    let modelContainer: ModelContainer?

    private var outlinesDirectory: URL {
        bookDirectory.appendingPathComponent("outlines", isDirectory: true)
    }

    private var indexURL: URL {
        bookDirectory.appendingPathComponent("outlines.json")
    }

    init(
        bookDirectory: URL,
        modelContainer: ModelContainer? = nil
    ) {
        self.bookDirectory = bookDirectory
        self.modelContainer = modelContainer
    }

    private var modelContext: ModelContext? {
        modelContainer?.mainContext
    }

    // MARK: OutlineStoring

    func loadOutlines() throws -> [OutlineEntry] {
        guard modelContainer != nil else {
            return try Self.loadOutlinesFromFileSystem(bookDirectory: bookDirectory)
        }
        guard let context = modelContext else { return [] }
        // Fetch all outlines for this book (= SwiftData FK on bookID).
        let bookID = bookDirectory.lastPathComponent
        guard let bookUUID = UUID(uuidString: bookID) else { return [] }
        let descriptor = FetchDescriptor<WSOutlineEntry>(
            predicate: #Predicate { $0.bookID == bookUUID }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.map(Self.toEntry)
    }

    func saveOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.saveOutlineToFileSystem(
                entry: entry,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let id = entry.id
        let descriptor = FetchDescriptor<WSOutlineEntry>(
            predicate: #Predicate { $0.id == id }
        )
        if let _ = try? context.fetch(descriptor).first {
            throw OutlineStoreError.outlineAlreadyExists(id: entry.id)
        }
        let row = Self.makeRow(entry: entry)
        context.insert(row)
        try context.save()
        // Write the body file too (= filesystem is the canonical
        // source for body content per the WSOutlineDocument split-
        // index pattern).
        try Self.writeBodyFile(bodyMarkdown: bodyMarkdown, entry: entry, bookDirectory: bookDirectory)
    }

    func replaceOutline(_ entry: OutlineEntry, bodyMarkdown: String) throws {
        guard modelContainer != nil else {
            try Self.replaceOutlineToFileSystem(
                entry: entry,
                bodyMarkdown: bodyMarkdown,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            throw OutlineStoreError.bookDirectoryMissing(path: bookDirectory.path)
        }
        let id = entry.id
        let descriptor = FetchDescriptor<WSOutlineEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            throw OutlineStoreError.outlineNotFound(id: entry.id)
        }
        existing.title = entry.title
        existing.summary = entry.summary
        existing.parent = entry.parent
        existing.order_ = entry.order
        existing.updatedAt = Date()
        try context.save()
        try Self.writeBodyFile(bodyMarkdown: bodyMarkdown, entry: entry, bookDirectory: bookDirectory)
    }

    func deleteOutline(id: UUID) throws {
        guard modelContainer != nil else {
            try Self.deleteOutlineFromFileSystem(
                id: id,
                bookDirectory: bookDirectory
            )
            return
        }
        guard let context = modelContext else {
            throw OutlineStoreError.outlineNotFound(id: id)
        }
        let descriptor = FetchDescriptor<WSOutlineEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let existing = try? context.fetch(descriptor).first else {
            return  // Idempotent.
        }
        context.delete(existing)
        try context.save()
        // Delete the body file too.
        let url = outlinesDirectory.appendingPathComponent("\(id.uuidString).md")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func loadOutlineBody(id: UUID) -> String? {
        guard modelContainer != nil else {
            return Self.loadOutlineBodyFromFileSystem(
                id: id,
                bookDirectory: bookDirectory
            )
        }
        // Body lives on disk (= filesystem is canonical for body
        // content); = read directly even on the SwiftData path.
        return Self.loadOutlineBodyFromFileSystem(
            id: id,
            bookDirectory: bookDirectory
        )
    }

    func outlineExists(id: UUID) -> Bool {
        guard modelContainer != nil else {
            return FileManager.default.fileExists(
                atPath: outlinesDirectory.appendingPathComponent("\(id.uuidString).md").path
            )
        }
        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<WSOutlineEntry>(
            predicate: #Predicate { $0.id == id }
        )
        return ((try? context.fetch(descriptor).first) != nil)
    }

    // MARK: - SwiftData bridging helpers

    private static func makeRow(entry: OutlineEntry) -> WSOutlineEntry {
        WSOutlineEntry(
            id: entry.id,
            bookID: entry.bookId,
            title: entry.title,
            summary: entry.summary,
            parent: entry.parent,
            order: entry.order,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    private static func toEntry(_ row: WSOutlineEntry) -> OutlineEntry {
        OutlineEntry(
            id: row.id,
            bookId: row.bookID,
            title: row.title,
            summary: row.summary,
            parent: row.parent,
            order: row.order_,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    // MARK: - FileSystem fallback (actor-safe; = nonisolated statics)

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
        try atomicWriteFileSystem(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

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
        try atomicWriteFileSystem(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)

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

    nonisolated private static func writeBodyFile(
        bodyMarkdown: String,
        entry: OutlineEntry,
        bookDirectory: URL
    ) throws {
        let outlinesDir = bookDirectory.appendingPathComponent("outlines", isDirectory: true)
        try ensureOutlinesDirectoryExists(at: outlinesDir)
        let url = entry.onDiskPath(under: bookDirectory)
        try atomicWriteFileSystem(bodyMarkdown.data(using: .utf8) ?? Data(), to: url)
    }

    nonisolated private static func writeIndexToFileSystem(
        _ entries: [OutlineEntry],
        bookDirectory: URL
    ) throws {
        let indexURL = bookDirectory.appendingPathComponent("outlines.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try atomicWriteFileSystem(data, to: indexURL)
    }

    nonisolated private static func ensureOutlinesDirectoryExists(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    nonisolated private static func atomicWriteFileSystem(_ data: Data, to url: URL) throws {
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
}