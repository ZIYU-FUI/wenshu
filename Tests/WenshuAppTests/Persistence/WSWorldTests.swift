//
//  Persistence/WSWorldTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSWorld (= per-book world-building entry @Model)")
struct WSWorldTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSWorld.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSWorld init sets name + type + summary")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let w = WSWorld(
            id: "w-001",
            bookID: "book-1",
            type: "geography",
            name: "Longzhong",
            summary: "Zhuge Liang's cottage"
        )
        context.insert(w)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSWorld>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "Longzhong")
        #expect(fetched[0].type == "geography")
        #expect(fetched[0].summary == "Zhuge Liang's cottage")
    }

    @Test("WSWorld type accepts 5 WorldEntryType values")
    @MainActor
    func typeValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let types = ["geography", "lore", "event", "object", "other"]
        for (i, t) in types.enumerated() {
            let w = WSWorld(id: "w-\(i)", bookID: "b", type: t, name: "x")
            context.insert(w)
            try context.save()
            #expect(w.type == t)
        }
    }

    @Test("WSWorld 1↔N to WSBook")
    @MainActor
    func relationshipToBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "b", title: "Test")
        context.insert(book)
        let w1 = WSWorld(id: "w1", bookID: book.id, name: "x")
        let w2 = WSWorld(id: "w2", bookID: book.id, name: "y")
        context.insert(w1)
        context.insert(w2)
        w1.book = book
        w2.book = book
        try context.save()
        #expect(book.worlds.count == 2)
    }
}
