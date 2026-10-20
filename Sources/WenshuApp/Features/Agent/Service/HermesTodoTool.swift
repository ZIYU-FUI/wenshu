// 
// … (= 73 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuAgent
import WenshuData

// NOTE: HermesTodoTool wraps HermesTodoStore (= in-memory DispatchQueue store).
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Valid status values for todo items (= mirrors Python `VALID_STATUSES`).
enum HermesTodoStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case inProgress = "in_progress"
    case completed
    case cancelled

    // / Whether this status is "active" for the post-compression
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / see Python `format_for_injection`).
    var isActive: Bool {
        switch self {
        case .pending, .inProgress: return true
        case .completed, .cancelled: return false
        }
    }

    /// Compact marker shown in `formatForInjection` output.
    var injectionMarker: String {
        switch self {
        case .completed:  return "[x]"
        case .inProgress: return "[>]"
        case .pending:    return "[ ]"
        case .cancelled:  return "[~]"
        }
    }
}

// / Upper bound on a single todo item's content (= mirrors
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / inflate the post-compression re-injection block without bound.
let maxTodoContentChars = 4_000

// / Upper bound on the total todo list size (= mirrors
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / head (= highest-priority items).
let maxTodoItems = 256

// / Upper bound on a single todo tool-result payload accepted during
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / it is parsed and re-injected (see Python comment).
let maxTodoResultChars = 512_000

/// Marker appended to truncated todo content (= mirrors Python
/// `_TRUNCATION_MARKER`).
let truncationMarker = "… [truncated]"

// MARK: - HermesTodoItem (= mirrors Python {_id, _content, _status} dict)
// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `HermesTodoSessionStore` is responsible for mutation.
struct HermesTodoItem: Codable, Sendable, Equatable, Hashable {
    var id: String
    var content: String
    var status: HermesTodoStatus

    init(id: String, content: String, status: HermesTodoStatus) {
        self.id = id
        self.content = content
        self.status = status
    }

    /// Convenience initializer from the python dict shape (= accepts
    /// Any for parity with the LLM-supplied tool input).
    init(fromAny raw: Any) {
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
    func asOrderedDict() -> [String: String] {
        [
            "id": id,
            "content": content,
            "status": status.rawValue
        ]
    }
}

// MARK: - HermesTodoStore (= mirrors Python TodoStore class)
// … (= 7 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /   - status: pending | in_progress | completed | cancelled
final class HermesTodoStore: @unchecked Sendable {
    // / Serial queue protecting `items`. We use a serial queue (not a
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / a synchronized block, so there is no recursion risk.
    private let queue = DispatchQueue(label: "com.wenshu.HermesTodoStore")
    private var items: [HermesTodoItem]

    init(items: [HermesTodoItem] = []) {
        self.items = items
    }

    // MARK: - write (= mirrors Python `TodoStore.write`)
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / - `merge=true`: update existing items by id and append new ones.
    @discardableResult
    func write(todos: [HermesTodoItem], merge: Bool = false) -> [HermesTodoItem] {
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
                        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // highest-priority head (list order is priority).
            if items.count > maxTodoItems {
                items = Array(items.prefix(maxTodoItems))
            }
            // Return the post-mutation snapshot directly (no nested
            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // that bit the previous implementation).
            return items
        }
    }

    // MARK: - read (= mirrors Python `TodoStore.read`)

    /// Return a copy of the current list.
    func read() -> [HermesTodoItem] {
        return queue.sync { items }
    }

    /// Whether the list has any items (= mirrors `has_items`).
    func hasItems() -> Bool {
        return queue.sync { !items.isEmpty }
    }

    // MARK: - formatForInjection (= mirrors Python)
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / model re-does finished work after compression).
    func formatForInjection() -> String? {
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
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / sane defaults (= mirrors Python `_validate`).
    static func validate(_ raw: HermesTodoItem) -> HermesTodoItem {
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
    static func capContent(_ content: String) -> String {
        if content.count > maxTodoContentChars {
            let keep = maxTodoContentChars - truncationMarker.count
            let head = String(content.prefix(keep))
            return head + truncationMarker
        }
        return content
    }

    /// Collapse duplicate ids, keeping the last occurrence in its
        /// position (= mirrors Python `_dedupe_by_id`).
    static func dedupeByID(_ todos: [HermesTodoItem]) -> [HermesTodoItem] {
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
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / `json.dumps({...})` output.
struct HermesTodoToolResult: Codable, Sendable, Equatable {
    var todos: [HermesTodoItem]
    var summary: HermesTodoSummary

    init(todos: [HermesTodoItem], summary: HermesTodoSummary) {
        self.todos = todos
        self.summary = summary
    }
}

struct HermesTodoSummary: Codable, Sendable, Equatable {
    var total: Int
    var pending: Int
    var inProgress: Int
    var completed: Int
    var cancelled: Int

    init(total: Int, pending: Int, inProgress: Int, completed: Int, cancelled: Int) {
        self.total = total
        self.pending = pending
        self.inProgress = inProgress
        self.completed = completed
        self.cancelled = cancelled
    }
}

// / Single entry point for the todo tool (= mirrors Python `todo_tool`).
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Returns a JSON-encoded `HermesTodoToolResult`.
func hermesTodoTool(
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
func hermesTodoToolJSONString(
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
// … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / Output: JSON-encoded `HermesTodoToolResult`.
struct HermesTodoTool: Tool, Sendable {
    // / Shared singleton for ToolRegistry bootstrap (= lazy in-memory
    // … (= 13 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // HermesTodoTool.swift L87 #warning.
    nonisolated static let shared: HermesTodoTool = HermesTodoTool(store: HermesTodoStore())

    private let store: HermesTodoStore

    init(store: HermesTodoStore) {
        self.store = store
    }

    func execute(input: String) async throws -> String {
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

// MARK: - ToolRegistry bootstrap (MIGRATE-TOOLREGISTRY-002)

extension HermesTodoTool {
    // / Module-load registration with `ToolRegistry.shared` (= hermes
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / wenshu-side TodoStoreTool `todo` (= same domain, different layer).
    static let _registryBootstrap: Void = {
        Task {
            await ToolRegistry.shared.registerTool(
                name: "todo_hermes",
                toolset: "agent",
                schema: ToolRegistrySchema(
                    name: "todo_hermes",
                    description: "Hermes-side internal todo list (= LLM scratchpad that survives context compression via re-injection).",
                    inputSchema: [
                        "todos": ToolRegistrySchemaProperty(
                            type: "array",
                            description: "Todo items to write (= array of {id, content, status} objects). Omit to read the current list."
                        ),
                        "merge": ToolRegistrySchemaProperty(
                            type: "boolean",
                            description: "When true (= default false), merge by id with the existing list; when false, replace the list."
                        )
                    ],
                    required: []
                ),
                handler: HermesTodoTool.shared,
                description: "Hermes-side internal todo list (= LLM scratchpad).",
                emoji: "🧠"
            )
        }
    }()
}

// MARK: - HermesTodoSessionStore (= wenshu-side persistence)
// … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / File: `<session-dir>/hermes-todo.json`
struct HermesTodoSessionStore: Sendable {
    let sessionDirectory: URL

    init(sessionDirectory: URL) {
        self.sessionDirectory = sessionDirectory
    }

    var jsonURL: URL {
        sessionDirectory.appendingPathComponent("hermes-todo.json")
    }

    /// Load the persisted todo list (= or an empty store if no file).
    func load() throws -> HermesTodoStore {
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
    func save(_ store: HermesTodoStore) throws {
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
    func exportJSON(_ store: HermesTodoStore) throws -> String {
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
