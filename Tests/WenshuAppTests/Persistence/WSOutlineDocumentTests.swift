//
//  Persistence/WSOutlineDocumentTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSOutlineDocument (= per-book outline .md metadata index)")
struct WSOutlineDocumentTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSOutlineDocument.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSOutlineDocument init sets title + filename + byteSize")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = WSOutlineDocument(
            id: "doc-001",
            bookID: "book-1",
            title: "First chapter",
            filename: "chapter-01.md",
            byteSize: 1234,
            summaryExcerpt: "The hero enters the city"
        )
        context.insert(doc)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSOutlineDocument>())
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "First chapter")
        #expect(fetched[0].filename == "chapter-01.md")
        #expect(fetched[0].byteSize == 1234)
        #expect(fetched[0].summaryExcerpt == "The hero enters the city")
    }

    @Test("WSOutlineDocument syncFromFile() updates fields + bumps updatedAt")
    @MainActor
    func syncFromFile() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let doc = WSOutlineDocument(id: "d1", bookID: "b", title: "old", filename: "x.md")
        context.insert(doc)
        try context.save()
        let originalUpdatedAt = doc.updatedAt
        try? Thread.sleep(forTimeInterval: 0.01)
        doc.syncFromFile(title: "new", byteSize: 999, summaryExcerpt: "abc", fileUpdatedAt: Date())
        try context.save()
        #expect(doc.title == "new")
        #expect(doc.byteSize == 999)
        #expect(doc.summaryExcerpt == "abc")
        #expect(doc.updatedAt > originalUpdatedAt)
    }

    @Test("WSOutlineDocument 1↔N to WSBook")
    @MainActor
    func relationshipToBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "b", title: "Test")
        context.insert(book)
        let d1 = WSOutlineDocument(id: "d1", bookID: book.id, title: "x", filename: "x.md")
        let d2 = WSOutlineDocument(id: "d2", bookID: book.id, title: "y", filename: "y.md")
        context.insert(d1)
        context.insert(d2)
        d1.book = book
        d2.book = book
        try context.save()
        #expect(book.outlineDocuments.count == 2)
    }
}
