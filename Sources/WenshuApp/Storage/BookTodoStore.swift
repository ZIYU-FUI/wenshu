// BookTodoStore.swift · Wenshu (文枢) · v0.26 (FCP library replica) + B-13
//
// Per-(book × scope) todo JSON store (= spec v5 ticket 026 + B-13 scope
// unification). Replaces v0.25.x app-level TodoStore (SQLite) with a
// per-book JSON file (books/<book-id>/todo.json).
//
// Per boss 2026-08-26 OOB: 'todo ... 没有现成数据要迁移' (= todo
//功能没实装, 没有现成数据要迁移). v0.26 starts with empty per-book
// JSON files (per LibraryBootstrapper).
//
// B-13 (= boss 2026-09-04 OOB): scope picker lets the user target one of
// 8 standard sub-folders inside the active book, the book root, or the
// reference library. The scope is a view filter, not a data-layer
// change: each scope variant writes to a different JSON file in the
// resolved directory:
//
//   - .book             → <dir>/todo.json
//   - .folder(.chapters)→ <dir>/todo-chapters.json
//   - ... (other folders)
//   - .referenceLibrary → <dir>/library-todo.json
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 026.
// B-13 spec at `.scratch/2026-09-04-b-13-scope-unification.md`.

import Foundation

/// Per-book JSON-serialized TodoItem (= distinct from v0.25.x
/// WenshuApp.Core.Todo.TodoItem which is Equatable + Sendable but
/// not Codable). Used by BookTodoStore for per-book JSON
/// serialization per boss 2026-08-26 OOB '切书=切数据源'.
struct PerBookTodoItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var status: TodoStatus
    var priority: TodoPriority
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        status: TodoStatus = .pending,
        priority: TodoPriority = .medium,
        dueDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct BookTodoStore: BookDataStoring {
    typealias Element = PerBookTodoItem
    let bookId: UUID

    /// The directory this store reads / writes inside. See
    /// `BookKanbanStore.directory` for the same convention.
    let directory: URL

    /// Which scope variant this store targets. Drives the JSON file
    /// name (= `todo.json` / `todo-<folder>.json` / `library-todo.json`).
    let scope: TaskScope

    // B-13 backward-compat init (= see BookKanbanStore for rationale).
    init(bookId: UUID, bookDirectory: URL) {
        self.bookId = bookId
        self.directory = bookDirectory
        self.scope = .book
    }

    /// B-13 scope-aware init (= canonical entry point).
    init(bookId: UUID, directory: URL, scope: TaskScope) {
        self.bookId = bookId
        self.directory = directory
        self.scope = scope
    }

    var jsonURL: URL {
        switch scope {
        case .book:
            return directory.appendingPathComponent("todo.json")
        case .folder(let folder):
            return directory.appendingPathComponent("todo-\(folder.folderName).json")
        case .referenceLibrary:
            return directory.appendingPathComponent("library-todo.json")
        }
    }

    func load() throws -> [PerBookTodoItem] {
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: jsonURL)
            return try JSONDecoder().decode([PerBookTodoItem].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ data: [PerBookTodoItem]) throws {
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
