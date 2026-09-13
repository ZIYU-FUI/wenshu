//
//  Persistence/WSForeshadowingTests.swift + WSPlaceholderTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSForeshadowing (= foreshadowing events @Model)")
struct WSForeshadowingTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSForeshadowing.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSForeshadowing init sets title + type + status default")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let f = WSForeshadowing(
            id: "fore-001",
            bookID: "book-1",
            title: "The silver dagger",
            foreshadowType: "object",
            detail: "First mentioned in chapter 1",
            setupChapterID: "ch-1",
            setupLineNumber: 42
        )
        context.insert(f)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSForeshadowing>())
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "The silver dagger")
        #expect(fetched[0].foreshadowType == "object")
        #expect(fetched[0].status == "open")
        #expect(fetched[0].setupChapterID == "ch-1")
        #expect(fetched[0].setupLineNumber == 42)
    }

    @Test("WSForeshadowing 1↔N to WSBook")
    @MainActor
    func relationshipToBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "book-rel", title: "Test")
        context.insert(book)
        let f1 = WSForeshadowing(id: "f1", bookID: book.id, title: "x")
        let f2 = WSForeshadowing(id: "f2", bookID: book.id, title: "y")
        context.insert(f1)
        context.insert(f2)
        f1.book = book
        f2.book = book
        try context.save()
        #expect(book.foreshadowings.count == 2)
    }
}

@Suite("WSPlaceholder (= TODO/FIXME markers @Model)")
struct WSPlaceholderTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSChapter.self, WSPlaceholder.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSPlaceholder init sets chapterID + pattern + status default")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let p = WSPlaceholder(
            id: "ph-001",
            bookID: "book-1",
            chapterID: "ch-1",
            lineNumber: 17,
            context: "context excerpt",
            pattern: "[TODO: check this]"
        )
        context.insert(p)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSPlaceholder>())
        #expect(fetched.count == 1)
        #expect(fetched[0].chapterID == "ch-1")
        #expect(fetched[0].lineNumber == 17)
        #expect(fetched[0].pattern == "[TODO: check this]")
        #expect(fetched[0].status == "open")
        #expect(fetched[0].context == "context excerpt")
    }

    @Test("WSPlaceholder trims context whitespace at init")
    @MainActor
    func contextTrims() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let p = WSPlaceholder(
            id: "ph-002",
            bookID: "b",
            chapterID: "c",
            lineNumber: 1,
            context: "  trim me  \n",
            pattern: "x"
        )
        context.insert(p)
        try context.save()
        #expect(p.context == "trim me")
    }

    @Test("WSPlaceholder 1↔N to WSBook")
    @MainActor
    func relationshipToBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "book-ph", title: "Test")
        context.insert(book)
        let p1 = WSPlaceholder(id: "p1", bookID: book.id, chapterID: "c", lineNumber: 1, pattern: "x")
        context.insert(p1)
        p1.book = book
        try context.save()
        #expect(book.placeholders.count == 1)
    }
}
