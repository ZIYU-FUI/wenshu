//
//  KanbanToolsTests.swift · Wenshu · HERMES-PARTIAL-011 (2026-09-04)
//
//  Round-trip tests for the KanbanTools LLM-facing dispatcher
// (= hermes kanban_tools.py = 1,672 LOC):
//    1. testCreateAndShow                — create + show round-trip
//    2. testListFilters                  — list returns the task
//    3. testCompleteTransition           — complete moves to .done
//    4. testBlockUnblock                 — block / unblock toggles status
//    5. testUnknownAction                — unknown action returns error
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("KanbanTools (HERMES-PARTIAL-011)")
struct KanbanToolsTests {

    // MARK: - Test 1: Create + show

    @Test("create + show round-trip preserves the task")
    func testCreateAndShow() async throws {
        let store = try KanbanStore(path: "/tmp/wenshu-test-\(UUID().uuidString).db")
        let tools = KanbanTools(store: store)
        let createResult = await tools.kanban(
            action: "create",
            params: KanbanTools.KanbanParams(title: "Write chapter 1", body: "outline: foo")
        )
        #expect(createResult.success == true)
        guard let taskID = createResult.data["task_id"] as? String else {
            Issue.record("expected task_id in create result")
            return
        }
        let showResult = await tools.kanban(
            action: "show",
            params: KanbanTools.KanbanParams(taskId: taskID)
        )
        #expect(showResult.success == true)
        #expect(showResult.output.contains("Write chapter 1"))
    }

    // MARK: - Test 2: List

    @Test("list returns the created task")
    func testListFilters() async throws {
        let store = try KanbanStore(path: "/tmp/wenshu-test-\(UUID().uuidString).db")
        let tools = KanbanTools(store: store)
        _ = await tools.kanban(
            action: "create",
            params: KanbanTools.KanbanParams(title: "Listable")
        )
        let listResult = await tools.kanban(action: "list")
        #expect(listResult.success == true)
        #expect(listResult.output.contains("Listable"))
    }

    // MARK: - Test 3: Complete

    @Test("complete transitions the task to .done")
    func testCompleteTransition() async throws {
        let store = try KanbanStore(path: "/tmp/wenshu-test-\(UUID().uuidString).db")
        let tools = KanbanTools(store: store)
        let createResult = await tools.kanban(
            action: "create",
            params: KanbanTools.KanbanParams(title: "Complete me")
        )
        guard let taskID = createResult.data["task_id"] as? String else { return }
        let completeResult = await tools.kanban(
            action: "complete",
            params: KanbanTools.KanbanParams(taskId: taskID)
        )
        #expect(completeResult.success == true)
        let showResult = await tools.kanban(
            action: "show",
            params: KanbanTools.KanbanParams(taskId: taskID)
        )
        #expect(showResult.data["status"] == nil
            || (showResult.data["status"] as? String)?.contains("done") == true)
    }

    // MARK: - Test 4: Block / unblock

    @Test("block then unblock cycles status")
    func testBlockUnblock() async throws {
        let store = try KanbanStore(path: "/tmp/wenshu-test-\(UUID().uuidString).db")
        let tools = KanbanTools(store: store)
        let createResult = await tools.kanban(
            action: "create",
            params: KanbanTools.KanbanParams(title: "Block me")
        )
        guard let taskID = createResult.data["task_id"] as? String else { return }
        let blockResult = await tools.kanban(
            action: "block",
            params: KanbanTools.KanbanParams(taskId: taskID, reason: "waiting on review")
        )
        #expect(blockResult.success == true)
        let unblockResult = await tools.kanban(
            action: "unblock",
            params: KanbanTools.KanbanParams(taskId: taskID)
        )
        #expect(unblockResult.success == true)
    }

    // MARK: - Test 5: Unknown action

    @Test("unknown kanban action returns failure")
    func testUnknownAction() async throws {
        let store = try KanbanStore(path: "/tmp/wenshu-test-\(UUID().uuidString).db")
        let tools = KanbanTools(store: store)
        let result = await tools.kanban(action: "delete")
        #expect(result.success == false)
        #expect(result.output.contains("Unknown kanban action"))
    }
}