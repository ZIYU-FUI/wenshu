//
//  BookTodoStoreTests.swift · Wenshu (文枢) · B-09 (kanban + todo UI functional linkage)
//
//  Round-trip persistence tests for the per-book Todo JSON store
//  (= spec v5 ticket 026). Mirrors the BookKanbanStoreTests pattern.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookTodoStore (per-book todo.json)")
struct BookTodoStoreTests {

    private func makeStore() throws -> (BookTodoStore, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test-book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let bookId = UUID()
        return (BookTodoStore(bookId: bookId, bookDirectory: bookDir), bookDir)
    }

    @Test("empty store returns []")
    func emptyReturnsEmpty() throws {
        let (store, _) = try makeStore()
        let items = try store.load()
        #expect(items.isEmpty)
    }

    @Test("save + load roundtrip preserves items + priority + status")
    func saveLoadRoundtrip() throws {
        let (store, _) = try makeStore()
        let original = [
            PerBookTodoItem(title: "buy milk", status: .pending, priority: .low),
            PerBookTodoItem(title: "ship B-09", status: .inProgress, priority: .urgent),
            PerBookTodoItem(title: "write spec", status: .completed, priority: .high),
            PerBookTodoItem(title: "old idea", status: .cancelled, priority: .medium),
        ]
        try store.save(original)
        let loaded = try store.load()
        #expect(loaded.count == 4)
        #expect(loaded.map(\.title) == ["buy milk", "ship B-09", "write spec", "old idea"])
        #expect(loaded.map(\.priority) == [.low, .urgent, .high, .medium])
        #expect(loaded.map(\.status) == [.pending, .inProgress, .completed, .cancelled])
    }

    @Test("save writes todo.json inside the book directory")
    func saveWritesInsideBookDirectory() throws {
        let (store, bookDir) = try makeStore()
        let item = PerBookTodoItem(title: "write test", priority: .high)
        try store.save([item])
        let jsonURL = bookDir.appendingPathComponent("todo.json")
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
    }

    @Test("corrupt JSON returns empty list (= forgiving load)")
    func corruptJsonReturnsEmpty() throws {
        let (store, bookDir) = try makeStore()
        let jsonURL = bookDir.appendingPathComponent("todo.json")
        try "not json at all".data(using: .utf8)!.write(to: jsonURL)
        let items = try store.load()
        #expect(items.isEmpty)
    }
}