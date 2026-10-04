// BookTodoStore.swift
//
// Per-(book × scope) todo JSON store. Each scope variant writes to a
// different JSON file in the resolved directory:
//
//   - .book             → <dir>/todo.json
//   - .folder(.chapters)→ <dir>/todo-chapters.json
//   - .folder(<other>)  → <dir>/todo-<folder>.json
//   - .referenceLibrary → <dir>/library-todo.json
//
// 8 standard sub-folders per book: chapters, world, characters, outlines,
// drafts, sessions, foreshadowing, placeholders. The scope is a view filter,
// not a data-layer change.

import Foundation

/// Per-book JSON-serialized todo item. Codable counterpart to
/// `WenshuApp.Core.Todo.TodoItem` (= the latter is Equatable + Sendable
/// but not Codable, so it can't round-trip JSON per-book).
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

    // backward-compat init. Defaults `scope = .book` and `directory = bookDirectory`.
    init(bookId: UUID, bookDirectory: URL) {
        self.bookId = bookId
        self.directory = bookDirectory
        self.scope = .book
    }

    /// scope-aware init.
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
