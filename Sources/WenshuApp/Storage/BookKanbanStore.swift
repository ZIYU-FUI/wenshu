// BookKanbanStore.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Per-book kanban JSON store (= spec v5 ticket 026). Replaces v0.25.x
// app-level KanbanStore (SQLite) with a per-book JSON file
// (books/<book-id>/kanban.json).
//
// Per boss 2026-08-26 OOB: '看板 ... 没有现成数据要迁移' (= kanban
//功能没实装, 没有现成数据要迁移). v0.26 starts with empty per-book
// JSON files (per LibraryBootstrapper).
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 026.

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
    let bookDirectory: URL
    var jsonURL: URL { bookDirectory.appendingPathComponent("kanban.json") }

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