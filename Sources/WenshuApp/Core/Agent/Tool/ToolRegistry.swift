//
//  ToolRegistry.swift · Wenshu · v0.40 PORT-TOOLREGISTRY-001
//
//  1:1 Swift port of hermes `tools/registry.py` (= 766 LOC).
//
//  Source of truth:
//    /Volumes/ANAN/.hermes/tools/registry.py
//  Spec:
//    .scratch/2026-09-05-v0-40-toolregistry-port-spec.md
//
//  The hermes implementation = thread-safe singleton (`threading.RLock`).
//  Swift equivalent = `actor` (= compiler-enforced serialized mutation).
//
//  Surface (mirrors hermes):
//    - `ToolRegistrySchema` (= JSON-schema-style tool declaration;
//      renamed from the spec sketch `ToolSchema` because a file-internal
//      `MemoryProvider.ToolSchema` already exists; per the spec hard
//      rule "DO NOT remove any existing public surface", we keep the
//      existing one untouched and use a registry-scoped name here).
//    - `ToolRegistrySchemaProperty` (= single property in the schema).
//    - `ToolEntry` (= metadata for one registered tool; 10 fields).
//    - `ToolRegistry` (= `actor` singleton; `register` with override
//      protection, `getDefinitions` for LLM, `getHandler` for dispatch,
//      `generation` counter for cache invalidation, `clear` +
//      `deregister` for testing + MCP dynamic refresh).
//
//  Out of scope (per spec):
//    - AST-based auto-discovery (= hermes Python has this via stdlib
//      `ast`; Swift would need SwiftSyntax lib = new dep = deferred to
//      separate ticket).
//    - check_fn TTL cache + transient-failure suppression (= hermes-
//      specific Python detail; Swift actor model does not need it).
//    - Migration of existing 12 wenshu tool registrations to
//      `ToolRegistry.shared.register(...)` (= separate ticket
//      MIGRATE-TOOLREGISTRY-002).
//
//  Hard rules (per spec):
//    - English-only in all files.
//    - No new third-party dependency.
//    - No removal of existing `Tool` protocol public surface.
//    - Additive only.
//

import Foundation

// MARK: - ToolRegistrySchema

/// JSON-schema-style declaration of one tool (= hermes `ToolEntry.schema`).
///
/// Mirrors the OpenAI `function` tool shape: name + description +
/// input properties + required-field list. `inputSchema` keys = property
/// names, values = `ToolRegistrySchemaProperty`.
public struct ToolRegistrySchema: Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: [String: ToolRegistrySchemaProperty]
    public let required: [String]

    public init(
        name: String,
        description: String,
        inputSchema: [String: ToolRegistrySchemaProperty] = [:],
        required: [String] = []
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.required = required
    }

    /// Render to a JSON-compatible dictionary (= hermes
    /// `schema_with_name` in `get_definitions`).
    public func toJSON() -> [String: Any] {
        var props: [String: Any] = [:]
        for (key, prop) in inputSchema {
            props[key] = prop.toJSON()
        }
        var json: [String: Any] = [
            "name": name,
            "description": description
        ]
        if !props.isEmpty {
            json["parameters"] = [
                "type": "object",
                "properties": props,
                "required": required
            ]
        }
        return json
    }
}

// MARK: - ToolRegistrySchemaProperty

/// Single property in a `ToolRegistrySchema.inputSchema` (= hermes
/// property objects inside the `properties` map).
///
/// `type` = "string" | "number" | "boolean" | "array" | "object".
/// `enumValues` populated only when the value is a closed enum
/// (= hermes uses `enum` arrays in JSON Schema).
public struct ToolRegistrySchemaProperty: Sendable, Codable, Equatable {
    public let type: String
    public let description: String
    public let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }

    public init(
        type: String,
        description: String,
        enumValues: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }

    /// Render to a JSON-compatible dictionary.
    public func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "type": type,
            "description": description
        ]
        if let enumValues {
            json["enum"] = enumValues
        }
        return json
    }
}

// MARK: - ToolEntry

/// Metadata for a single registered tool (= hermes `ToolEntry`).
///
/// 10 fields, mirroring hermes 1:1 minus `handler` (= replaced by
/// `handlerID` — a stable identifier for the handler slot; wenshu
/// tools are mostly `struct`-based so we wrap them in a class-bound
/// `HandlerBox` to give `ObjectIdentifier` a stable key) and minus
/// `dynamic_schema_overrides` (= Python-specific dynamic re-binding;
/// Swift actor model makes this simpler: re-register with the new
/// schema if config changes).
public struct ToolEntry: Sendable {
    public let name: String
    public let toolset: String
    public let schema: ToolRegistrySchema
    /// Stable identifier for the handler slot (= `ObjectIdentifier` of
    /// the internal `HandlerBox` holding the `any Tool` instance). Use
    /// `registry.getHandler(name:)` to retrieve the live handler.
    public let handlerID: ObjectIdentifier
    /// Optional availability check (= hermes `check_fn`). When
    /// `nil`, the tool is always available. When set, called
    /// synchronously at `getDefinitions` time.
    public let checkFn: (@Sendable () -> Bool)?
    public let requiresEnv: [String]
    public let isAsync: Bool
    public let description: String
    public let emoji: String
    public let maxResultSizeChars: Int?

    public init(
        name: String,
        toolset: String,
        schema: ToolRegistrySchema,
        handlerID: ObjectIdentifier,
        checkFn: (@Sendable () -> Bool)? = nil,
        requiresEnv: [String] = [],
        isAsync: Bool = true,
        description: String,
        emoji: String,
        maxResultSizeChars: Int? = nil
    ) {
        self.name = name
        self.toolset = toolset
        self.schema = schema
        self.handlerID = handlerID
        self.checkFn = checkFn
        self.requiresEnv = requiresEnv
        self.isAsync = isAsync
        self.description = description
        self.emoji = emoji
        self.maxResultSizeChars = maxResultSizeChars
    }

    /// Manual `Equatable` (= closure field `checkFn` cannot be auto-
    /// synthesized). Excludes `checkFn` from comparison (= hermes
    /// treats two entries with the same metadata as equal regardless
    /// of the check callable identity).
    public static func == (lhs: ToolEntry, rhs: ToolEntry) -> Bool {
        lhs.name == rhs.name
            && lhs.toolset == rhs.toolset
            && lhs.schema == rhs.schema
            && lhs.handlerID == rhs.handlerID
            && lhs.requiresEnv == rhs.requiresEnv
            && lhs.isAsync == rhs.isAsync
            && lhs.description == rhs.description
            && lhs.emoji == rhs.emoji
            && lhs.maxResultSizeChars == rhs.maxResultSizeChars
    }
}

// MARK: - HandlerBox

/// Class wrapper that gives a `any Tool` existential a stable identity
/// (= `ObjectIdentifier`). Necessary because `Tool` is implemented by
/// value types like `ReadFileTool` (`struct`), and `ObjectIdentifier`
/// requires class-bound references.
private final class HandlerBox: @unchecked Sendable {
    let id: ObjectIdentifier
    let handler: any Tool

    init(handler: any Tool) {
        // Allocate a tiny marker class per box; the marker is the
        // stable ObjectIdentifier key. `ObjectIdentifier(self)` would
        // require both stored properties to be set first, which
        // creates a chicken-and-egg initialization problem. The
        // marker is held only inside this stored property; once the
        // box is constructed, it is never accessed again.
        self.handler = handler
        self.id = ObjectIdentifier(HandlerBoxIdentity())
    }
}

/// Marker class used to give each `HandlerBox` a unique
/// `ObjectIdentifier`. Allocated once per registered tool; held only
/// inside the box's `id` property.
private final class HandlerBoxIdentity: Sendable {}

// MARK: - ToolRegistry

/// Singleton registry that collects tool schemas + handlers (= hermes
/// `ToolRegistry`).
///
/// Thread-safe via Swift `actor` isolation (= compiler-enforced
/// serialized mutation; equivalent to hermes `threading.RLock`).
///
/// Override protection (mirrors hermes `register()` L356-448):
///   - If a tool with the same name is already registered under a
///     different toolset AND `override=false`, the new registration
///     is rejected (= stored `lastRegisterError`, state unchanged).
///     This prevents accidental shadowing of built-in tools by
///     plugins / MCP servers.
///   - If `override=true`, the new registration replaces the existing
///     entry.
///   - If the new registration matches the existing toolset, it
///     always replaces silently (= re-registration by the same owner
///     is idempotent).
///
/// Generation counter (mirrors hermes `_generation`): bumped on every
/// mutation (= `register`, `deregister`, `clear`). External callers
/// can key their memoization on `generation()` (= equivalent of hermes
/// cache invalidation on registry mutation).
public actor ToolRegistry {

    /// Module-level singleton (= hermes `registry = ToolRegistry()`).
    public static let shared = ToolRegistry()

    // MARK: - State

    /// Schema + metadata per tool name.
    private var _tools: [String: ToolEntry] = [:]
    /// Stable handler storage: `ObjectIdentifier` of the `HandlerBox`
    /// (= class identity) → live handler. Separated from `_tools` so
    /// `ToolEntry` can be `Sendable`.
    private var _handlers: [ObjectIdentifier: HandlerBox] = [:]
    /// Monotonic mutation counter (= hermes `_generation`).
    private var _generation: Int = 0
    /// Last-register error message (= tests inspect this; nil = clean).
    private var _lastRegisterError: String?

    // MARK: - Init

    public init() {}

    // MARK: - Register (= hermes `register()` L356-448)

    /// Register a tool (= hermes `register()`).
    ///
    /// Called at module-import time by each tool file. `override=true`
    /// is the explicit opt-in for plugins that intend to replace an
    /// existing built-in tool implementation. Without it, registrations
    /// that would shadow an existing tool from a different toolset are
    /// rejected to prevent accidental overwrites.
    public func register(
        name: String,
        toolset: String,
        schema: ToolRegistrySchema,
        handler: any Tool,
        checkFn: (@Sendable () -> Bool)? = nil,
        requiresEnv: [String] = [],
        isAsync: Bool = true,
        description: String = "",
        emoji: String = "",
        maxResultSizeChars: Int? = nil,
        override: Bool = false
    ) {
        // Override protection (= hermes L380-426).
        if let existing = _tools[name], existing.toolset != toolset {
            if !override {
                // Reject shadowing.
                _lastRegisterError = "Tool '\(name)' (toolset '\(toolset)') would shadow existing tool from toolset '\(existing.toolset)'. Pass override=true to register() if the replacement is intentional, or deregister the existing tool first."
                return
            }
            _lastRegisterError = nil
        } else {
            _lastRegisterError = nil
        }

        // Wrap handler in a class box so we can key by identity. If an
        // entry already exists for this name, we drop the old handler
        // box when no other tool references it.
        let box = HandlerBox(handler: handler)
        if let oldEntry = _tools[name] {
            let stillReferenced = _tools.values.contains {
                $0.name != name && $0.handlerID == oldEntry.handlerID
            }
            if !stillReferenced {
                _handlers.removeValue(forKey: oldEntry.handlerID)
            }
        }
        _handlers[box.id] = box

        // Resolve description from schema if caller passed empty
        // (= hermes L435: `description or schema.get("description", "")`).
        let resolvedDescription = description.isEmpty ? schema.description : description

        _tools[name] = ToolEntry(
            name: name,
            toolset: toolset,
            schema: schema,
            handlerID: box.id,
            checkFn: checkFn,
            requiresEnv: requiresEnv,
            isAsync: isAsync,
            description: resolvedDescription,
            emoji: emoji,
            maxResultSizeChars: maxResultSizeChars
        )
        _generation += 1
    }

    /// Last error message from `register()` (= tests inspect; nil =
    /// clean).
    public func lastRegisterError() -> String? { _lastRegisterError }

    // MARK: - Deregister (= hermes `deregister()` L450-515)

    /// Remove a tool from the registry (= hermes `deregister()`).
    ///
    /// Bumps the generation counter on success. No-op when the tool is
    /// not registered.
    public func deregister(name: String) {
        guard let entry = _tools[name] else { return }
        _tools.removeValue(forKey: name)
        // Drop the handler box if no other tool still references it.
        let stillReferenced = _tools.values.contains {
            $0.handlerID == entry.handlerID
        }
        if !stillReferenced {
            _handlers.removeValue(forKey: entry.handlerID)
        }
        _generation += 1
    }

    // MARK: - Schema retrieval (= hermes `get_definitions()` L521-568)

    /// Return `ToolRegistrySchema` list for the requested tool names.
    ///
    /// Only tools whose `checkFn` returns `true` (or have no `checkFn`)
    /// are included. Output is sorted by tool name (= hermes
    /// `sorted(tool_names)`).
    public func getDefinitions(toolNames: Set<String>) -> [ToolRegistrySchema] {
        var result: [ToolRegistrySchema] = []
        let sortedNames = toolNames.sorted()
        for name in sortedNames {
            guard let entry = _tools[name] else { continue }
            if let checkFn = entry.checkFn, !checkFn() {
                continue
            }
            result.append(entry.schema)
        }
        return result
    }

    /// Same as `getDefinitions` but wrapped in the OpenAI function-call
    /// envelope `{"type": "function", "function": {...}}` (= hermes
    /// L567).
    public func getDefinitionsWrapped(toolNames: Set<String>) -> [[String: Any]] {
        getDefinitions(toolNames: toolNames).map { schema in
            [
                "type": "function",
                "function": schema.toJSON()
            ]
        }
    }

    // MARK: - Dispatch (= hermes `dispatch()` query helpers)

    /// Return the registered `Tool` handler for the given name, or nil.
    public func getHandler(name: String) -> (any Tool)? {
        guard let entry = _tools[name],
              let box = _handlers[entry.handlerID]
        else { return nil }
        return box.handler
    }

    /// Return the registered `ToolEntry` for the given name, or nil
    /// (= hermes `get_entry()`).
    public func getEntry(name: String) -> ToolEntry? {
        _tools[name]
    }

    // MARK: - Query helpers (= hermes query API)

    /// Sorted list of all registered tool names (= hermes
    /// `get_all_tool_names()`).
    public func getAllToolNames() -> [String] {
        _tools.keys.sorted()
    }

    /// Sorted unique toolset names (= hermes
    /// `get_registered_toolset_names()`).
    public func getRegisteredToolsetNames() -> [String] {
        Array(Set(_tools.values.map { $0.toolset })).sorted()
    }

    /// Sorted tool names for a given toolset (= hermes
    /// `get_tool_names_for_toolset()`).
    public func getToolNamesForToolset(toolset: String) -> [String] {
        _tools.values
            .filter { $0.toolset == toolset }
            .map { $0.name }
            .sorted()
    }

    /// Toolset name for a given tool (= hermes `get_toolset_for_tool()`).
    public func getToolsetForTool(name: String) -> String? {
        _tools[name]?.toolset
    }

    /// Emoji for a given tool, or `default` if unset (= hermes
    /// `get_emoji()`).
    public func getEmoji(name: String, default defaultEmoji: String = "⚡") -> String {
        guard let entry = _tools[name] else { return defaultEmoji }
        return entry.emoji.isEmpty ? defaultEmoji : entry.emoji
    }

    /// `tool_name -> toolset` map for every registered tool (= hermes
    /// `get_tool_to_toolset_map()`).
    public func getToolToToolsetMap() -> [String: String] {
        var result: [String: String] = [:]
        for (name, entry) in _tools {
            result[name] = entry.toolset
        }
        return result
    }

    /// Per-tool max result size, or `default` if unset (= hermes
    /// `get_max_result_size()`).
    public func getMaxResultSize(name: String, default defaultSize: Int? = nil) -> Int? {
        if let entry = _tools[name], let size = entry.maxResultSizeChars {
            return size
        }
        return defaultSize
    }

    /// Snapshot of all registered entries (= hermes
    /// `_snapshot_entries()`).
    public func snapshotEntries() -> [ToolEntry] {
        Array(_tools.values)
    }

    // MARK: - Mutation helpers (= hermes `clear()` + generation counter)

    /// Drop all registrations (= testing convenience; hermes equivalent
    /// achieved via `registry._tools.clear()`).
    public func clear() {
        _tools.removeAll()
        _handlers.removeAll()
        _lastRegisterError = nil
        _generation += 1
    }

    /// Current mutation generation (= hermes `_generation`).
    /// External callers can key memoization on this (= cache is valid
    /// while generation is unchanged).
    public func generation() -> Int {
        _generation
    }

    /// Total number of registered tools (= hermes `len(_tools)`).
    public func count() -> Int {
        _tools.count
    }
}