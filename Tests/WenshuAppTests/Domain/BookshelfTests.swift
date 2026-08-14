// BookshelfTests.swift · Wenshu (Wenshu) · v0.02.0
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
// These tests lock the Bookshelf domain model before any storage / view code
// touches it. If Bookshelf's shape changes (= adds a required field, renames
// id, etc.), these tests fail and force the architectural decision to surface
// (= not just an incidental change in some deep file).

import Testing
import Foundation
@testable import WenshuApp

@Suite("Bookshelf")
struct BookshelfTests {

    @Test("id is non-nil and stable across round-trips")
    func idIsStable() throws {
        let id = UUID()
        let shelf = Bookshelf(id: id, name: "Test", createdAt: .now, updatedAt: .now)
        let encoded = try JSONEncoder().encode(shelf)
        let decoded = try JSONDecoder().decode(Bookshelf.self, from: encoded)
        #expect(decoded.id == id)
    }

    @Test("name round-trips with non-empty string")
    func nameRoundTrips() throws {
        let shelf = Bookshelf(id: UUID(), name: "长篇小说", createdAt: .now, updatedAt: .now)
        let data = try JSONEncoder().encode(shelf)
        let decoded = try JSONDecoder().decode(Bookshelf.self, from: data)
        #expect(decoded.name == "长篇小说")
    }

    @Test("Equatable: same id = same shelf, even if other fields differ")
    func equalityById() {
        let id = UUID()
        let a = Bookshelf(id: id, name: "Foo", createdAt: .now, updatedAt: .now)
        let b = Bookshelf(id: id, name: "Bar", createdAt: .now, updatedAt: .now)
        #expect(a == b)
    }

    @Test("Identifiable: id used as SwiftUI List selection")
    func identifiable() {
        let id = UUID()
        let shelf = Bookshelf(id: id, name: "X", createdAt: .now, updatedAt: .now)
        #expect(shelf.id == id)
    }

    @Test("Sendable: can cross actor boundaries (= SwiftUI view + storage layer)")
    func sendable() async {
        let shelf = Bookshelf(id: UUID(), name: "X", createdAt: .now, updatedAt: .now)
        let result = await Task.detached { shelf }.value
        #expect(result.id == shelf.id)
    }
}