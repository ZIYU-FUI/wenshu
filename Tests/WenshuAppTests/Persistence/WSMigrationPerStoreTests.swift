//
//  Persistence/WSMigrationPerStoreTests.swift · Wenshu · v0.72 SwiftData migration Phase 4
//
//  Test commit 39: per-store migration logic tests.

import Foundation
import SQLite3
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSMigrationPerStore (= sqlite3 → SwiftData migration)")
struct WSMigrationPerStoreTests {

    // Helper: create a temp sqlite3 file with given rows
    static func createTestSQLite(rows: [(table: String, columns: [String], values: [[Any]])]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("wenshu-test-\(UUID().uuidString).db")
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw NSError(domain: "WSMigrationTest", code: 1)
        }
        defer { sqlite3_close(db) }

        for (table, columns, values) in rows {
            let cols = columns.joined(separator: ", ")
            let placeholders = Array(repeating: "?", count: columns.count).joined(separator: ", ")
            let createSQL = "CREATE TABLE \(table) (\(cols));"
            _ = createSQL.withCString { sqlite3_exec(db, $0, nil, nil, nil) }

            for row in values {
                let insertSQL = "INSERT INTO \(table) (\(cols)) VALUES (\(placeholders));"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
                    continue
                }
                defer { sqlite3_finalize(stmt) }
                for (i, val) in row.enumerated() {
                    let idx = Int32(i + 1)
                    if let s = val as? String {
                        sqlite3_bind_text(stmt, idx, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                    } else if let i = val as? Int {
                        sqlite3_bind_int64(stmt, idx, Int64(i))
                    } else if let d = val as? Double {
                        sqlite3_bind_double(stmt, idx, d)
                    } else if let dt = val as? Date {
                        sqlite3_bind_double(stmt, idx, dt.timeIntervalSince1970)
                    }
                }
                sqlite3_step(stmt)
            }
        }
        return url
    }

    @MainActor
    @Test("Memory migration: 3 memories → 3 WSMemory rows")
    func migrateMemory() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            (
                "memories",
                ["user_id", "memory_id", "content", "created_at", "updated_at"],
                [
                    ["u1", "m1", "hello world", Date().timeIntervalSince1970, Date().timeIntervalSince1970],
                    ["u1", "m2", "second", Date().timeIntervalSince1970, Date().timeIntervalSince1970],
                    ["u1", "m3", "third", Date().timeIntervalSince1970, Date().timeIntervalSince1970]
                ]
            )
        ])
        // Override defaultDBPath for testing
        let dest = WSMigrationPerStore.defaultDBPath(name: "memory") ?? tempDB
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempDB, to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }

        try await WSMigrationPerStore.migrateMemoryStore(context: context)
        let memories = try context.fetch(FetchDescriptor<WSMemory>())
        #expect(memories.count == 3)
        #expect(Set(memories.map { $0.content }) == Set(["hello world", "second", "third"]))
    }

    @MainActor
    @Test("Memory migration is idempotent (= runs twice → still 3 rows)")
    func migrateMemoryIdempotent() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            ("memories", ["user_id", "memory_id", "content", "created_at", "updated_at"],
             [["u1", "m1", "x", Date().timeIntervalSince1970, Date().timeIntervalSince1970]])
        ])
        try FileManager.default.moveItem(at: tempDB, to: WSMigrationPerStore.defaultDBPath(name: "memory") ?? tempDB)
        defer { try? FileManager.default.removeItem(at: WSMigrationPerStore.defaultDBPath(name: "memory") ?? tempDB) }

        try await WSMigrationPerStore.migrateMemoryStore(context: context)
        try await WSMigrationPerStore.migrateMemoryStore(context: context)
        let memories = try context.fetch(FetchDescriptor<WSMemory>())
        #expect(memories.count == 1)
    }

    @MainActor
    @Test("Todo migration: 2 todos → 2 WSTodo rows")
    func migrateTodo() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            ("todos", ["id", "title", "status", "priority", "due_date", "created_at", "updated_at"],
             [
                ["t1", "buy milk", "pending", 1, 0.0, Date().timeIntervalSince1970, Date().timeIntervalSince1970],
                ["t2", "write docs", "in_progress", 2, 0.0, Date().timeIntervalSince1970, Date().timeIntervalSince1970]
             ])
        ])
        let dest = WSMigrationPerStore.defaultDBPath(name: "todos") ?? tempDB
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempDB, to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }

        try await WSMigrationPerStore.migrateTodoStore(context: context)
        let todos = try context.fetch(FetchDescriptor<WSTodo>())
        #expect(todos.count == 2)
    }

    @MainActor
    @Test("Bookmark migration: doc_id + label → WSBookmark (= actual schema = id, doc_id, label, created_at)")
    func migrateBookmark() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            ("bookmarks", ["id", "doc_id", "label", "created_at"],
             [["bm1", "doc-1", "My anchor", Date().timeIntervalSince1970]])
        ])
        let dest = WSMigrationPerStore.defaultDBPath(name: "bookmarks") ?? tempDB
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempDB, to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }

        try await WSMigrationPerStore.migrateBookmarkStore(context: context)
        let bookmarks = try context.fetch(FetchDescriptor<WSBookmark>())
        #expect(bookmarks.count == 1)
        #expect(bookmarks[0].docID == "doc-1")
        // WSBookmark @Model has `title` field but the BookmarkStore
        // schema uses `label`; Round 5 migration maps label → title.
        #expect(bookmarks[0].title == "My anchor")
    }

    @MainActor
    @Test("Kanban migration: 1 task → WSKanbanTask")
    func migrateKanban() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            ("kanban_tasks", ["id", "title", "status", "priority", "assignee", "started_at", "completed_at", "model_override", "created_at", "updated_at"],
             [["kt1", "task x", "new", 5, NSNull(), NSNull(), NSNull(), NSNull(), Date().timeIntervalSince1970, Date().timeIntervalSince1970]])
        ])
        let dest = WSMigrationPerStore.defaultDBPath(name: "kanban") ?? tempDB
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempDB, to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }

        try await WSMigrationPerStore.migrateKanbanStore(context: context)
        let tasks = try context.fetch(FetchDescriptor<WSKanbanTask>())
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "task x")
    }

    @MainActor
    @Test("Link migration: sourceDocId + line + targetRef → WSLink with full composite id (= Phase 5 ticket 5 added targetRef)")
    func migrateLink() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        let tempDB = try Self.createTestSQLite(rows: [
            ("links", ["id", "source_doc_id", "target_ref", "target_doc_id", "line", "offset", "created_at"],
             [[1, "src", "Target", NSNull(), 5, 0, Date().timeIntervalSince1970]])
        ])
        let dest = WSMigrationPerStore.defaultDBPath(name: "links") ?? tempDB
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempDB, to: dest)
        defer { try? FileManager.default.removeItem(at: dest) }

        try await WSMigrationPerStore.migrateLinkIndex(context: context)
        let links = try context.fetch(FetchDescriptor<WSLink>())
        #expect(links.count == 1)
        // Composite id = "<sourceDocID>:<line>:<targetRef>" (= Phase 5 ticket 5
        // fix to disambiguate multiple [[name]] links on the same line).
        #expect(links[0].id == "src:5:Target")
        #expect(links[0].targetRef == "Target")
    }

    @MainActor
    @Test("Missing sqlite3 file → migration no-op (= safe)")
    func missingFile() async throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = container.mainContext
        // No file created
        try await WSMigrationPerStore.migrateMemoryStore(context: context)
        let memories = try context.fetch(FetchDescriptor<WSMemory>())
        #expect(memories.isEmpty)
    }
}
