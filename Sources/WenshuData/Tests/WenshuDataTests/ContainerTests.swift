//
//  Persistence/ContainerTests.swift · Wenshu · v0.72 SwiftData migration
//
//  Test : WSPersistenceContainer = ModelContainer setup.
//  Validates that all 21 @Model classes can co-exist in one container
//  (= no schema conflicts; = SwiftData accepts the union).

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("WSPersistenceContainer (= SwiftData ModelContainer setup)")
struct WSPersistenceContainerTests {

    @Test("Container.makeInMemoryContainer() succeeds with all 21 @Model classes")
    @MainActor
    func makeInMemoryContainerSucceeds() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = ModelContext(container)
        #expect(context.container.configurations.count == 1)
    }

    @Test("Container can insert + fetch across multiple @Model types")
    @MainActor
    func crossTypeInsertAndFetch() throws {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        let context = ModelContext(container)

        // Insert one of each major type
        let book = WSBook(id: "book-001", title: "Book")
        let todo = WSTodo(id: "t-001", title: "x")
        let session = WSSession(sessionID: "sess-001", title: "test")
        context.insert(book)
        context.insert(todo)
        context.insert(session)
        try context.save()

        // Fetch each
        let books = try context.fetch(FetchDescriptor<WSBook>())
        let todos = try context.fetch(FetchDescriptor<WSTodo>())
        let sessions = try context.fetch(FetchDescriptor<WSSession>())
        #expect(books.count == 1)
        #expect(todos.count == 1)
        #expect(sessions.count == 1)
    }
}
