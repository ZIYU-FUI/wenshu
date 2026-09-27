//
//  Persistence/Repositories/WSKanbanRepositoryBodyTests.swift · kanban-markdown 2026-09-28 T3
//
//  RED tests for Phase 1 T3:
//  WSKanbanRepository.add(...) persists the optional body
//  through to the fetched KanbanTask. The current add signature
//  has no body argument, so this test calls add(title:, body:)
//  and expects body to round-trip via get(id:).
//
//  WSPersistenceContainer.shared is the live container (= uses
//  the on-disk SQLite/SwiftData store). For Phase 1 T3 we
//  isolate via an in-memory ModelContainer the same way the rest
//  of WSKanbanRepository tests do.
//
//  See WSTodoRepository / WSChatRepository for the pattern.
//

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSKanbanRepository.body (kanban-markdown 2026-09-28 T3)")
struct WSKanbanRepositoryBodyTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WSKanbanTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("add(title:, body:) persists body through to fetched KanbanTask")
    @MainActor
    func addPersistsBody() throws {
        let container = try makeContainer()
        let repo = WSKanbanRepository(container: container)
        let created = try repo.add(
            title: "outline chapter 4",
            body: "**Goal:** write a 4-beat outline with conflict at beat 2."
        )
        let fetched = try repo.get(id: created.id)
        #expect(fetched?.body == "**Goal:** write a 4-beat outline with conflict at beat 2.")
    }

    @Test("add(title:) leaves body nil when body is omitted")
    @MainActor
    func addOmittingBodyIsNil() throws {
        let container = try makeContainer()
        let repo = WSKanbanRepository(container: container)
        let created = try repo.add(title: "no body here")
        let fetched = try repo.get(id: created.id)
        #expect(fetched?.body == nil)
    }

    @Test("list() includes body in every KanbanTask")
    @MainActor
    func listSurfacesBody() throws {
        let container = try makeContainer()
        let repo = WSKanbanRepository(container: container)
        _ = try repo.add(title: "a", body: "A body")
        _ = try repo.add(title: "b")
        let all = try repo.list()
        let withBody = all.first { $0.body != nil }
        let withoutBody = all.first { $0.title == "b" }
        #expect(withBody?.body == "A body")
        #expect(withoutBody?.body == nil)
    }
}
