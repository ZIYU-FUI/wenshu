// LibraryStoringContractTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. These tests describe the BEHAVIORAL CONTRACT that every
// LibraryStoring implementation must satisfy:
//   - FileSystemLibraryStore (v0.02.0)
//   - MetadataQueryLibraryStore (v0.03.0)
//   - CoreDataLibraryStore     (v0.04.0+, if needed)
//   - CloudKitDocumentsLibraryStore (v0.04.0+, if needed)
//
// The contract is parameterized over an `any LibraryStoring` factory so
// each impl runs through the same test suite (= Apple HIG Test Suite
// pattern). Adding a new impl = adding a new conformance factory; the
// test bodies don't change.

import Testing
import Foundation
@testable import WenshuApp

/// One conformance = one suite. To add FileSystem tests, create
/// `FileSystemLibraryStoreContractTests` that uses `LibraryStoringContractTests`
/// as a base (= struct inheritance is not in Swift; instead, the contract
/// body is exposed as static funcs called by each suite).
///
/// v0.02.0 only has FileSystemLibraryStore (lands in v39); once it's in
/// place, FileSystemLibraryStoreContractTests is added here.

@Suite("LibraryStoring contract")
struct LibraryStoringContractTests {

    // Use the FileSystem implementation under /tmp to verify the contract
    // end-to-end (= each test creates an isolated tmp root so tests don't
    // collide and don't touch real user data).

    private func makeStore() throws -> (any LibraryStoring, URL) {
        let root = URL(fileURLWithPath: "/tmp/wenshu-test-\(UUID().uuidString)", isDirectory: true)
        return (FileSystemLibraryStore(rootURL: root), root)
    }

    @Test("empty store returns no shelves")
    func emptyStore() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelves = try store.loadShelves()
        #expect(shelves.isEmpty)
    }

    @Test("saveShelf + loadShelves round-trips a shelf")
    func roundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Bookshelf(id: UUID(), name: "长篇小说", createdAt: .now, updatedAt: .now)
        try store.saveShelf(original)
        let loaded = try store.loadShelves()
        #expect(loaded.count == 1)
        #expect(loaded.first == original)
    }

    @Test("saving twice with the same id throws .shelfAlreadyExists")
    func duplicateSave() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        try store.saveShelf(Bookshelf(id: id, name: "A", createdAt: .now, updatedAt: .now))
        #expect(throws: LibraryStoringError.self) {
            try store.saveShelf(Bookshelf(id: id, name: "B", createdAt: .now, updatedAt: .now))
        }
    }

    @Test("saveShelf + deleteShelf round-trips: re-load is empty")
    func deleteRoundTrip() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "Trash me", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        try store.deleteShelf(id: shelf.id)
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("deleteShelf on a missing id is a no-op (= idempotent)")
    func deleteMissingIsNoop() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.deleteShelf(id: UUID())  // nothing on disk yet
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("saveShelf creates a directory at <root>/<shelf-id>/")
    func directoryCreated() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "X", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let expectedDir = root.appendingPathComponent(shelf.directoryName)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: expectedDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test("saveShelf writes shelf.json inside the shelf directory")
    func shelfJsonWritten() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let shelf = Bookshelf(id: UUID(), name: "X", createdAt: .now, updatedAt: .now)
        try store.saveShelf(shelf)
        let jsonURL = root
            .appendingPathComponent(shelf.directoryName)
            .appendingPathComponent("shelf.json")
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
        let data = try Data(contentsOf: jsonURL)
        let decoded = try JSONDecoder().decode(Bookshelf.self, from: data)
        #expect(decoded == shelf)
    }

    @Test("multiple shelves: saveShelf three, loadShelves returns three sorted by updatedAt desc")
    func multipleShelves() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date.now
        let a = Bookshelf(id: UUID(), name: "A", createdAt: now, updatedAt: now)
        let b = Bookshelf(id: UUID(), name: "B", createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(-100))
        let c = Bookshelf(id: UUID(), name: "C", createdAt: now.addingTimeInterval(-50), updatedAt: now.addingTimeInterval(-50))
        try store.saveShelf(a)
        try store.saveShelf(b)
        try store.saveShelf(c)
        let loaded = try store.loadShelves()
        #expect(loaded.map(\.id) == [a.id, c.id, b.id])
    }

    @Test("search returns [] in v0.02.0 (= stub; v0.03.0 implements)")
    func searchStubReturnsEmpty() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.saveShelf(Bookshelf(id: UUID(), name: "Anything", createdAt: .now, updatedAt: .now))
        #expect(try store.search(query: "Anything").isEmpty)
    }

    @Test("rootURL points at the configured directory (= so UI can show it)")
    func rootURLExposed() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(store.rootURL.standardizedFileURL == root.standardizedFileURL)
    }
}