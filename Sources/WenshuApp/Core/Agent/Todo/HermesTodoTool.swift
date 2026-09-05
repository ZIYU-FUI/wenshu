//
//  HermesTodoTool.swift · Wenshu · HERMES-SUBSYSTEM-4 (ticket 026 step 4)
//
//  HERMES-SUBSYSTEM-4 (todo) FULL 1:1 port of /Volumes/ANAN/.hermes/tools/
//  todo_tool.py (330 LOC). This is the LLM internal planning list (= the
//  agent's scratchpad that lives on AIAgent and is re-injected after
//  context compression). NOT the wenshu-side user-facing persisted
//  todo (= TodoStore.swift / BookTodoStore.swift), which is kept intact
//  per boss wenshu-side-wins pattern.
//
//  Boss 2026-09-04 OOB: 'Subsystem 4 -- hermes todo,要走 hermes' (=
//  override earlier SKIP, AGENTS.md §11.3 default = port hermes as-is).
//
//  ------------------------------------------------------------------------
//  Divergence vs. earlier ticket draft (= §4.1 hermes inventory says
//  "5 status + 4 priority"):
//
//    Hermes Python todo_tool.py has FOUR statuses (pending,
//    in_progress, completed, cancelled) and NO priority field. The
//    "5 status + 4 priority" surface described in some internal
//    sketches came from a draft that conflated wenshu's local
//    TodoStatus / TodoPriority with the hermes source. We port the
//    actual hermes source (= 1:1 = real source wins over notes):
//
//      - statuses: pending | in_progress | completed | cancelled
//      - NO priority, NO dueDate, NO tags (= hermes is flat: id +
//        content + status)
//
//    Wenshu's TodoStore / BookTodoStore (= the user-facing tracker)
//    keep their richer surface untouched (per boss wenshu-side
//    wins pattern, see TodoStore.swift header).
//
//  ------------------------------------------------------------------------
//  API surface (= mirrors Python todo_tool.py, line-for-line):
//
//    TodoStore
//      init()
//      write(todos: merge: false) -> [Item]   (replace or update-by-id)
//      read() -> [Item]
//      hasItems() -> Bool
//      formatForInjection() -> String?        (post-compression re-inject)
//      validate(_:)                          (static)
//      capContent(_:)                        (static)
//      dedupeByID(_:)                        (static)
//
//    todoTool(todos: merge: store:) -> String
//      (= single entry point, JSON-encoded result; python todo_tool)
//
//    TODO_SCHEMA  (= Swift mirror of OpenAI function-calling schema)
//
//  ------------------------------------------------------------------------
//  Bounds (= mirrors Python module-level constants):
//
//    maxTodoContentChars = 4_000
//    maxTodoItems        = 256
//    maxTodoResultChars  = 512_000
//    truncationMarker    = "… [truncated]"
//
//  ------------------------------------------------------------------------
//  Context-injection persistence (= wenshu-side):
//
//    Hermes Python keeps the todo on the AIAgent instance in memory
//    only. Wenshu has no AIAgent runtime (= the agent loop lives in
//    subagent shells); we persist to a lightweight per-session JSON
//    blob (`hermes-todo.json` under Application Support / wenshu /
//    sessions / <sessionId> /). This is the same model Hermes uses
//    when re-injecting after context compression: the JSON is
//    decoded back into a TodoStore on session resume. See
//    `HermesTodoSessionStore.load / save`.
//
//  ------------------------------------------------------------------------
//  Standards-axis S3 (= single source of truth for tool input JSON):
//  tool input parsing goes through ToolInputParser (same as
//  ReadFileTool / WriteFileTool).
//
//  Standards-axis S4 (= no new third-party deps): pure Foundation + the
//  existing WenshuApp module surface. No SQLite, no external libs.
//

import Foundation

// MARK: - Module-level bounds (= mirrors todo_tool.py module header)

/// Valid status values for todo items (= mirrors Python `VALID_STATUSES`).
public enum HermesTodoStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled

    /// Whether this status is "active" for the post-compression
    /// re-injection block. Completed / cancelled items are skipped
    /// (= otherwise the model re-does finished work after compression,
    /// see Python `format_for_injection`).
    public var isActive: Bool {
        switch self {
        case .pending, .inProgress: return true
        case .completed, .cancelled: return false
        }
    }

    /// Compact marker shown in `formatForInjection` output.
    public var injectionMarker: String {
        switch self {
        case .completed:  return "[x]"
        case .inProgress: return "[>]"
        case .pending:    return "[ ]"
        case .cancelled:  return "[~]"
        }
    }
}

/// Upper bound on a single todo item's content (= mirrors
/// `MAX_TODO_CONTENT_CHARS`). A single huge item would otherwise
/// inflate the post-compression re-injection block without bound.
public let maxTodoContentChars = 4_000

/// Upper bound on the total todo list size (= mirrors
/// `MAX_TODO_ITEMS`). List order is priority, so truncation keeps the
/// head (= highest-priority items).
public let maxTodoItems = 256

/// Upper bound on a single todo tool-result payload accepted during
/// history hydration (= mirrors `MAX_TODO_RESULT_CHARS`). The
/// gateway/API server replays caller-supplied conversation history to
/// rebuild the store, so an oversized forged result is dropped before
/// it is parsed and re-injected (see Python comment).
public let maxTodoResultChars = 512_000

/// Marker appended to truncated todo content (= mirrors Python
/// `_TRUNCATION_MARKER`).
public let truncationMarker = "… [truncated]"

// MARK: - HermesTodoItem (= mirrors Python {_id, _content, _status} dict)

/// A single todo entry in the LLM internal planning list.
///
/// Mirrors the python dict (`{id, content, status}`). Pure value type
/// for `Sendable` / `Codable` round-trips; the owning actor /
/// `HermesTodoSessionStore` is responsible for mutation.
public struct HermesTodoItem: Codable, Sendable, Equatable, Hashable {
    public var id: String
    public var content: String
    public var status: HermesTodoStatus

    public init(id: String, content: String, status: HermesTodoStatus) {
        self.id = id
        self.content = content
        self.status = status
    }

    /// Convenience initializer from the python dict shape (= accepts
    /// Any for parity with the LLM-supplied tool input).
    public init(fromAny raw: Any) {
        if let d = raw as? [String: Any] {
            self.id = HermesTodoItem.stringValue(d["id"]) ?? "?"
            self.content = HermesTodoStore.capContent(HermesTodoItem.stringValue(d["content"]) ?? "")
            self.status = HermesTodoStatus(rawValue: HermesTodoItem.stringValue(d["status"])?.lowercased() ?? "") ?? .pending
        } else {
            self.id = "?"
            self.content = HermesTodoStore.capContent("")
            self.status = .pending
        }
    }

    private static func stringValue(_ v: Any?) -> String? {
        guard let v = v else { return nil }
        if let s = v as? String { return s }
        return "\(v)"
    }

    /// `[id, content, status]` ordered tuple (= mirrors the python
    /// dict shape for JSON serialization).
    public func asOrderedDict() -> [String: String] {
        [
            "id": id,
            "content": content,
            "status": status.rawValue
        ]
    }
}

// MARK: - HermesTodoStore (= mirrors Python TodoStore class)

/// In-memory todo list. One instance per session (= the python
/// AIAgent-equivalent on wenshu is the per-session JSON store, see
/// `HermesTodoSessionStore`).
///
/// Items are ordered -- list position is priority. Each item has:
///   - id: unique string identifier (agent-chosen)
///   - content: task description
///   - status: pending | in_progress | completed | cancelled
public final class HermesTodoStore: @unchecked Sendable {
    /// Serial queue protecting `items`. We use a serial queue (not a
    /// concurrent barrier queue) because the public surface mixes
    /// read + write on the same `items` storage from multiple call
    /// sites (= `read` is called from inside `write`'s tail, and
    /// `formatForInjection` snapshots then filters off-queue). A
    /// serial queue's `.sync` is re-entrant from the same thread when
    /// NOT nested through another `.sync` -- but to avoid the
    /// lock-recursion deadlock the previous NSLock implementation
    /// exhibited (NSLock is non-recursive in Swift; `write` returned
    /// `read()` while still holding the lock), we extract the
    /// post-mutation snapshot inside the lock-protected block and
    /// return it directly. The queue is never re-entered from inside
    /// a synchronized block, so there is no recursion risk.
    private let queue = DispatchQueue(label: "com.wenshu.HermesTodoStore")
    private var items: [HermesTodoItem]

    public init(items: [HermesTodoItem] = []) {
        self.items = items
    }

    // MARK: - write (= mirrors Python `TodoStore.write`)

    /// Write todos. Returns the full current list after writing.
    ///
    /// - `merge=false` (default): replace the entire list.
    /// - `merge=true`: update existing items by id and append new ones.
    @discardableResult
    public func write(todos: [HermesTodoItem], merge: Bool = false) -> [HermesTodoItem] {
        return queue.sync {
            if !merge {
                // Replace mode: new list entirely.
                let deduped = HermesTodoStore.dedupeByID(todos)
                items = deduped.map { HermesTodoStore.validate($0) }
            } else {
                // Merge mode: update existing items by id, append new ones.
                var existing: [String: HermesTodoItem] = [:]
                for item in items {
                    existing[item.id] = item
                }
                let deduped = HermesTodoStore.dedupeByID(todos)
                for raw in deduped {
                    let itemId = raw.id.trimmingCharacters(in: .whitespacesAndNewlines)
                    if itemId.isEmpty { continue }  // can't merge without id

                    if var existingItem = existing[itemId] {
                        // Update only the fields the LLM actually provided.
                        // (`HermesTodoItem` is fully formed, but we honour
                        // `merge` semantics: don't replace with empty
                        // content or unknown status.)
                        if !raw.content.isEmpty {
                            existingItem.content = HermesTodoStore.capContent(raw.content.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        let lowered = raw.status.rawValue
                        if HermesTodoStatus(rawValue: lowered) != nil {
                            existingItem.status = raw.status
                        }
                        existing[itemId] = existingItem
                    } else {
                        // New item -- validate fully and append to end.
                        let validated = HermesTodoStore.validate(raw)
                        existing[validated.id] = validated
                        items.append(validated)
                    }
                }
                // Rebuild `items` preserving order for existing items
                // (= mirrors Python rebuild loop).
                var seen = Set<String>()
                var rebuilt: [HermesTodoItem] = []
                for item in items {
                    let current = existing[item.id] ?? item
                    if !seen.contains(current.id) {
                        rebuilt.append(current)
                        seen.insert(current.id)
                    }
                }
                items = rebuilt
            }

            // Bound total item count so a replayed/oversized list can't
            // grow the re-injection block without limit. Keep the
            // highest-priority head (list order is priority).
            if items.count > maxTodoItems {
                items = Array(items.prefix(maxTodoItems))
            }
            // Return the post-mutation snapshot directly (no nested
            // `read()` call -- avoids the NSLock recursion deadlock
            // that bit the previous implementation).
            return items
        }
    }

    // MARK: - read (= mirrors Python `TodoStore.read`)

    /// Return a copy of the current list.
    public func read() -> [HermesTodoItem] {
        return queue.sync { items }
    }

    /// Whether the list has any items (= mirrors `has_items`).
    public func hasItems() -> Bool {
        return queue.sync { !items.isEmpty }
    }

    // MARK: - formatForInjection (= mirrors Python)

    /// Render the todo list for post-compression injection.
    ///
    /// Returns a human-readable string to append to the compressed
    /// message history, or nil if the list has no active items
    /// (= completed / cancelled items are skipped, otherwise the
    /// model re-does finished work after compression).
    public func formatForInjection() -> String? {
        let snapshot = queue.sync { items }
        let activeItems = snapshot.filter { $0.status.isActive }
        guard !activeItems.isEmpty else { return nil }

        var lines = ["[Your active task list was preserved across context compression]"]
        for item in activeItems {
            let marker = item.status.injectionMarker
            lines.append("- \(marker) \(item.id). \(item.content) (\(item.status.rawValue))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - validate / capContent / dedupeByID (= mirrors Python @staticmethod helpers)

    /// Validate and normalize a todo item. Returns a clean item with
    /// sane defaults (= mirrors Python `_validate`).
    public static func validate(_ raw: HermesTodoItem) -> HermesTodoItem {
        var id = raw.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty { id = "?" }

        var content = raw.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            content = "(no description)"
        } else {
            content = capContent(content)
        }

        let status: HermesTodoStatus
        if let parsed = HermesTodoStatus(rawValue: raw.status.rawValue) {
            status = parsed
        } else {
            status = .pending
        }

        return HermesTodoItem(id: id, content: content, status: status)
    }

    /// Truncate oversized todo content to `maxTodoContentChars`
        /// (= mirrors Python `_cap_content`).
    public static func capContent(_ content: String) -> String {
        if content.count > maxTodoContentChars {
            let keep = maxTodoContentChars - truncationMarker.count
            let head = String(content.prefix(keep))
            return head + truncationMarker
        }
        return content
    }

    /// Collapse duplicate ids, keeping the last occurrence in its
        /// position (= mirrors Python `_dedupe_by_id`).
    public static func dedupeByID(_ todos: [HermesTodoItem]) -> [HermesTodoItem] {
        var lastIndex: [String: Int] = [:]
        for (i, item) in todos.enumerated() {
            let key = item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "__invalid_\(i)"
                : item.id
            lastIndex[key] = i
        }
        return lastIndex.values.sorted().map { todos[$0] }
    }
}

// MARK: - todoTool entry point (= mirrors Python `todo_tool`)

/// Result payload returned by `todoTool` -- mirrors the python
/// `json.dumps({...})` output.
public struct HermesTodoToolResult: Codable, Sendable, Equatable {
    public var todos: [HermesTodoItem]
    public var summary: HermesTodoSummary

    public init(todos: [HermesTodoItem], summary: HermesTodoSummary) {
        self.todos = todos
        self.summary = summary
    }
}

public struct HermesTodoSummary: Codable, Sendable, Equatable {
    public var total: Int
    public var pending: Int
    public var inProgress: Int
    public var completed: Int
    public var cancelled: Int

    public init(total: Int, pending: Int, inProgress: Int, completed: Int, cancelled: Int) {
        self.total = total
        self.pending = pending
        self.inProgress = inProgress
        self.completed = completed
        self.cancelled = cancelled
    }
}

/// Single entry point for the todo tool (= mirrors Python `todo_tool`).
///
/// - `todos`: if provided, write these items. If nil, read the current list.
/// - `merge`: if true, update by id. If false (default), replace the entire list.
/// - `store`: the `HermesTodoStore` instance from the session.
///
/// Returns a JSON-encoded `HermesTodoToolResult`.
public func hermesTodoTool(
    todos: [HermesTodoItem]? = nil,
    merge: Bool = false,
    store: HermesTodoStore
) throws -> HermesTodoToolResult {
    let items: [HermesTodoItem]
    if let supplied = todos {
        items = store.write(todos: supplied, merge: merge)
    } else {
        items = store.read()
    }

    let summary = HermesTodoSummary(
        total: items.count,
        pending: items.filter { $0.status == .pending }.count,
        inProgress: items.filter { $0.status == .inProgress }.count,
        completed: items.filter { $0.status == .completed }.count,
        cancelled: items.filter { $0.status == .cancelled }.count
    )

    return HermesTodoToolResult(todos: items, summary: summary)
}

/// Convenience: throw `ToolExecutorError` on failure (= mirrors
/// Python `tool_error` registry return).
public func hermesTodoToolJSONString(
    todos: [HermesTodoItem]? = nil,
    merge: Bool = false,
    store: HermesTodoStore
) throws -> String {
    let result = try hermesTodoTool(todos: todos, merge: merge, store: store)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(result)
    return String(data: bytes, encoding: .utf8) ?? "{}"
}

// MARK: - HermesTodoTool (= Tool conformance for wenshu's ToolExecutor)

/// `Tool` conformance wrapping `hermesTodoTool` (= so the wenshu
/// `ToolExecutor` can dispatch it identically to ReadFileTool /
/// WriteFileTool / etc.). The LLM hands a JSON tool_use block to
/// `ToolExecutor`, which routes to `execute(input:)`.
///
/// Input shape (= mirrors Python `TODO_SCHEMA.parameters`):
///   {
///     "todos": [{id, content, status}, ...]? ,
///     "merge": Bool (default false)
///   }
///
/// Output: JSON-encoded `HermesTodoToolResult`.
public struct HermesTodoTool: Tool, Sendable {
    private let store: HermesTodoStore

    public init(store: HermesTodoStore) {
        self.store = store
    }

    public func execute(input: String) async throws -> String {
        // Empty input == read (= mirrors Python "omit todos to read").
        let parsed: [String: Any]
        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parsed = [:]
        } else {
            parsed = try ToolInputParser.parseDictionary(input: input)
        }

        var todos: [HermesTodoItem]? = nil
        if let raw = parsed["todos"] {
            // Guard: LLM sometimes sends todos as a JSON string instead
            // of a list (= mirrors Python isinstance check).
            let arr: [Any]
            if let s = raw as? String {
                guard let data = s.data(using: .utf8),
                      let decoded = try? JSONSerialization.jsonObject(with: data),
                      let list = decoded as? [Any] else {
                    throw ToolExecutorError.invalidInput(
                        name: "todo",
                        reason: "todos must be a list of objects, got unparseable string"
                    )
                }
                arr = list
            } else if let list = raw as? [Any] {
                arr = list
            } else {
                throw ToolExecutorError.invalidInput(
                    name: "todo",
                    reason: "todos must be a list, got \(type(of: raw))"
                )
            }
            todos = arr.map { HermesTodoItem(fromAny: $0) }
        }

        let merge: Bool = (parsed["merge"] as? Bool) ?? false

        return try hermesTodoToolJSONString(todos: todos, merge: merge, store: store)
    }
}

// MARK: - TODO_SCHEMA (= mirrors Python TODO_SCHEMA)

/// OpenAI function-calling schema for the `todo` tool (= mirrors
/// Python `TODO_SCHEMA`). Behavioral guidance is baked into the
/// description so it's part of the static tool schema (cached, never
/// changes mid-conversation).
public enum HermesTodoSchema {
    public static let name = "todo"

    public static let description = """
    Manage your task list for the current session. Use for complex tasks \
    with 3+ steps or when the user provides multiple tasks. \
    Call with no parameters to read the current list.

    Writing:
    - Provide 'todos' array to create/update items
    - merge=false (default): replace the entire list with a fresh plan
    - merge=true: update existing items by id, add any new ones

    Each item: {id: string, content: string, \
    status: pending|in_progress|completed|cancelled}
    List order is priority. Only ONE item in_progress at a time.
    Mark items completed immediately when done. If something fails, \
    cancel it and add a revised item.

    Always returns the full current list.
    """

    // `nonisolated(unsafe)` because the value is a static, immutable
    // schema dictionary (= never mutated after init); Swift 6's strict
    // concurrency checker still flags `[String: Any]` as non-Sendable
    // even on a static let.
    public nonisolated(unsafe) static let parametersSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "todos": [
                "type": "array",
                "description": "Task items to write. Omit to read current list.",
                "items": [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "Unique item identifier"
                        ],
                        "content": [
                            "type": "string",
                            "description": "Task description"
                        ],
                        "status": [
                            "type": "string",
                            "enum": ["pending", "in_progress", "completed", "cancelled"],
                            "description": "Current status"
                        ]
                    ],
                    "required": ["id", "content", "status"]
                ]
            ],
            "merge": [
                "type": "boolean",
                "description": (
                    "true: update existing items by id, add new ones. "
                    + "false (default): replace the entire list."
                ),
                "default": false
            ]
        ],
        "required": []
    ]
}

// MARK: - HermesTodoSessionStore (= wenshu-side persistence)

/// Per-session JSON persistence for `HermesTodoStore` (= wenshu has
/// no AIAgent runtime, so we persist the LLM scratchpad to disk and
/// reload on session resume; this is the same model Hermes uses when
/// re-injecting after context compression).
///
/// File: `<session-dir>/hermes-todo.json`
public struct HermesTodoSessionStore: Sendable {
    public let sessionDirectory: URL

    public init(sessionDirectory: URL) {
        self.sessionDirectory = sessionDirectory
    }

    public var jsonURL: URL {
        sessionDirectory.appendingPathComponent("hermes-todo.json")
    }

    /// Load the persisted todo list (= or an empty store if no file).
    public func load() throws -> HermesTodoStore {
        let url = jsonURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return HermesTodoStore()
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let items = try decoder.decode([HermesTodoItem].self, from: data)
        return HermesTodoStore(items: items)
    }

    /// Save the current todo list atomically.
    public func save(_ store: HermesTodoStore) throws {
        let items = store.read()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(items)
        try FileManager.default.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true
        )
        try atomicWrite(bytes)
    }

    /// Export the full current todo state as a JSON string (= for
        /// context injection payloads).
    public func exportJSON(_ store: HermesTodoStore) throws -> String {
        let items = store.read()
        let result = HermesTodoToolResult(
            todos: items,
            summary: HermesTodoSummary(
                total: items.count,
                pending: items.filter { $0.status == .pending }.count,
                inProgress: items.filter { $0.status == .inProgress }.count,
                completed: items.filter { $0.status == .completed }.count,
                cancelled: items.filter { $0.status == .cancelled }.count
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(result)
        return String(data: bytes, encoding: .utf8) ?? "{}"
    }

    private func atomicWrite(_ data: Data) throws {
        let tmpURL = jsonURL.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: .atomic)
        if FileManager.default.fileExists(atPath: jsonURL.path) {
            try FileManager.default.removeItem(at: jsonURL)
        }
        try FileManager.default.moveItem(at: tmpURL, to: jsonURL)
    }
}

// MARK: - check_todo_requirements (= mirrors Python `check_todo_requirements`)

/// Todo tool has no external requirements -- always available.
/// (= mirrors Python `check_todo_requirements`.)
public func hermesCheckTodoRequirements() -> Bool { true }