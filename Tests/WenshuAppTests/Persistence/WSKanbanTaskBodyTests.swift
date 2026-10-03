//
//  Persistence/WSKanbanTaskBodyTests.swift · Wenshu · kanban-markdown 2026-09-28
//
//  WSKanbanTask gets a `body: String?` column to hold agent-written markdown.
//  Mirrors the existing WSTodo pattern (in-memory ModelContainer + Schema([WSKanbanTask.self])).
//
//  Notes:
//  - The full repo @Model schema lives in WSPersistenceContainer.
//  - The tests here use a minimal schema so the new column is observable
//    in isolation (= the SwiftData store proves the field round-trips).
//
// : the RED test asserts WSKanbanTask accepts a `body` init arg AND
// round-trips it through SwiftData. Without the field, the file fails
// to compile (= red via symptom = compile failure).
//

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSKanbanTask.body (kanban-markdown 2026-09-28 T1)")
struct WSKanbanTaskBodyTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSKanbanTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSKanbanTask init accepts body: String? and persists it")
    @MainActor
    func initPersistsBody() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let task = WSKanbanTask(
            id: "k-001",
            title: "Summarize chapter 3",
            body: "**Goal:** extract 3 themes from chapter 3."
        )
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSKanbanTask>())
        #expect(fetched.count == 1)
        #expect(fetched[0].body == "**Goal:** extract 3 themes from chapter 3.")
    }

    @Test("WSKanbanTask body defaults to nil when omitted")
    @MainActor
    func bodyDefaultsToNil() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let task = WSKanbanTask(id: "k-002", title: "no body here")
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSKanbanTask>())
        #expect(fetched[0].body == nil)
    }
}
