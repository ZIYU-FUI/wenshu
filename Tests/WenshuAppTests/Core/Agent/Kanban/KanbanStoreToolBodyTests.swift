//
//  Core/Agent/Kanban/KanbanStoreToolBodyTests.swift · kanban-markdown 2026-09-28 T4
//
//  KanbanStoreTool.execute(input:) — the LLM-facing entry point —
//  persists the `body` argument when the LLM sends
//  {action: "create", title: ..., body: "..."}.
//
//  Today: buildParams parses body cleanly (KanbanStoreTool.swift:180)
//  and passes it as params.body, but KanbanTools.create(params:)
//  never forwards params.body into store.add(...). Body silently
//  drops between the tool envelope and the @Model column.
//
//  Acceptance: when the LLM body arg is present, the resulting
//  KanbanTask.body reflects that arg exactly. When absent, nil.
//

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("KanbanStoreTool.execute.body (kanban-markdown 2026-09-28 T4)")
struct KanbanStoreToolBodyTests {

    @MainActor
    private func freshTool() throws -> (KanbanStoreTool, WSKanbanRepository) {
        let schema = Schema([WSKanbanTask.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let store = WSKanbanRepository(container: container)
        let tools = KanbanTools(store: store)
        return (KanbanStoreTool(kanbanTools: tools), store)
    }

    @Test("execute(create) with body persists body end-to-end")
    @MainActor
    func executeCreateWithBody() async throws {
        let (tool, store) = try freshTool()
        let input = #"{"action":"create","title":"outline ch4","body":"**Goal:** 4 beats with conflict."}"#
        _ = try await tool.execute(input: input)
        let all = try store.list()
        #expect(all.count == 1)
        #expect(all[0].body == "**Goal:** 4 beats with conflict.")
    }

    @Test("execute(create) without body leaves body nil")
    @MainActor
    func executeCreateWithoutBody() async throws {
        let (tool, store) = try freshTool()
        let input = #"{"action":"create","title":"no body"}"#
        _ = try await tool.execute(input: input)
        let all = try store.list()
        #expect(all.count == 1)
        #expect(all[0].body == nil)
    }
}
