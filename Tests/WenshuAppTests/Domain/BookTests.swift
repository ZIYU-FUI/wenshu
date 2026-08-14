// BookTests.swift · Wenshu (Wenshu) · v0.02.1 (book module)
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
// Same pattern as BookshelfTests (v38): lock the domain model shape
// before storage / view code touches it. If Book's fields, identity, or
// Codable strategy change, these tests fail and force the architectural
// decision to surface.

import Testing
import Foundation
@testable import WenshuApp

@Suite("Book")
struct BookTests {

    @Test("id is non-nil and stable across round-trips")
    func idIsStable() throws {
        let id = UUID()
        let shelfId = UUID()
        let book = Book(id: id, title: "Untitled", author: "", shelfId: shelfId, createdAt: .now, updatedAt: .now)
        let encoded = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: encoded)
        #expect(decoded.id == id)
    }

    @Test("shelfId round-trips (= parent shelf reference is required)")
    func shelfIdRoundTrips() throws {
        let shelfId = UUID()
        let book = Book(id: UUID(), title: "X", author: "", shelfId: shelfId, createdAt: .now, updatedAt: .now)
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded.shelfId == shelfId)
    }

    @Test("title round-trips with non-empty string")
    func titleRoundTrips() throws {
        let book = Book(id: UUID(), title: "雪山的狼", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded.title == "雪山的狼")
    }

    @Test("Equatable: same id = same book, even if other fields differ")
    func equalityById() {
        let id = UUID()
        let shelfId = UUID()
        let a = Book(id: id, title: "Foo", author: "", shelfId: shelfId, createdAt: .now, updatedAt: .now)
        let b = Book(id: id, title: "Bar", author: "Someone", shelfId: shelfId, createdAt: .now, updatedAt: .now)
        #expect(a == b)
    }

    @Test("Identifiable: id used as SwiftUI List selection")
    func identifiable() {
        let id = UUID()
        let book = Book(id: id, title: "X", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        #expect(book.id == id)
    }

    @Test("Sendable: can cross actor boundaries")
    func sendable() async {
        let book = Book(id: UUID(), title: "X", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        let result = await Task.detached { book }.value
        #expect(result.id == book.id)
    }

    @Test("directoryName = id.uuidString (= Apple HIG document-based: id = filesystem identity)")
    func directoryName() {
        let id = UUID()
        let book = Book(id: id, title: "X", author: "", shelfId: UUID(), createdAt: .now, updatedAt: .now)
        #expect(book.directoryName == id.uuidString)
    }
}