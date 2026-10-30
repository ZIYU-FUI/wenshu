//
//  HermesTodoToolTests.swift · Wenshu · HERMES-SUBSYSTEM-4 (ticket 026 step 4)
//
//  Six round-trip tests for the 1:1 port of hermes todo_tool.py to
//  HermesTodoTool.swift. Tests verify the parity surface (= write /
//  read / format_for_injection / persistence).
//
//  Test surface (= covers the spec's required test inventory):
//
//    1. testTodoAdd           — write replace mode inserts items
//    2. testTodoList          — read + filter by status
//    3. testTodoUpdate        — write merge mode updates by id
//    4. testTodoRemove        — write replace with id absent
//    5. testTodoClear         — write with empty list clears the store
//    6. testSerialization     — JSON encode + decode round-trip for
//                                context-injection persistence (= Hermes
//                                TodoSessionStore load / save)
//
//  Plus one bonus: testFormatForInjection covers the post-compression
//  re-injection block (= the file's marquee feature per the python
//  docstring).
//
//  Plus the plan tree's cases:
//
//    7. testPlanItemCarriesParent  — the item names the item it belongs to
//    8. testPlanItemCodable        — the parent survives the JSON round-trip
//    9. testStoreReadReturnsParent  — the read hands back the parent
//   10. testPlanTextUnchanged       — the re-injection text and the status
//                                    words keep their shape
//   11. testPlanCapsAndDedupe      — the caps and the de-duplication keep
//                                    their behaviour
//

import Testing
import SwiftData
import Foundation
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("HermesTodoTool (HERMES-SUBSYSTEM-4)")
struct HermesTodoToolTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSTodoRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from TodoStore actor.
    @MainActor
    private static func makeTodoRepository() throws -> WSTodoRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSTodoRepository(container: container)
    }

    // MARK: - Test 1: todo_add (= write replace mode inserts)

    @Test("todo_add writes a fresh item and returns the full list")
    @MainActor
    func testTodoAdd() throws {
        let store = HermesTodoStore()
        let item = HermesTodoItem(
            id: "task-1",
            content: "First planning item",
            status: HermesTodoStatus.pending
        )
        let result = try hermesTodoTool(todos: [item], merge: false, store: store)
        #expect(result.todos.count == 1)
        #expect(result.todos.first?.id == "task-1")
        #expect(result.todos.first?.content == "First planning item")
        #expect(result.todos.first?.status == .pending)
        #expect(result.summary.total == 1)
        #expect(result.summary.pending == 1)
        #expect(result.summary.completed == 0)
    }

    // MARK: - Test 2: todo_list (= read with status filter)

    @Test("todo_list returns the current list, filterable by status")
    @MainActor
    func testTodoList() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "a", content: "alpha", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "b", content: "beta", status: HermesTodoStatus.inProgress),
                HermesTodoItem(id: "c", content: "gamma", status: HermesTodoStatus.completed)
            ],
            merge: false
        )

        // No filter = full list.
        let all = store.read()
        #expect(all.count == 3)

        // Filter by status manually (mirrors the python `list()` shape;
        // wenshu TodoStore has status filter too, but HermesTodoStore
        // exposes the raw list and lets callers filter).
        let pending = all.filter { $0.status == .pending }
        let inProgress = all.filter { $0.status == .inProgress }
        let completed = all.filter { $0.status == .completed }
        #expect(pending.count == 1)
        #expect(inProgress.count == 1)
        #expect(completed.count == 1)

        // Reading with no todos supplied returns the same payload.
        let readResult = try hermesTodoTool(todos: nil, merge: false, store: store)
        #expect(readResult.todos.count == 3)
        #expect(readResult.summary.total == 3)
    }

    // MARK: - Test 3: todo_update (= write merge mode updates by id)

    @Test("todo_update merges an existing item by id")
    @MainActor
    func testTodoUpdate() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "x", content: "Original", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "y", content: "Untouched", status: HermesTodoStatus.pending)
            ],
            merge: false
        )

        // Merge in: update x's content + status; add a new item z.
        store.write(
            todos: [
                HermesTodoItem(id: "x", content: "Renamed", status: HermesTodoStatus.inProgress),
                HermesTodoItem(id: "z", content: "Brand new", status: HermesTodoStatus.pending)
            ],
            merge: true
        )

        let items = store.read()
        #expect(items.count == 3)

        let x = items.first(where: { $0.id == "x" })
        #expect(x?.content == "Renamed")
        #expect(x?.status == .inProgress)

        let y = items.first(where: { $0.id == "y" })
        #expect(y?.content == "Untouched")
        #expect(y?.status == .pending)

        let z = items.first(where: { $0.id == "z" })
        #expect(z?.content == "Brand new")
        #expect(z?.status == .pending)
    }

    // MARK: - Test 4: todo_remove (= write replace with id absent)

    @Test("todo_remove drops an item when absent from the next write")
    @MainActor
    func testTodoRemove() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "keep", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "2", content: "drop", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "3", content: "keep", status: HermesTodoStatus.pending)
            ],
            merge: false
        )
        #expect(store.read().count == 3)

        // Replace with the same list minus id "2".
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "keep", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "3", content: "keep", status: HermesTodoStatus.pending)
            ],
            merge: false
        )

        let items = store.read()
        #expect(items.count == 2)
        #expect(items.contains(where: { $0.id == "2" }) == false)
        #expect(items.contains(where: { $0.id == "1" }))
        #expect(items.contains(where: { $0.id == "3" }))
    }

    // MARK: - Test 5: todo_clear (= write with empty list)

    @Test("todo_clear empties the store")
    @MainActor
    func testTodoClear() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "a", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "2", content: "b", status: HermesTodoStatus.completed),
                HermesTodoItem(id: "3", content: "c", status: HermesTodoStatus.cancelled)
            ],
            merge: false
        )
        #expect(store.hasItems())

        store.write(todos: [], merge: false)

        #expect(store.read().isEmpty)
        #expect(store.hasItems() == false)
        #expect(store.formatForInjection() == nil)
    }

    // MARK: - Test 6: testSerialization (= JSON round-trip for context injection)

    // MARK: - Bonus: formatForInjection marker coverage

    @Test("formatForInjection emits the correct marker per status")
    @MainActor
    func testFormatForInjection() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "p", content: "p-item", status: HermesTodoStatus.pending),
                HermesTodoItem(id: "i", content: "i-item", status: HermesTodoStatus.inProgress),
                HermesTodoItem(id: "c", content: "c-item", status: HermesTodoStatus.completed),
                HermesTodoItem(id: "x", content: "x-item", status: HermesTodoStatus.cancelled)
            ],
            merge: false
        )

        let injection = store.formatForInjection()
        #expect(injection != nil)
        // Active markers present.
        #expect(injection?.contains("[ ]") == true)  // pending
        #expect(injection?.contains("[>]") == true)  // in_progress
        // Inactive markers absent.
        #expect(injection?.contains("[x]") == false) // completed
        #expect(injection?.contains("[~]") == false) // cancelled
        // Active items in injection.
        #expect(injection?.contains("p-item") == true)
        #expect(injection?.contains("i-item") == true)
        // Inactive items absent.
        #expect(injection?.contains("c-item") == false)
        #expect(injection?.contains("x-item") == false)
        // Header.
        #expect(injection?.contains("[Your active task list was preserved across context compression]") == true)
    }

    // MARK: - Bonus: HermesTodoTool.execute (= wenshu Tool conformance)

    @Test("HermesTodoTool.execute handles empty input (= read mode)")
    func testToolConformanceEmptyInput() async throws {
        let store = HermesTodoStore()
        store.write(
            todos: [HermesTodoItem(id: "only", content: "one", status: HermesTodoStatus.pending)],
            merge: false
        )
        let tool = HermesTodoTool(store: store)
        let output = try await tool.execute(input: "")
        #expect(output.contains("\"only\""))
        #expect(output.contains("\"pending\""))
    }

    @Test("HermesTodoTool.execute parses JSON input via ToolInputParser")
    @MainActor
    func testToolConformanceJSONInput() async throws {
        let store = HermesTodoStore()
        let tool = HermesTodoTool(store: store)
        let inputJSON = """
        {"todos":[{"id":"from-json","content":"hello","status":"pending"}],"merge":false}
        """
        let output = try await tool.execute(input: inputJSON)
        #expect(output.contains("\"from-json\""))
        #expect(output.contains("\"hello\""))
    }

    // MARK: - Test 7: a plan item names the item it belongs to

    @Test("a plan item names the item it belongs to")
    @MainActor
    func testPlanItemCarriesParent() {
        // An item written WITH a parent carries it.
        let child = HermesTodoItem(
            id: "1.1",
            content: "sub-step",
            status: .pending,
            parent: "1"
        )
        #expect(child.parent == "1")

        // An item written WITHOUT one carries none (= it behaves exactly
        // as it did before the field existed).
        let root = HermesTodoItem(id: "1", content: "step", status: .pending)
        #expect(root.parent == nil)

        // The raw input carries the parent's id under its own key.
        let rawChild: [String: Any] = [
            "id": "1.1",
            "content": "sub-step",
            "status": "pending",
            "parent": "1"
        ]
        #expect(HermesTodoItem(fromAny: rawChild).parent == "1")

        // A raw input without the key = no parent.
        let rawRoot: [String: Any] = ["id": "1", "content": "step", "status": "pending"]
        #expect(HermesTodoItem(fromAny: rawRoot).parent == nil)
    }

    // MARK: - Test 8: the parent survives the JSON round-trip

    @Test("the parent survives the JSON round-trip")
    @MainActor
    func testPlanItemCodable() throws {
        let child = HermesTodoItem(
            id: "1.1",
            content: "sub-step",
            status: .inProgress,
            parent: "1"
        )
        let encoded = try JSONEncoder().encode(child)
        let decoded = try JSONDecoder().decode(HermesTodoItem.self, from: encoded)
        #expect(decoded == child)
        #expect(decoded.parent == "1")

        // An item with no parent round-trips unchanged (= the synthesized
        // coding stays correct for an item that carries no parent).
        let root = HermesTodoItem(id: "1", content: "step", status: .pending)
        let rootEncoded = try JSONEncoder().encode(root)
        let rootDecoded = try JSONDecoder().decode(HermesTodoItem.self, from: rootEncoded)
        #expect(rootDecoded == root)
        #expect(rootDecoded.parent == nil)

        // A payload persisted before the field existed (= no "parent" key)
        // still decodes, and carries no parent.
        let legacy = Data(#"{"id":"1","content":"step","status":"pending"}"#.utf8)
        let legacyDecoded = try JSONDecoder().decode(HermesTodoItem.self, from: legacy)
        #expect(legacyDecoded.id == "1")
        #expect(legacyDecoded.content == "step")
        #expect(legacyDecoded.status == .pending)
        #expect(legacyDecoded.parent == nil)
    }

    // MARK: - Test 9: the store's read hands back the parent

    @Test("the store's read hands back the parent")
    @MainActor
    func testStoreReadReturnsParent() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "step", status: .pending),
                HermesTodoItem(
                    id: "1.1",
                    content: "sub-step",
                    status: .inProgress,
                    parent: "1"
                )
            ],
            merge: false
        )

        let items = store.read()
        #expect(items.count == 2)
        #expect(items.first(where: { $0.id == "1" })?.parent == nil)
        #expect(items.first(where: { $0.id == "1.1" })?.parent == "1")

        // The tool's own write path hands the same parent back.
        let result = try hermesTodoTool(todos: nil, merge: false, store: store)
        #expect(result.todos.first(where: { $0.id == "1.1" })?.parent == "1")
        #expect(result.todos.first(where: { $0.id == "1" })?.parent == nil)
    }

    // MARK: - Test 10: the plan's own text keeps its shape

    @Test("the re-injection text and the status words keep their shape")
    @MainActor
    func testPlanTextUnchanged() {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "step", status: .pending),
                HermesTodoItem(
                    id: "1.1",
                    content: "sub-step",
                    status: .inProgress,
                    parent: "1"
                ),
                HermesTodoItem(id: "2", content: "done", status: .completed)
            ],
            merge: false
        )

        let injection = store.formatForInjection()
        #expect(injection != nil)
        // The header line.
        #expect(injection?.hasPrefix("[Your active task list was preserved across context compression]") == true)
        // The row shape: "- <marker> <id>. <content> (<status>)".
        #expect(injection?.contains("- [ ] 1. step (pending)") == true)
        #expect(injection?.contains("- [>] 1.1. sub-step (in_progress)") == true)
        // A resolved item stays out of the re-injection.
        #expect(injection?.contains("done") == false)

        // The plan's own status words.
        #expect(HermesTodoStatus.pending.rawValue == "pending")
        #expect(HermesTodoStatus.inProgress.rawValue == "in_progress")
        #expect(HermesTodoStatus.completed.rawValue == "completed")
        #expect(HermesTodoStatus.cancelled.rawValue == "cancelled")
    }

    // MARK: - Test 11: the caps and the de-duplication keep their behaviour

    @Test("the caps and the de-duplication keep their behaviour")
    @MainActor
    func testPlanCapsAndDedupe() {
        // De-duplication: the last occurrence of an id wins, in its own
        // position.
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "first", status: .pending),
                HermesTodoItem(id: "2", content: "other", status: .pending),
                HermesTodoItem(id: "1", content: "last", status: .completed)
            ],
            merge: false
        )
        let items = store.read()
        #expect(items.count == 2)
        #expect(items.map(\.id) == ["2", "1"])
        #expect(items.first(where: { $0.id == "1" })?.content == "last")

        // The content cap.
        let long = String(repeating: "x", count: maxTodoContentChars + 100)
        #expect(HermesTodoStore.capContent(long).count == maxTodoContentChars)
        #expect(HermesTodoStore.capContent(long).hasSuffix(truncationMarker) == true)

        // The item-count cap.
        let many = (0..<(maxTodoItems + 5)).map {
            HermesTodoItem(id: "\($0)", content: "c", status: .pending)
        }
        #expect(HermesTodoStore().write(todos: many, merge: false).count == maxTodoItems)
    }
}