//
//  Persistence/WSCharacterTests.swift + WSKanbanTaskTests.swift · Wenshu · v0.72 SwiftData migration Phase 1

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSCharacter (= per-book character @Model)")
struct WSCharacterTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSBook.self, WSCharacter.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSCharacter init sets name + role + summary")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let ch = WSCharacter(
            id: "char-001",
            bookID: "book-1",
            name: "Zhuge Liang",
            role: "protagonist",
            summary: "The strategist of the Three Kingdoms"
        )
        context.insert(ch)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSCharacter>())
        #expect(fetched.count == 1)
        #expect(fetched[0].name == "Zhuge Liang")
        #expect(fetched[0].role == "protagonist")
        #expect(fetched[0].summary == "The strategist of the Three Kingdoms")
    }

    @Test("WSCharacter role accepts 5 CharacterRole values")
    @MainActor
    func roleValues() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let roles = ["protagonist", "antagonist", "supporting", "narrator", "other"]
        for (i, role) in roles.enumerated() {
            let ch = WSCharacter(id: "char-\(i)", bookID: "b", name: "x", role: role, summary: "")
            context.insert(ch)
            try context.save()
            #expect(ch.role == role)
        }
    }

    @Test("WSCharacter 1↔N to WSBook")
    @MainActor
    func relationshipToBook() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let book = WSBook(id: "b", title: "Test")
        context.insert(book)
        let c1 = WSCharacter(id: "c1", bookID: book.id, name: "A")
        let c2 = WSCharacter(id: "c2", bookID: book.id, name: "B")
        context.insert(c1)
        context.insert(c2)
        c1.book = book
        c2.book = book
        try context.save()
        #expect(book.characters.count == 2)
    }
}

@Suite("WSKanbanTask (= kanban_tasks @Model)")
struct WSKanbanTaskTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSKanbanTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSKanbanTask init sets title + status default + priority default")
    @MainActor
    func initSetsFields() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let t = WSKanbanTask(id: "kt-001", title: "Review chapter 1")
        context.insert(t)
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<WSKanbanTask>())
        #expect(fetched.count == 1)
        #expect(fetched[0].title == "Review chapter 1")
        #expect(fetched[0].status == "new")
        #expect(fetched[0].priority == 5)
        #expect(fetched[0].startedAt == nil)
        #expect(fetched[0].completedAt == nil)
    }

    @Test("WSKanbanTask start(assignee:) sets status=in_progress + startedAt")
    @MainActor
    func start() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let t = WSKanbanTask(id: "kt-002", title: "x")
        context.insert(t)
        try context.save()
        t.start(assignee: "writer")
        try context.save()
        #expect(t.status == "in_progress")
        #expect(t.assignee == "writer")
        #expect(t.startedAt != nil)
    }

    @Test("WSKanbanTask complete() sets status=done + completedAt")
    @MainActor
    func complete() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let t = WSKanbanTask(id: "kt-003", title: "x")
        context.insert(t)
        try context.save()
        t.start(assignee: "writer")
        t.complete()
        try context.save()
        #expect(t.status == "done")
        #expect(t.completedAt != nil)
    }

    @Test("WSKanbanTask id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSKanbanTask(id: "same", title: "a")
        let b = WSKanbanTask(id: "same", title: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }
}
