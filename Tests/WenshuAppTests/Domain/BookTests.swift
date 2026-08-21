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

    // v52: New Book Creation Wizard
    // Boss 8/15 17:32: '新建书架, 然后新建书, 然后在新建书的时候, 就是是
    // 我说的那个新建的场景了, 先实现最简新建书的逻辑, 书名, 篇幅选择, 创意
    // 点, 然后新建'.
    //
    // Two new optional fields on Book (= length enum + idea string).
    // Optional so v0.02.x fixtures (which predate these fields) still
    // decode. Codable back-compat: a missing key in book.json decodes
    // to nil / default.

    @Test("BookLength has three cases: short / medium / long")
    func bookLengthHasThreeCases() {
        // Static enum sanity (= used by Picker in the wizard).
        let all = BookLength.allCases
        #expect(all.count == 3)
        #expect(all.contains(.short))
        #expect(all.contains(.medium))
        #expect(all.contains(.long))
    }

    @Test("Book with length + idea round-trips through JSON")
    func bookWithNewFieldsRoundTrips() throws {
        let book = Book(
            id: UUID(),
            title: "雪山的狼",
            author: "小白",
            shelfId: UUID(),
            length: .long,
            idea: "一个关于孤独和记忆的故事",
            createdAt: .now,
            updatedAt: .now
        )
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Book.self, from: data)
        #expect(decoded == book)
        #expect(decoded.length == .long)
        #expect(decoded.idea == "一个关于孤独和记忆的故事")
    }

    @Test("Book with default length + nil idea (= old-style fixture still decodes)")
    func bookWithDefaultFields() throws {
        let book = Book(title: "X", author: "", shelfId: UUID())
        // Default length is .medium (= most common case); idea defaults
        // to nil (= the wizard makes it optional; the user can skip it).
        #expect(book.length == .medium)
        #expect(book.idea == nil)
    }

    @Test("JSON missing 'length' / 'idea' keys decodes to defaults (= back-compat with v0.02.x fixtures)")
    func bookJsonBackCompat() throws {
        // v0.02.x book.json files don't have 'length' or 'idea' (= fields
        // added in v52). The Codable conformance must decode them as
        // their default values (= .medium, nil), NOT fail.
        let oldJson = """
        {
          "id": "00000000-0000-0000-0000-000000000AAA",
          "title": "Legacy",
          "author": "",
          "shelfId": "00000000-0000-0000-0000-000000000001",
          "createdAt": 808400000.0,
          "updatedAt": 808400000.0
        }
        """.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: oldJson)
        #expect(book.title == "Legacy")
        #expect(book.length == .medium)
        #expect(book.idea == nil)
    }
}