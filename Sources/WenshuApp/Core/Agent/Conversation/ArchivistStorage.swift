//
//  ArchivistStorage.swift
//
//  Storage adapter for the Archivist sub-agent.
//
//  Background:
//  Archivist's domain (= bookmark CRUD + filesystem backup) does
//  NOT have an LLM-facing tool in `ToolRegistry.shared` (= the
//  bookmark / backup tools were never ported). The Archivist
//  sub-agent writes to the canonical SwiftData store via
//  `WSBookmarkRepository.shared` + filesystem directly (same
//  pattern as `DelegateResearchTool.addKanbanTask`).
//
//  This protocol isolates the storage calls so the runner can be
//  tested without a real SwiftData container (= the test passes an
//  in-memory ArchivistStorage stub).
//
//  Threading: all methods are `@MainActor` (the underlying
//  WSBookmarkRepository is `@MainActor`). Callers (= SubAgentRunner)
//  hop to MainActor before invoking.
//

import Foundation

@MainActor
protocol ArchivistStorage: Sendable {
    /// Add a bookmark (= docId + label) to the canonical store.
    func addBookmark(docID: String, label: String) async throws

    /// List all bookmarks (= newest first).
    func listBookmarks() async throws -> [ArchivistBookmark]

    /// Remove a bookmark by id.
    func removeBookmark(id: String) async throws

    /// Write a backup snapshot (= blob) to the per-book archive dir.
    /// Used by Archivist's "backup" sub-task (= copies current
    /// chapter content + meta to a dated snapshot file).
    func writeBackup(label: String, contents: String) async throws -> URL
}

/// Value-object bookmark record (= mirrors `WSBookmarkRepository.list()`
/// output but stripped of the SwiftData type to keep the protocol
/// surface framework-free for testing).
struct ArchivistBookmark: Sendable, Equatable {
    let id: String
    let docId: String
    let label: String
    let createdAt: Date
}

/// Production default implementation. Delegates to
/// `WSBookmarkRepository.shared` (= the canonical SwiftData-backed
/// bookmark store) + the per-book archive dir for backups.
@MainActor
final class LiveArchivistStorage: ArchivistStorage {
    private let bookmarkRepo: WSBookmarkRepository
    private let archiveRoot: URL

    init(
        bookmarkRepo: WSBookmarkRepository = WSBookmarkRepository(),
        archiveRoot: URL
    ) {
        self.bookmarkRepo = bookmarkRepo
        self.archiveRoot = archiveRoot
    }

    func addBookmark(docID: String, label: String) async throws {
        let bookmark = Bookmark(
            id: UUID().uuidString,
            docId: docID,
            label: label,
            createdAt: Date()
        )
        try bookmarkRepo.add(bookmark)
    }

    func listBookmarks() async throws -> [ArchivistBookmark] {
        try bookmarkRepo.list().map { bm in
            ArchivistBookmark(
                id: bm.id,
                docId: bm.docId,
                label: bm.label,
                createdAt: bm.createdAt
            )
        }
    }

    func removeBookmark(id: String) async throws {
        try bookmarkRepo.remove(id: id)
    }

    func writeBackup(label: String, contents: String) async throws -> URL {
        try FileManager.default.createDirectory(
            at: archiveRoot,
            withIntermediateDirectories: true
        )
        let stamp = Date().formatted(.iso8601)
            .replacingOccurrences(of: ":", with: "-")
        let safeLabel = label
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
            .prefix(64)
        let fileURL = archiveRoot.appendingPathComponent("\(safeLabel)-\(stamp).md")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}