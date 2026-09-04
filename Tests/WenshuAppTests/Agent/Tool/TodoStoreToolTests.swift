//
//  TodoStoreToolTests.swift · Wenshu · P0 #4 (WIRE-AGENT-004)
//
//  Round-trip tests for the TodoStoreTool thin adapter. Each test
//  exercises the full path: LLM-supplied JSON input → HermesTodoTool
//  (= hermes-side state machine) → TodoStore (= wenshu-side canonical).
//
//  Test inventory (= 4 round-trip tests per spec):
//
//    1. testTodoStoreTool_create_persistsToTodoStore
//       (= create call → HermesTodoTool receives item → TodoStore row written)
//    2. testTodoStoreTool_list_returnsTodoStoreItems
//       (= TodoStore pre-seeded with 2 items → list returns JSON of 2 items)
//    3. testTodoStoreTool_complete_marksItemDone
//       (= create → complete → TodoStore row updated to status=completed)
//    4. testTodoStoreTool_remove_deletesItem
//       (= create → remove → TodoStore row gone + list returns 0 items)
//
//  All tests use a tmp-file TodoStore so they don't touch the user's
//  canonical ~/Library/Application Support/wenshu/todo.db.
//
//  Acceptance: `--filter "TodoStoreTool"` = 4/4 pass.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("TodoStoreTool adapter (P0 #4 / WIRE-AGENT-004)")
struct TodoStoreToolTests {

    // MARK: - Helpers

    /// Make a fresh TodoStore backed by a tmp file (= each test gets
    /// isolation; no cleanup race because we use a unique UUID per
    /// call and the OS reclaims tmp files on reboot).
    /// Async because TodoStore.bootstrap() is actor-isolated.
    private static func makeTodoStore() async throws -> TodoStore {
        let path = NSTemporaryDirectory() + "wenshu-todo-store-tool-\(UUID().uuidString).sqlite"
        let store = try TodoStore(path: path)
        try await store.bootstrap()
        return store
    }

    /// Make a fresh HermesTodoTool + HermesTodoStore pair (= hermes-side
    /// state machine that the adapter mirrors into TodoStore).
    private static func makeHermesTool() -> (HermesTodoTool, HermesTodoStore) {
        let hermesStore = HermesTodoStore()
        let tool = HermesTodoTool(store: hermesStore)
        return (tool, hermesStore)
    }

    // MARK: - Test 1: create persists to TodoStore

    @Test("todo_create persists the new item to TodoStore")
    func testTodoStoreTool_create_persistsToTodoStore() async throws {
        print("[TEST] step 1: makeTodoStore")
        let todoStore = try await Self.makeTodoStore()
        print("[TEST] step 2: makeHermesTool")
        let (hermesTool, hermesStore) = Self.makeHermesTool()
        print("[TEST] step 3: TodoStoreTool.init")
        let tool = TodoStoreTool(hermesTodo: hermesTool, todoStore: todoStore)

        // Sanity check: TodoStore actor works in isolation.
        print("[TEST] step 4: precheck list")
        let precheck = try await todoStore.list()
        print("[TEST] step 5: precheck done, count=\(precheck.count)")
        #expect(precheck.isEmpty, "fresh TodoStore must be empty; got \(precheck.count) rows")

        print("[TEST] step 6: tool.execute")
        let input = #"{"action":"create","id":"task-1","content":"Draft chapter 1","priority":2}"#
        let output = try await tool.execute(input: input)
        print("[TEST] step 7: tool.execute done, output=\(output)")

        // 1) adapter returned ok envelope
        #expect(output.contains("\"ok\":true"), "output must report ok=true; got: \(output)")
        #expect(output.contains("\"action\":\"create\""), "output must echo action=create; got: \(output)")
        #expect(output.contains("Draft chapter 1"), "output must echo content; got: \(output)")

        // 2) TodoStore has the new row
        let items = try await todoStore.list()
        #expect(items.count == 1, "TodoStore must hold 1 row after create; got \(items.count)")
        #expect(items.first?.title == "Draft chapter 1")
        #expect(items.first?.status == .pending)
        #expect(items.first?.priority == .high)  // priority 2 == high

        // 3) HermesTodoStore received the mirror (= merge-mode write)
        #expect(hermesStore.hasItems())
        let hermesItems = hermesStore.read()
        #expect(hermesItems.count == 1)
        #expect(hermesItems.first?.id == "task-1")
        #expect(hermesItems.first?.content == "Draft chapter 1")
        #expect(hermesItems.first?.status == .pending)
    }

    // MARK: - Test 2: list returns TodoStore items

    @Test("todo_list returns the canonical TodoStore items as JSON")
    func testTodoStoreTool_list_returnsTodoStoreItems() async throws {
        let todoStore = try await Self.makeTodoStore()
        let (hermesTool, _) = Self.makeHermesTool()
        let tool = TodoStoreTool(hermesTodo: hermesTool, todoStore: todoStore)

        // Pre-seed TodoStore with 2 items (= bypasses the adapter so
        // this test isolates the list path).
        _ = try await todoStore.add(title: "First item", priority: .high)
        _ = try await todoStore.add(title: "Second item", priority: .low)

        let output = try await tool.execute(input: #"{"action":"list"}"#)

        // Adapter must return 2 items
        #expect(output.contains("\"ok\":true"))
        #expect(output.contains("\"action\":\"list\""))
        #expect(output.contains("First item"), "output must include the first seeded item; got: \(output)")
        #expect(output.contains("Second item"), "output must include the second seeded item; got: \(output)")
        #expect(output.contains("\"count\":2"), "output must report count=2; got: \(output)")
    }

    // MARK: - Test 3: complete marks item done

    @Test("todo_complete updates the TodoStore row to status=completed")
    func testTodoStoreTool_complete_marksItemDone() async throws {
        let todoStore = try await Self.makeTodoStore()
        let (hermesTool, hermesStore) = Self.makeHermesTool()
        let tool = TodoStoreTool(hermesTodo: hermesTool, todoStore: todoStore)

        // 1) create an item
        let createInput = #"{"action":"create","id":"task-2","content":"Write outline"}"#
        let createOutput = try await tool.execute(input: createInput)
        #expect(createOutput.contains("\"ok\":true"))

        // 2) complete it
        let completeOutput = try await tool.execute(input: #"{"action":"complete","id":"task-2"}"#)
        #expect(completeOutput.contains("\"ok\":true"), "complete must return ok=true; got: \(completeOutput)")
        #expect(completeOutput.contains("\"action\":\"complete\""))
        #expect(completeOutput.contains("\"status\":\"completed\""))

        // 3) TodoStore row is now status=completed
        let items = try await todoStore.list()
        #expect(items.count == 1)
        #expect(items.first?.status == .completed, "TodoStore row must be status=completed; got: \(String(describing: items.first?.status))")

        // 4) hermes-side mirror also flipped to completed
        let hermesItems = hermesStore.read()
        #expect(hermesItems.first?.status == .completed)
    }

    // MARK: - Test 4: remove deletes item

    @Test("todo_remove deletes the TodoStore row")
    func testTodoStoreTool_remove_deletesItem() async throws {
        let todoStore = try await Self.makeTodoStore()
        let (hermesTool, hermesStore) = Self.makeHermesTool()
        let tool = TodoStoreTool(hermesTodo: hermesTool, todoStore: todoStore)

        // 1) create
        _ = try await tool.execute(input: #"{"action":"create","id":"task-3","content":"Throwaway task"}"#)
        let seeded = try await todoStore.list()
        #expect(seeded.count == 1)

        // 2) remove
        let removeOutput = try await tool.execute(input: #"{"action":"remove","id":"task-3"}"#)
        #expect(removeOutput.contains("\"ok\":true"), "remove must return ok=true; got: \(removeOutput)")
        #expect(removeOutput.contains("\"action\":\"remove\""))
        #expect(removeOutput.contains("\"removed\":true"))

        // 3) TodoStore row is gone (= list returns 0 items)
        let after = try await todoStore.list()
        #expect(after.isEmpty, "TodoStore must be empty after remove; got \(after.count) items")

        // 4) hermes-side mirror cancelled the item (= cancelled items
        //    are filtered out of formatForInjection so they no longer
        //    re-inject after context compression; this is the
        //    hermes-python "remove" semantic).
        let hermesItems = hermesStore.read()
        #expect(hermesItems.count == 1)
        #expect(hermesItems.first?.status == .cancelled)
    }
}
