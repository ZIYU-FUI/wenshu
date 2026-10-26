//
//  Persistence/WSChapterTests.swift · Wenshu · v0.72 SwiftData migration

import Foundation
import SwiftData
import Testing
import WenshuData

@Suite("WSChapter (= the chapter @Model)")
struct WSChapterTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSBookShelf.self, WSChapter.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSChapter init sets title + position + status")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let ch = WSChapter(id: "ch-001", bookID: "book-1", title: "Chapter 1", position: 0)
        context.insert(ch)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSChapter>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "ch-001")
        #expect(fetched[0].bookID == "book-1")
        #expect(fetched[0].title == "Chapter 1")
        #expect(fetched[0].position == 0)
        #expect(fetched[0].wordCount == 0)
        #expect(fetched[0].status == "draft")
    }
}
