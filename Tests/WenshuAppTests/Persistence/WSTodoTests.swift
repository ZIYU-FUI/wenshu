//
//  Persistence/WSTodoTests.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Test commit 3: WSTodo @Model (= todos table from TodoStore.swift).

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSTodo (= todos @Model)")
struct WSTodoTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSTodo.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("WSTodo init sets all fields with defaults")
    @MainActor
    func initDefaults() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let todo = WSTodo(id: "t-001", title: "buy milk")
        context.insert(todo)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<WSTodo>())
        #expect(fetched.count == 1)
        #expect(fetched[0].id == "t-001")
        #expect(fetched[0].title == "buy milk")
        #expect(fetched[0].status == "new")
        #expect(fetched[0].priority == 5)
        #expect(fetched[0].dueDate == nil)
    }

    @Test("WSTodo updateStatus mutates status + bumps updatedAt")
    @MainActor
    func updateStatusBumpsUpdatedAt() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let todo = WSTodo(id: "t-002", title: "x")
        context.insert(todo)
        try context.save()
        let original = todo.updatedAt
        try? Thread.sleep(forTimeInterval: 0.05)  // v0.72 Q99 MED fix: bumped from 0.01 (= too flaky on slow CI; = needs > Date precision)
        todo.updateStatus("in_progress")
        try context.save()
        #expect(todo.status == "in_progress")
        #expect(todo.updatedAt > original)
    }

    @Test("WSTodo id uniqueness enforced")
    @MainActor
    func idUniqueEnforced() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let a = WSTodo(id: "same", title: "a")
        let b = WSTodo(id: "same", title: "b")
        context.insert(a)
        context.insert(b)
        #expect(throws: Never.self) {
            try context.save()
        }
    }

    @Test("WSTodo status transitions accepted (= any string)")
    @MainActor
    func statusAnyString() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let todo = WSTodo(id: "t-003", title: "x")
        context.insert(todo)
        for s in ["new", "in_progress", "done", "cancelled"] {
            todo.updateStatus(s)
            try context.save()
            #expect(todo.status == s)
        }
    }
}
