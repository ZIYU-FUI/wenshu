// BookKanbanStore.swift · WenshuApp · v1.85
//
// Per-(book × scope) kanban JSON store. Each scope variant writes to a
// different JSON file in the resolved directory:
//
//   - .book             → <dir>/kanban.json
//   - .folder(.chapters)→ <dir>/kanban-chapters.json
//   - .folder(<other>)  → <dir>/kanban-<folder>.json
//   - .referenceLibrary → <dir>/library-kanban.json
//
// 8 standard sub-folders per book: chapters, world, characters, outlines,
// drafts, sessions, foreshadowing, placeholders. The scope is a view filter,
// not a data-layer change.

import Foundation

protocol BookDataStoring: Sendable {
    associatedtype Element: Codable
    var bookId: UUID { get }
    var jsonURL: URL { get }
    func load() throws -> [Element]
    func save(_ data: [Element]) throws
}

// MARK: - Kanban ticket

struct KanbanTicket: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var status: KanbanStatus
    var createdAt: Date
    var updatedAt: Date
    /// Agent-written markdown body. Mirrors the SwiftData `KanbanTask.body`
    /// field; this struct is the JSON-file shape that `KanbanCard` renders.
    var body: String?

    init(
        id: UUID = UUID(),
        title: String,
        status: KanbanStatus = .new,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        body: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.body = body
    }
}

// KanbanStatus enum: see WenshuApp.Core.Kanban.KanbanStatus.

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

    // backward-compat init. Defaults `scope = .book` and `directory = bookDirectory`
    // (= unchanged semantics for the book-root case).
    init(bookId: UUID, bookDirectory: URL) {
        self.bookId = bookId
        self.directory = bookDirectory
        self.scope = .book
    }

    /// scope-aware init. `directory` is whatever `BookStore.scopeDirectory`
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
