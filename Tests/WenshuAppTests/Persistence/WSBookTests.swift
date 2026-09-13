//
//  Persistence/WSBookTests.swift + WSBookShelfTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSBook + WSBookShelf (= books @Model + shelves)")
struct WSBookTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSBookShelf.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSBook init sets title + optional idea/length/shelfID")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(
            id: "book-001",
            title: "赤壁之战",
            idea: "三国时期的赤壁之战",
            length: 80_000,
            shelfID: "shelf-1"
        )
        context.insert(book)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSBook>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "book-001")
        #expect(fetched[0].title == "赤壁之战")
        #expect(fetched[0].idea == "三国时期的赤壁之战")
        #expect(fetched[0].length == 80_000)
        #expect(fetched[0].shelfID == "shelf-1")
    }

    @Test("WSBook minimal init (= title only; = optional fields nil)")
    @MainActor
    func initMinimal() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "book-min", title: "Untitled")
        context.insert(book)
        try context.save()
        #expect(book.idea == nil)
        #expect(book.length == nil)
        #expect(book.shelfID == nil)
    }

    @Test("WSBookShelf init + 1↔N relationship to WSBook")
    @MainActor
    func shelfRelationship() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let shelf = WSBookShelf(id: "shelf-1", name: "测试书架", position: 0)
        context.insert(shelf)
        let b1 = WSBook(id: "b1", title: "Book 1", shelfID: shelf.id)
        let b2 = WSBook(id: "b2", title: "Book 2", shelfID: shelf.id)
        context.insert(b1)
        context.insert(b2)
        b1.shelf = shelf
        b2.shelf = shelf
        try context.save()

        #expect(shelf.books.count == 2)
        #expect(Set(shelf.books.map { $0.id }) == Set(["b1", "b2"]))
        #expect(b1.shelf?.name == "测试书架")
    }

    @Test("WSBook id uniqueness enforced")
    @MainActor
    func bookIDUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSBook(id: "same", title: "a")
        let b = WSBook(id: "same", title: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSBookShelf id uniqueness enforced")
    @MainActor
    func shelfIDUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSBookShelf(id: "same", name: "a")
        let b = WSBookShelf(id: "same", name: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
