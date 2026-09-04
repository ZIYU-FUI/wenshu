//
//  BookKanbanStoreTests.swift · Wenshu (文枢) · B-09 (kanban + todo UI functional linkage)
//
//  Round-trip persistence tests for the per-book Kanban JSON store
//  (= spec v5 ticket 026). Mirrors the per-book Character / World
//  contract test style (= uses a /tmp scratch dir per test, cleans up
//  via the testing framework's implicit temp cleanup).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookKanbanStore (per-book kanban.json)")
struct BookKanbanStoreTests {

    /// Make a fresh per-book store + tmp dir. Returns the store + the
    /// scratch dir (= caller doesn't need to clean up; /tmp survives
    /// until reboot on macOS, which matches the contract tests style
    /// for FileSystemCharacterStore etc.).
    private func makeStore() throws -> (BookKanbanStore, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bookDir = root.appendingPathComponent("books/test-book", isDirectory: true)
        try FileManager.default.createDirectory(at: bookDir, withIntermediateDirectories: true)
        let bookId = UUID()
        return (BookKanbanStore(bookId: bookId, bookDirectory: bookDir), bookDir)
    }

    @Test("empty store returns []")
    func emptyReturnsEmpty() throws {
        let (store, _) = try makeStore()
        let tickets = try store.load()
        #expect(tickets.isEmpty)
    }

    @Test("save + load roundtrip preserves tickets")
    func saveLoadRoundtrip() throws {
        let (store, _) = try makeStore()
        let original = [
            KanbanTicket(title: "task one", status: .new),
            KanbanTicket(title: "task two", status: .running),
            KanbanTicket(title: "task three", status: .done),
        ]
        try store.save(original)
        let loaded = try store.load()
        #expect(loaded.count == 3)
        #expect(loaded.map(\.title) == ["task one", "task two", "task three"])
        #expect(loaded.map(\.status) == [.new, .running, .done])
    }

    @Test("save writes kanban.json inside the book directory")
    func saveWritesInsideBookDirectory() throws {
        let (store, bookDir) = try makeStore()
        let ticket = KanbanTicket(title: "write test", status: .ready)
        try store.save([ticket])
        let jsonURL = bookDir.appendingPathComponent("kanban.json")
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
    }

    @Test("corrupt JSON returns empty list (= forgiving load)")
    func corruptJsonReturnsEmpty() throws {
        let (store, bookDir) = try makeStore()
        let jsonURL = bookDir.appendingPathComponent("kanban.json")
        try "not json at all".data(using: .utf8)!.write(to: jsonURL)
        let tickets = try store.load()
        #expect(tickets.isEmpty)
    }
}