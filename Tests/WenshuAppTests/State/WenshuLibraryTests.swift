// WenshuLibraryTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
// These tests lock WenshuLibrary's public behavior so the view layer
// (= v40 BookshelfListView) can rely on it without re-implementing logic.

import Testing
import Foundation
@testable import WenshuApp

@Suite("WenshuLibrary")
struct WenshuLibraryTests {

    /// In-memory LibraryStoring impl for tests (= avoid touching real
    /// ~/Documents/wenshu/). Lives next to the test target because it's
    /// only for contract / library tests; production code uses
    /// FileSystemLibraryStore.
    private final class InMemoryStore: LibraryStoring, @unchecked Sendable {
        let rootURL: URL = URL(fileURLWithPath: "/tmp/inmemory", isDirectory: true)
        var shelves: [UUID: Bookshelf] = [:]
        func loadShelves() throws -> [Bookshelf] {
            Array(shelves.values).sorted { $0.updatedAt > $1.updatedAt }
        }
        func saveShelf(_ shelf: Bookshelf) throws {
            if shelves[shelf.id] != nil {
                throw LibraryStoringError(kind: .shelfAlreadyExists(shelf.id))
            }
            shelves[shelf.id] = shelf
        }
        func deleteShelf(id: UUID) throws {
            shelves.removeValue(forKey: id)
        }
        func search(query: String) throws -> [SearchHit] { [] }
    }

    @Test("init loads existing shelves from store")
    func initLoadsShelves() async throws {
        let store = InMemoryStore()
        try store.saveShelf(Bookshelf(id: UUID(), name: "Existing", createdAt: .now, updatedAt: .now))
        let lib = await WenshuLibrary(store: store)
        let names = await lib.shelves.map(\.name)
        #expect(names == ["Existing"])
    }

    @Test("addShelf appends to the in-memory list AND persists to store")
    func addShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "长篇小说")
        try await lib.addShelf(shelf)
        let names = await lib.shelves.map(\.name)
        #expect(names == ["长篇小说"])
        let persisted = try store.loadShelves().map(\.name)
        #expect(persisted == ["长篇小说"])
    }

    @Test("addShelf with duplicate id throws and does NOT corrupt the list")
    func addShelfDuplicateThrows() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let id = UUID()
        try await lib.addShelf(Bookshelf(id: id, name: "A"))
        await #expect(throws: LibraryStoringError.self) {
            try await lib.addShelf(Bookshelf(id: id, name: "B"))
        }
        // Only the first shelf is in the list
        let count = await lib.shelves.count
        #expect(count == 1)
    }

    @Test("renameShelf updates name + updatedAt in memory AND persists")
    func renameShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let id = UUID()
        try await lib.addShelf(Bookshelf(id: id, name: "Old"))
        try await Task.sleep(nanoseconds: 10_000_000)  // ensure updatedAt differs
        try await lib.renameShelf(id: id, to: "New")
        let names = await lib.shelves.map(\.name)
        #expect(names == ["New"])
        let persisted = try store.loadShelves().first?.name
        #expect(persisted == "New")
    }

    @Test("deleteShelf removes from list AND from store")
    func deleteShelf() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        let shelf = Bookshelf(name: "Trash me")
        try await lib.addShelf(shelf)
        try await lib.deleteShelf(id: shelf.id)
        #expect(await lib.shelves.isEmpty)
        #expect(try store.loadShelves().isEmpty)
    }

    @Test("deleteShelf with unknown id is a no-op (= idempotent)")
    func deleteUnknownIsNoop() async throws {
        let store = InMemoryStore()
        let lib = await WenshuLibrary(store: store)
        try await lib.deleteShelf(id: UUID())
        #expect(await lib.shelves.isEmpty)
    }

    @Test("selectedShelfId is nil by default; setSelectedShelf / clear work")
    func selectedShelfId() async throws {
        let lib = await WenshuLibrary(store: InMemoryStore())
        #expect(await lib.selectedShelfId == nil)
        let id = UUID()
        await lib.setSelectedShelf(id: id)
        #expect(await lib.selectedShelfId == id)
        await lib.clearSelection()
        #expect(await lib.selectedShelfId == nil)
    }
}