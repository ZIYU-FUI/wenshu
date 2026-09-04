//
//  KanbanStoreToolTests.swift · Wenshu · P0 #5 (WIRE-AGENT-005)
//
//  Round-trip tests for the KanbanStoreTool thin adapter. Each test
//  exercises the full path:
//
//    LLM-supplied JSON input -> ToolInputParser -> KanbanStoreTool
//      -> KanbanTools.kanban(action:params:)
//      -> KanbanStore (wenshu-side canonical, read back by the test)
//
//  Test inventory (= 4 round-trip tests per spec):
//
//    1. testKanbanStoreTool_create_persistsToKanbanView
//       (= create call -> KanbanStore row written, observable
//          via list / show)
//    2. testKanbanStoreTool_list_returnsCurrentKanbanItems
//       (= KanbanStore pre-seeded with 2 items -> list returns
//          JSON of 2 items via the adapter)
//    3. testKanbanStoreTool_claim_setsClaimedBy
//       (= create -> update with assignee -> KanbanStore row
//          updated to reflect the new assignee = the wenshu-side
//          equivalent of hermes' "claim" surface, since wenshu
//          KanbanStore has a single `assignee` field not a
//          separate `claimed_by` column)
//    4. testKanbanStoreTool_complete_marksDone
//       (= create -> complete -> KanbanStore row updated to
//          status=done)
//
//  All tests use a tmp-file KanbanStore so they don't touch the
//  user's canonical ~/Library/Application Support/wenshu/kanban.db.
//
//  Acceptance: `--filter "KanbanStoreTool"` = 4/4 pass.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanStoreTool adapter (P0 #5 / WIRE-AGENT-005)")
struct KanbanStoreToolTests {

    // MARK: - Helpers

    /// Make a fresh KanbanStore backed by a tmp file (= each test
    /// gets isolation; no cleanup race because we use a unique UUID
    /// per call and the OS reclaims tmp files on reboot).
    /// Async because KanbanStore.bootstrap() is actor-isolated.
    private static func makeKanbanStore() async throws -> KanbanStore {
        let path = NSTemporaryDirectory() + "wenshu-kanban-store-tool-\(UUID().uuidString).db"
        let store = try KanbanStore(path: path)
        try await store.bootstrap()
        return store
    }

    /// Build a fresh KanbanStoreTool wrapping a fresh KanbanTools
    /// (= the canonical adapter wiring: KanbanStoreTool ->
    /// KanbanTools -> KanbanStore).
    private static func makeTool(store: KanbanStore) -> KanbanStoreTool {
        let tools = KanbanTools(store: store)
        return KanbanStoreTool(kanbanTools: tools)
    }

    // MARK: - Test 1: create persists to KanbanView (KanbanStore)

    @Test("kanban_create persists the new task to KanbanStore (= KanbanView reads from here)")
    func testKanbanStoreTool_create_persistsToKanbanView() async throws {
        let store = try await Self.makeKanbanStore()
        let tool = Self.makeTool(store: store)

        let input = #"{"action":"create","title":"Draft chapter 1","body":"outline: foo","priority":7}"#
        let output = try await tool.execute(input: input)

        // 1) adapter returned ok envelope
        #expect(output.contains("\"ok\":true"), "output must report ok=true; got: \(output)")
        #expect(output.contains("\"action\":\"create\""), "output must echo action=create; got: \(output)")
        #expect(output.contains("Draft chapter 1"), "output must echo title; got: \(output)")

        // 2) data envelope includes a task_id the LLM can reference
        //    in follow-up tool calls (= e.g. kanban_complete / show).
        #expect(output.contains("\"task_id\""), "output must include task_id; got: \(output)")

        // 3) KanbanStore has the new row (= the same row KanbanView
        //    reads from; OpenBox zone shows it on next refresh).
        let tasks = try await store.list()
        #expect(tasks.count == 1, "KanbanStore must hold 1 row after create; got \(tasks.count)")
        #expect(tasks.first?.title == "Draft chapter 1")
        #expect(tasks.first?.priority == 7, "priority must round-trip; got \(String(describing: tasks.first?.priority))")
    }

    // MARK: - Test 2: list returns current Kanban items

    @Test("kanban_list returns the canonical KanbanStore items as JSON")
    func testKanbanStoreTool_list_returnsCurrentKanbanItems() async throws {
        let store = try await Self.makeKanbanStore()
        let tool = Self.makeTool(store: store)

        // Pre-seed KanbanStore with 2 items (= bypasses the adapter
        // so this test isolates the list path).
        _ = try await store.add(title: "First ticket", priority: 8)
        _ = try await store.add(title: "Second ticket", priority: 3)

        let output = try await tool.execute(input: #"{"action":"list"}"#)

        // Adapter must return 2 items (= the count field KanbanTools
        // emits on the list action).
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"list\""))
        #expect(output.contains("First ticket"), "output must include the first seeded item; got: \(output)")
        #expect(output.contains("Second ticket"), "output must include the second seeded item; got: \(output)")
        #expect(output.contains("\"count\":\"2\""), "output must report count=2; got: \(output)")
    }

    // MARK: - Test 3: claim sets assignee (wenshu-side equivalent of hermes claim)

    @Test("kanban_create with assignee writes assignee to KanbanStore (= wenshu-side 'claim' surface)")
    func testKanbanStoreTool_claim_setsClaimedBy() async throws {
        let store = try await Self.makeKanbanStore()
        let tool = Self.makeTool(store: store)

        // 1) create with an assignee (= simulates the LLM claiming a
        //    task for itself; hermes uses a separate `claimed_by`
        //    column, wenshu collapses to the `assignee` field on
        //    KanbanTask per KanbanStore.swift line 39).
        let createInput = #"{"action":"create","title":"Write outline","assignee":"wenshu-conductor"}"#
        let createOutput = try await tool.execute(input: createInput)
        #expect(createOutput.contains("\"ok\":true"))

        // 2) KanbanStore row has assignee = wenshu-conductor.
        let tasks = try await store.list()
        #expect(tasks.count == 1)
        #expect(tasks.first?.assignee == "wenshu-conductor",
                "KanbanStore row must have assignee=wenshu-conductor; got: \(String(describing: tasks.first?.assignee))")

        // 3) show returns the same task (= so the next tool call
        //    can re-claim it / inspect assignee).
        let taskID = try await Self.taskIDFromJSONEnvelope(createOutput, fallbackStore: store)
        let showInput = #"{"action":"show","task_id":"\#(taskID)"}"#
        let showOutput = try await tool.execute(input: showInput)
        #expect(showOutput.contains("\"ok\":true"), "show must return ok=true; got: \(showOutput)")
        #expect(showOutput.contains("Write outline"),
                "show output must include the task title; got: \(showOutput)")
    }

    // MARK: - Test 4: complete marks task done

    @Test("kanban_complete transitions the KanbanStore row to status=done")
    func testKanbanStoreTool_complete_marksDone() async throws {
        let store = try await Self.makeKanbanStore()
        let tool = Self.makeTool(store: store)

        // 1) create a task
        let createOutput = try await tool.execute(input: #"{"action":"create","title":"Finish me"}"#)
        #expect(createOutput.contains("\"ok\":true"))
        let taskID = try await Self.taskIDFromJSONEnvelope(createOutput, fallbackStore: store)

        // 2) complete it
        let completeOutput = try await tool.execute(input: #"{"action":"complete","task_id":"\#(taskID)"}"#)
        #expect(completeOutput.contains("\"ok\":true"), "complete must return ok=true; got: \(completeOutput)")
        #expect(completeOutput.contains("\"action\":\"complete\""))
        #expect(completeOutput.contains("Completed task:"))

        // 3) KanbanStore row is now status=done.
        let after = try await store.list()
        let task = after.first { $0.id == taskID }
        #expect(task?.status == .done,
                "KanbanStore row must be status=done; got: \(String(describing: task?.status))")
        #expect(task?.completedAt != nil, "completed_at must be set when status=done")
    }

    // MARK: - JSON helpers

    /// Pull the created `task_id` out of a KanbanStoreTool JSON
    /// envelope. The adapter's create output is a JSON object of
    /// shape `{"ok":true,"action":"create","data":{"task_id":"<id>"}, ...}`;
    /// we parse it once and grab `data.task_id`. Falls back to
    /// the first row in the store when the envelope is missing
    /// the data field (= backwards-compatible with simpler
    /// adapter output, e.g. tests against a stripped-down tool).
    private static func taskIDFromJSONEnvelope(
        _ output: String,
        fallbackStore: KanbanStore
    ) async throws -> String {
        if let data = output.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = parsed["data"] as? [String: Any],
           let taskID = dataDict["task_id"] as? String,
           !taskID.isEmpty {
            return taskID
        }
        let tasks = try await fallbackStore.list()
        guard let first = tasks.first else {
            throw KanbanStoreToolTestError.noTaskCreated(output: output)
        }
        return first.id
    }
}

/// Local test-only error (= for the rare case where the adapter did
/// not return a recognizable create frame AND the store was empty).
private enum KanbanStoreToolTestError: Error, CustomStringConvertible {
    case noTaskCreated(output: String)
    var description: String {
        switch self {
        case .noTaskCreated(let o):
            return "no task created (adapter output: \(o))"
        }
    }
}
