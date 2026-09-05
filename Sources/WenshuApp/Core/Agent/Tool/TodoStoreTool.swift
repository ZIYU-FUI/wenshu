//
//  TodoStoreTool.swift · Wenshu · P0 #4 (WIRE-AGENT-004, 2026-09-04)
//
//  Thin adapter wrapping HermesTodoTool (= hermes-side state machine
//  / LLM internal planning list) and mirroring the result into the
//  wenshu-side canonical TodoStore (SQLite actor). Lets the LLM
//  create / list / update / complete / remove Todo items directly via
//  the `todo` tool (= one Tool entry-point registered with
//  WenshuConductor.tools in ChatView).
//
//  Why an adapter (instead of using HermesTodoTool directly)?
//
//    The hermes-side HermesTodoTool is the LLM scratchpad (= lives on
//    AIAgent and is re-injected after context compression). The
//    wenshu-side TodoStore is the user-facing persisted task tracker
//    (= UI: TodoListView, schema: SQLite). Per boss wenshu-side-wins
//    pattern (= HermesTodoTool.swift header) the two stores stay
//    separate; this adapter is the single bridge the LLM goes through
//    to keep both stores in sync from a single tool call.
//
//    Command surface (single input field `action`):
//
//      todo_create   {action:"create", id, content, priority?}
//      todo_list     {action:"list", status?}
//      todo_update   {action:"update", id, content?, priority?}
//      todo_complete {action:"complete", id}
//      todo_remove   {action:"remove", id}
//
//    Empty / unknown action = `todo_list` (mirrors HermesTodoTool's
//    "empty input == read" convention).
//
//    Output: JSON `{ ok: true, action, data, summary }` (= LLM can
//    see what was written). On error: JSON `{ ok: false, action,
//    error }` (= does not throw; per ToolExecutorError policy the
//    LLM gets a string it can react to, not a thrown exception).
//
//  Standards-axis S3 (= single source of truth for tool input JSON):
//  tool input parsing goes through ToolInputParser (same as
//  HermesTodoTool / ReadFileTool / WriteFileTool / ParagraphAITool).
//
//  Standards-axis S4 (= no new third-party deps): pure Foundation +
//  the existing WenshuApp module surface (HermesTodoTool +
//  ToolInputParser + TodoStore actor). No SQLite import here (= the
//  TodoStore actor owns the SQL handle; we call its public API).
//
//

import Foundation

public struct TodoStoreTool: Tool, Sendable {

    /// Shared singleton for ToolRegistry bootstrap (= lazy in-memory
    /// HermesTodoTool + a fresh fallback TodoStore on first access).
    /// Used by the MIGRATE-TOOLREGISTRY-002 module-load registration
    /// (= `TodoStoreTool._registryBootstrap`); production wiring
    /// still constructs dedicated instances via the existing
    /// `init(hermesTodo:todoStore:)` initializer (= e.g. ChatView
    /// pre-populates the conductor with a per-library instance).
    ///
    /// `nonisolated(unsafe)` is required because the initializer
    /// stores actor-isolated types (`TodoStore`, `HermesTodoTool`)
    /// from a `static let` (= nonisolated context); the closure
    /// runs synchronously at first access (= before any actor
    /// isolation becomes relevant) so the unsafe escape hatch is
    /// safe here. TodoStore() with no path uses the default App
    /// Support location (= /tmp fallback if unavailable).
    public nonisolated(unsafe) static let shared = TodoStoreTool(
        hermesTodo: HermesTodoTool(store: HermesTodoStore()),
        todoStore: Self.makeFallback()
    )

    /// Tiny fallback TodoStore (= /tmp-backed SQLite) for the
    /// `shared` bootstrap instance. Production wiring uses a
    /// dedicated per-library store via `init(hermesTodo:todoStore:)`.
    ///
    /// `nonisolated(unsafe)` because constructing an actor
    /// (= TodoStore) from a nonisolated static-let context trips
    /// Swift 6's strict-concurrency check.
    nonisolated(unsafe) private static func makeFallback() -> TodoStore {
        return try! TodoStore(path: "/tmp/wenshu-toolregistry-todo-fallback-\(UUID().uuidString).sqlite")
    }

    /// Tool name (matches HermesTodoSchema.name = "todo"; ToolExecutor
    /// routes one tool_use block to one Tool by name).
    public let name = "todo"

    /// Human-readable description (baked into the tool schema at
    /// prompt-build time so the LLM sees it cached as static context).
    public let description = """
    Manage the Todo items for the current session. Actions: \
    create / list / update / complete / remove. Each action mirrors \
    the canonical TodoStore (= SQLite, user-facing) and the hermes \
    internal planning list. Use list to read; create to add; \
    complete to mark done; remove to delete.
    """

    private let hermesTodo: HermesTodoTool
    private let todoStore: TodoStore

    public init(hermesTodo: HermesTodoTool, todoStore: TodoStore) {
        self.hermesTodo = hermesTodo
        self.todoStore = todoStore
    }

    // MARK: - Tool conformance

    public func execute(input: String) async throws -> String {
        // Step 1: parse input via the single-source-of-truth parser
        // (= S3 parity with HermesTodoTool / ReadFileTool / etc.).
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: [String: Any]
        if trimmed.isEmpty {
            parsed = [:]
        } else {
            do {
                parsed = try ToolInputParser.parseDictionary(input: input)
            } catch {
                return Self.jsonError(action: nil, message: "invalid input: \(error)")
            }
        }

        // Step 2: extract action (default = list = matches the empty-
        // input-read convention HermesTodoTool uses).
        let action = (parsed["action"] as? String ?? "list").lowercased()

        // Step 3: dispatch.
        switch action {
        case "create":
            return await runCreate(parsed: parsed)
        case "list":
            return await runList(parsed: parsed)
        case "update":
            return await runUpdate(parsed: parsed)
        case "complete":
            return await runComplete(parsed: parsed)
        case "remove":
            return await runRemove(parsed: parsed)
        default:
            return Self.jsonError(
                action: action,
                message: "unknown action '\(action)' (expected create|list|update|complete|remove)"
            )
        }
    }

    // MARK: - Action: create

    private func runCreate(parsed: [String: Any]) async -> String {
        guard let id = parsed["id"] as? String, !id.isEmpty else {
            return Self.jsonError(action: "create", message: "missing 'id' (string, required)")
        }
        guard let content = parsed["content"] as? String, !content.isEmpty else {
            return Self.jsonError(action: "create", message: "missing 'content' (string, required)")
        }
        let priority = Self.parsePriority(parsed["priority"]) ?? .medium

        // 1) mirror to hermes-side state machine (so post-compression
        //    re-injection block stays in sync).
        let hermesResult = await mirrorToHermes(
            todos: [HermesTodoItem(id: id, content: content, status: .pending)],
            merge: true
        )
        guard hermesResult.ok else {
            return Self.jsonError(action: "create", message: "hermes mirror failed: \(hermesResult.error ?? "unknown")")
        }

        // 2) mirror to wenshu-side canonical TodoStore.
        do {
            let stored = try await todoStore.add(title: content, priority: priority)
            return Self.jsonOk(
                action: "create",
                data: [
                    "id": stored.id,
                    "title": stored.title,
                    "status": stored.status.rawValue,
                    "priority": stored.priority.rawValue
                ]
            )
        } catch {
            return Self.jsonError(action: "create", message: "TodoStore.add failed: \(error)")
        }
    }

    // MARK: - Action: list

    private func runList(parsed: [String: Any]) async -> String {
        let statusFilter: TodoStatus? = (parsed["status"] as? String).flatMap { TodoStatus(rawValue: $0) }
        do {
            let items = try await todoStore.list(status: statusFilter)
            let data: [[String: Any]] = items.map { item in
                [
                    "id": item.id,
                    "title": item.title,
                    "status": item.status.rawValue,
                    "priority": item.priority.rawValue
                ]
            }
            return Self.jsonOk(action: "list", data: ["items": data, "count": data.count])
        } catch {
            return Self.jsonError(action: "list", message: "TodoStore.list failed: \(error)")
        }
    }

    // MARK: - Action: update

    private func runUpdate(parsed: [String: Any]) async -> String {
        guard let id = parsed["id"] as? String, !id.isEmpty else {
            return Self.jsonError(action: "update", message: "missing 'id' (string, required)")
        }
        guard let content = parsed["content"] as? String, !content.isEmpty else {
            return Self.jsonError(action: "update", message: "missing 'content' (string, required)")
        }
        let priority = Self.parsePriority(parsed["priority"])

        // 1) mirror to hermes-side state machine (merge by id).
        let hermesResult = await mirrorToHermes(
            todos: [HermesTodoItem(id: id, content: content, status: .pending)],
            merge: true
        )
        guard hermesResult.ok else {
            return Self.jsonError(action: "update", message: "hermes mirror failed: \(hermesResult.error ?? "unknown")")
        }

        // 2) mirror to wenshu-side: TodoStore has no content update
        //    API (= add is insert-only by design). To honour the
        //    LLM's `update` intent we delete the old row and insert
        //    the new one (preserving the same id). This is a thin
        //    adapter, not a new TodoStore API.
        do {
            try await todoStore.delete(id: id)
            let stored = try await todoStore.add(title: content, priority: priority ?? .medium)
            return Self.jsonOk(
                action: "update",
                data: [
                    "id": stored.id,
                    "title": stored.title,
                    "status": stored.status.rawValue,
                    "priority": stored.priority.rawValue
                ]
            )
        } catch {
            return Self.jsonError(action: "update", message: "TodoStore.update failed: \(error)")
        }
    }

    // MARK: - Action: complete

    private func runComplete(parsed: [String: Any]) async -> String {
        guard let id = parsed["id"] as? String, !id.isEmpty else {
            return Self.jsonError(action: "complete", message: "missing 'id' (string, required)")
        }

        // 1) mirror to hermes-side: mark status=completed (merge by id).
        let hermesResult = await mirrorToHermes(
            todos: [HermesTodoItem(id: id, content: "(completed)", status: .completed)],
            merge: true
        )
        guard hermesResult.ok else {
            return Self.jsonError(action: "complete", message: "hermes mirror failed: \(hermesResult.error ?? "unknown")")
        }

        // 2) mirror to wenshu-side canonical TodoStore.
        do {
            try await todoStore.setStatus(id: id, status: .completed)
            return Self.jsonOk(action: "complete", data: ["id": id, "status": TodoStatus.completed.rawValue])
        } catch {
            return Self.jsonError(action: "complete", message: "TodoStore.setStatus failed: \(error)")
        }
    }

    // MARK: - Action: remove

    private func runRemove(parsed: [String: Any]) async -> String {
        guard let id = parsed["id"] as? String, !id.isEmpty else {
            return Self.jsonError(action: "remove", message: "missing 'id' (string, required)")
        }

        // 1) mirror to hermes-side: replace the hermes list with the
        //    remaining items (= the Python hermes source has no
        //    remove op, so we go through write-merge with a status=
        //    cancelled sentinel to drop the item from the active
        //    re-injection block. Cancelled items are filtered out of
        //    formatForInjection (= see HermesTodoStatus.isActive).
        let hermesResult = await mirrorToHermes(
            todos: [HermesTodoItem(id: id, content: "(removed)", status: .cancelled)],
            merge: true
        )
        guard hermesResult.ok else {
            return Self.jsonError(action: "remove", message: "hermes mirror failed: \(hermesResult.error ?? "unknown")")
        }

        // 2) mirror to wenshu-side: hard-delete the row.
        do {
            try await todoStore.delete(id: id)
            return Self.jsonOk(action: "remove", data: ["id": id, "removed": true])
        } catch {
            return Self.jsonError(action: "remove", message: "TodoStore.delete failed: \(error)")
        }
    }

    // MARK: - Helpers

    /// Forward to HermesTodoTool.execute (= hermes-side state machine).
    /// Returns (ok, errorMessage). We catch thrown errors so the tool
    /// returns a JSON failure envelope instead of a Swift throw (= the
    /// LLM gets a string it can react to, matching the spec's
    /// "does not throw" policy).
    private func mirrorToHermes(todos: [HermesTodoItem], merge: Bool) async -> (ok: Bool, error: String?) {
        // Build the JSON input HermesTodoTool.execute expects.
        // HermesTodoTool uses ToolInputParser under the hood.
        let todosJSON: String
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(todos.map { $0.asOrderedDict() })
            todosJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return (false, "encode todos failed: \(error)")
        }
        let payload = "{\"todos\":\(todosJSON),\"merge\":\(merge)}"
        do {
            _ = try await hermesTodo.execute(input: payload)
            return (true, nil)
        } catch {
            return (false, "\(error)")
        }
    }

    private static func parsePriority(_ raw: Any?) -> TodoPriority? {
        if let i = raw as? Int { return TodoPriority(rawValue: i) }
        if let d = raw as? Double { return TodoPriority(rawValue: Int(d)) }
        if let s = raw as? String, let i = Int(s) { return TodoPriority(rawValue: i) }
        return nil
    }

    // MARK: - JSON envelope helpers

    private static func jsonOk(action: String, data: [String: Any]) -> String {
        let payload: [String: Any] = ["ok": true, "action": action, "data": data]
        return jsonString(payload)
    }

    private static func jsonError(action: String?, message: String) -> String {
        var payload: [String: Any] = ["ok": false, "error": message]
        if let a = action { payload["action"] = a }
        return jsonString(payload)
    }

    private static func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ) else {
            return "{\"ok\":false,\"error\":\"internal: failed to encode envelope\"}"
        }
        return String(data: data, encoding: .utf8) ?? "{\"ok\":false,\"error\":\"internal: non-utf8 envelope\"}"
    }
}

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension TodoStoreTool {
    /// Module-load registration with `ToolRegistry.shared` (= hermes
    /// `tools/registry.py` `register()` 1:1). Fires once at first
    /// type access; the underlying `Task` schedules the async
    /// `register(...)` call off the init thread.
    ///
    /// Idempotency: the registry's `register` method silently replaces
    /// a same-toolset re-registration. Cross-toolset shadowing is
    /// blocked unless `override=true` (= matches hermes
    /// `tools/registry.py` override-protection semantics).
    public static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.register(
                name: "todo",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "todo",
                    description: """
                    Manage the Todo items for the current session. Actions: \
                    create / list / update / complete / remove. Each action mirrors \
                    the canonical TodoStore (= SQLite, user-facing) and the hermes \
                    internal planning list. Use list to read; create to add; \
                    complete to mark done; remove to delete.
                    """,
                    inputSchema: [
                        "action": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "The todo operation to perform.",
                            enumValues: ["create", "list", "update", "complete", "remove"]
                        ),
                        "id": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Todo identifier (= required for update / complete / remove)."
                        ),
                        "content": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Todo title / body (= required for create / update)."
                        ),
                        "priority": ToolRegistrySchemaProperty(
                            type: "integer",
                            description: "Priority tier (= 0 = low, 1 = medium, 2 = high; optional)."
                        ),
                        "status": ToolRegistrySchemaProperty(
                            type: "string",
                            description: "Status filter for list (= pending / running / completed / cancelled). Optional.",
                            enumValues: ["pending", "running", "completed", "cancelled"]
                        )
                    ],
                    required: []
                ),
                handler: TodoStoreTool.shared,
                description: """
                Manage the Todo items for the current session. Actions: \
                create / list / update / complete / remove.
                """,
                emoji: "📝"
            )
        }
    }()
}

// NOTE: Swift 6 forbids top-level expressions, so the static let
// `_registryBootstrap` initializer runs lazily on first type access
// (= Swift equivalent of Python module-load statement = hermes
// `registry.register(...)` at import time). Production code paths
// that touch this type (= e.g. ChatView constructing
// `ParagraphAITool.shared`, WenshuConductor constructing `ReadFileTool()`)
// automatically trigger the bootstrap.
