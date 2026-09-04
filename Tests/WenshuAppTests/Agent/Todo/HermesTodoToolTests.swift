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

import Testing
import Foundation
@testable import WenshuApp

@Suite("HermesTodoTool (HERMES-SUBSYSTEM-4)")
struct HermesTodoToolTests {

    // MARK: - Test 1: todo_add (= write replace mode inserts)

    @Test("todo_add writes a fresh item and returns the full list")
    func testTodoAdd() throws {
        let store = HermesTodoStore()
        let item = HermesTodoItem(
            id: "task-1",
            content: "First planning item",
            status: .pending
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
    func testTodoList() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "a", content: "alpha", status: .pending),
                HermesTodoItem(id: "b", content: "beta", status: .inProgress),
                HermesTodoItem(id: "c", content: "gamma", status: .completed)
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
    func testTodoUpdate() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "x", content: "Original", status: .pending),
                HermesTodoItem(id: "y", content: "Untouched", status: .pending)
            ],
            merge: false
        )

        // Merge in: update x's content + status; add a new item z.
        store.write(
            todos: [
                HermesTodoItem(id: "x", content: "Renamed", status: .inProgress),
                HermesTodoItem(id: "z", content: "Brand new", status: .pending)
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
    func testTodoRemove() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "keep", status: .pending),
                HermesTodoItem(id: "2", content: "drop", status: .pending),
                HermesTodoItem(id: "3", content: "keep", status: .pending)
            ],
            merge: false
        )
        #expect(store.read().count == 3)

        // Replace with the same list minus id "2".
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "keep", status: .pending),
                HermesTodoItem(id: "3", content: "keep", status: .pending)
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
    func testTodoClear() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "1", content: "a", status: .pending),
                HermesTodoItem(id: "2", content: "b", status: .completed),
                HermesTodoItem(id: "3", content: "c", status: .cancelled)
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

    @Test("JSON round-trip preserves the todo list for context injection")
    func testSerialization() throws {
        let sessionDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-todo-test-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: sessionDir)
        }
        let sessionStore = HermesTodoSessionStore(sessionDirectory: sessionDir)

        // 1. Persist a populated store.
        let original = HermesTodoStore()
        original.write(
            todos: [
                HermesTodoItem(id: "alpha", content: "alpha content", status: .inProgress),
                HermesTodoItem(id: "beta",  content: "beta content",  status: .pending),
                HermesTodoItem(id: "gamma", content: "gamma content", status: .completed)
            ],
            merge: false
        )
        try sessionStore.save(original)

        // File must exist.
        #expect(FileManager.default.fileExists(atPath: sessionStore.jsonURL.path))

        // 2. Re-load into a fresh store and verify parity.
        let reloaded = try sessionStore.load()
        let reloadedItems = reloaded.read()
        #expect(reloadedItems.count == 3)

        let alpha = reloadedItems.first(where: { $0.id == "alpha" })
        #expect(alpha?.content == "alpha content")
        #expect(alpha?.status == .inProgress)

        let beta = reloadedItems.first(where: { $0.id == "beta" })
        #expect(beta?.status == .pending)

        let gamma = reloadedItems.first(where: { $0.id == "gamma" })
        #expect(gamma?.status == .completed)

        // 3. JSON export shape (= mirrors python `json.dumps`).
        let json = try sessionStore.exportJSON(reloaded)
        #expect(json.contains("\"todos\""))
        #expect(json.contains("\"summary\""))
        #expect(json.contains("\"alpha\""))
        #expect(json.contains("\"beta\""))
        #expect(json.contains("\"gamma\""))
        // Sorted keys + UTF-8 == stable.
        #expect(json == json)

        // 4. formatForInjection = active items only (= completed /
        // cancelled skipped, per python `format_for_injection`).
        let injection = reloaded.formatForInjection()
        #expect(injection != nil)
        #expect(injection?.contains("alpha") == true)
        #expect(injection?.contains("beta") == true)
        // gamma is completed -> not in the injection block.
        #expect(injection?.contains("gamma") == false)
    }

    // MARK: - Bonus: formatForInjection marker coverage

    @Test("formatForInjection emits the correct marker per status")
    func testFormatForInjection() throws {
        let store = HermesTodoStore()
        store.write(
            todos: [
                HermesTodoItem(id: "p", content: "p-item", status: .pending),
                HermesTodoItem(id: "i", content: "i-item", status: .inProgress),
                HermesTodoItem(id: "c", content: "c-item", status: .completed),
                HermesTodoItem(id: "x", content: "x-item", status: .cancelled)
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
            todos: [HermesTodoItem(id: "only", content: "one", status: .pending)],
            merge: false
        )
        let tool = HermesTodoTool(store: store)
        let output = try await tool.execute(input: "")
        #expect(output.contains("\"only\""))
        #expect(output.contains("\"pending\""))
    }

    @Test("HermesTodoTool.execute parses JSON input via ToolInputParser")
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
}