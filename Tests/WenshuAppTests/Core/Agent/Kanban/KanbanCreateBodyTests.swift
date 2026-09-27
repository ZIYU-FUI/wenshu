//
//  Core/Agent/Kanban/KanbanCreateBodyTests.swift · kanban-markdown 2026-09-28 T4
//
//  RED tests for Phase 1 T4:
//  KanbanTools.create(params:) persists params.body through to
//  the created task. Today, params.body parses cleanly out of
//  the LLM tool envelope (= KanbanStoreTool.swift:180) but the
//  create() method never forwards it to store.add(...). Body
//  silently drops.
//
//  Acceptance: when the LLM sends {action: "create", title: "x",
//  body: "**Goal:** ..."}, the resulting KanbanTask.body is the
//  same string.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanTools.create.body (kanban-markdown 2026-09-28 T4)")
struct KanbanCreateBodyTests {

    @MainActor
    private func makeStore() throws -> WSKanbanRepository {
        let schema = Schema([WSKanbanTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return WSKanbanRepository(container: container)
    }

    @Test("create action with body persists body on the resulting task")
    @MainActor
    func createWithBodyPersists() async throws {
        let store = try makeStore()
        let tools = KanbanTools(store: store)
        let params = KanbanTools.KanbanParams(
            taskId: nil,
            title: "outline chapter 4",
            body: "**Goal:** write a 4-beat outline with conflict at beat 2.",
            status: nil,
            assignee: nil,
            tenant: nil,
            priority: 5,
            modelOverride: nil,
            comment: nil,
            reason: nil,
            limit: nil,
            includeArchived: nil,
            parentId: nil,
            childId: nil,
            newStatus: nil
        )
        let result = await tools.create(params: params)
        #expect(result.success == true)
        let all = try store.list()
        let created = all.first
        #expect(created?.body == "**Goal:** write a 4-beat outline with conflict at beat 2.")
    }

    @Test("create without body leaves body nil")
    @MainActor
    func createWithoutBodyIsNil() async throws {
        let store = try makeStore()
        let tools = KanbanTools(store: store)
        let params = KanbanTools.KanbanParams(
            taskId: nil,
            title: "no body here",
            body: nil,
            status: nil,
            assignee: nil,
            tenant: nil,
            priority: 5,
            modelOverride: nil,
            comment: nil,
            reason: nil,
            limit: nil,
            includeArchived: nil,
            parentId: nil,
            childId: nil,
            newStatus: nil
        )
        _ = await tools.create(params: params)
        let all = try store.list()
        #expect(all.first?.body == nil)
    }
}
