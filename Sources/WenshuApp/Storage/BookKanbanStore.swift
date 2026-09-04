// BookKanbanStore.swift · Wenshu (文枢) · v0.26 (FCP library replica) + B-13
//
// Per-(book × scope) kanban JSON store (= spec v5 ticket 026 + B-13 scope
// unification). Replaces v0.25.x app-level KanbanStore (SQLite) with a
// per-book JSON file (books/<book-id>/kanban.json).
//
// Per boss 2026-08-26 OOB: '看板 ... 没有现成数据要迁移' (= kanban
//功能没实装, 没有现成数据要迁移). v0.26 starts with empty per-book
// JSON files (per LibraryBootstrapper).
//
// B-13 (= boss 2026-09-04 OOB): scope picker lets the user target one of
// 8 standard sub-folders inside the active book (= `chapters/`,
// `world/`, ...), the book root, or the reference library. The scope is
// a view filter, not a data-layer change: each scope variant writes to a
// different JSON file in the resolved directory:
//
//   - .book             → <dir>/kanban.json
//   - .folder(.chapters)→ <dir>/kanban-chapters.json
//   - ... (other folders)
//   - .referenceLibrary → <dir>/library-kanban.json
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 026.
// B-13 spec at `.scratch/2026-09-04-b-13-scope-unification.md`.

import Foundation

protocol BookDataStoring: Sendable {
    associatedtype Element: Codable
    var bookId: UUID { get }
    var jsonURL: URL { get }
    func load() throws -> [Element]
    func save(_ data: [Element]) throws
}

// MARK: - Kanban ticket (= reuses v0.25.x KanbanTicket shape)

struct KanbanTicket: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var status: KanbanStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        status: KanbanStatus = .new,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// KanbanStatus enum: see WenshuApp.Core.Kanban.KanbanStatus (v0.25.x, 7 cases: new / triage / ready / running / blocked / review / done / failed)

// MARK: - BookKanbanStore

struct BookKanbanStore: BookDataStoring {
    typealias Element = KanbanTicket
    let bookId: UUID

    /// The directory this store reads / writes inside. For `.book` /
    /// `.folder(...)` scopes this is the book root or a standard
    /// sub-folder inside it. For `.referenceLibrary` this is the
    /// library-public archive root (= `reference-library/`).
    let directory: URL

    /// Which scope variant this store targets. Drives the JSON file
    /// name (= `kanban.json` / `kanban-<folder>.json` / `library-kanban.json`).
    let scope: TaskScope

    // B-13 backward-compat init: pre-B-13 callers (= existing tests +
    // KanbanView in the middle of a code review) used `init(bookId:
    // bookDirectory:)`. Preserved as a thin wrapper that defaults
    // `scope = .book` and `directory = bookDirectory` (= unchanged
    // semantics for the book-root case).
    init(bookId: UUID, bookDirectory: URL) {
        self.bookId = bookId
        self.directory = bookDirectory
        self.scope = .book
    }

    /// B-13 scope-aware init (= the canonical entry point after the
    /// unification). `directory` is whatever `BookStore.scopeDirectory`
    /// returns for the active `(bookId, scope)` pair.
    init(bookId: UUID, directory: URL, scope: TaskScope) {
        self.bookId = bookId
        self.directory = directory
        self.scope = scope
    }

    var jsonURL: URL {
        switch scope {
        case .book:
            return directory.appendingPathComponent("kanban.json")
        case .folder(let folder):
            return directory.appendingPathComponent("kanban-\(folder.folderName).json")
        case .referenceLibrary:
            return directory.appendingPathComponent("library-kanban.json")
        }
    }

    func load() throws -> [KanbanTicket] {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: jsonURL)
            return try JSONDecoder().decode([KanbanTicket].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ data: [KanbanTicket]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(data)
        try atomicWrite(bytes)
    }

    private func atomicWrite(_ data: Data) throws {
        let tmpURL = jsonURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            try FileManager.default.removeItem(at: jsonURL)
        }
        try FileManager.default.moveItem(at: tmpURL, to: jsonURL)
    }
}
