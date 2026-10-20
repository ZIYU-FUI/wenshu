// ToolRegistry.swift
//
// The registry half of the tool contract: registration, definition
// lookup, handler dispatch, and the generation counter callers memoize
// on. The declarations it stores live in ToolSchema.swift.

import Foundation
import WenshuAgent

/// cache invalidation on registry mutation).
actor ToolRegistry {

    /// Module-level singleton (= hermes `registry = ToolRegistry()`).
    /// Access also starts the production tool bootstraps. Swift static
    /// properties are lazy, so merely linking the tool files does not
    /// execute their registration initializers.
    nonisolated static var shared: ToolRegistry {
        let registry = sharedStorage
        _ = ProductionToolRegistryBootstrap.start
        return registry
    }

    private nonisolated static let sharedStorage = ToolRegistry()

    /// Touch every production registration point exactly once.
    private enum ProductionToolRegistryBootstrap {
        static let start: Void = {
            _ = ReadFileTool._registryBootstrap
            _ = WriteFileTool._registryBootstrap
            _ = AVMediaTools._registryBootstrap
            _ = BookManagerTool._registryBootstrap
            _ = FileTools._registryBootstrap
            _ = KanbanStoreTool._registryBootstrap
            _ = ProcessTools._registryBootstrap
            _ = TodoStoreTool._registryBootstrap
            _ = HermesTodoTool._registryBootstrap
            _ = VisionTools._registryBootstrap
            _ = WebTools._registryBootstrap
        }()
    }

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

    init() {}

    // MARK: - Register (= hermes `register()` L356-448)

    /// Register a tool (= hermes `register()`).
    ///
    /// Called at module-import time by each tool file. `override=true`
    /// is the explicit opt-in for plugins that intend to replace an
    /// existing built-in tool implementation. Without it, registrations
    /// that would shadow an existing tool from a different toolset are
    /// rejected to prevent accidental overwrites.
    func register(
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
    /// thin wrapper for the canonical `_registryBootstrap`
    /// boilerplate (= 14 files repeat the same `Task { await register(...) }`
    /// pattern; = the wrapper schedules the async call off the init
    /// thread; = collapse each call site from 8-line `Task { ... }`
    /// to 1-line `Task { await registerTool(...) }`).
    func registerTool(
        name: String,
        toolset: String,
        schema: ToolRegistrySchema,
        handler: any Tool,
        description: String = "",
        emoji: String = ""
    ) async {
        register(
            name: name,
            toolset: toolset,
            schema: schema,
            handler: handler,
            description: description,
            emoji: emoji
        )
    }

    func lastRegisterError() -> String? { _lastRegisterError }

    // MARK: - Deregister (= hermes `deregister()` L450-515)

    /// Remove a tool from the registry (= hermes `deregister()`).
    ///
    /// Bumps the generation counter on success. No-op when the tool is
    /// not registered.
    func deregister(name: String) {
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
    func getDefinitions(toolNames: Set<String>) -> [ToolRegistrySchema] {
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

    // MARK: - Dispatch (= hermes `dispatch()` query helpers)

    /// Return the registered `Tool` handler for the given name, or nil.
    func getHandler(name: String) -> (any Tool)? {
        guard let entry = _tools[name],
              let box = _handlers[entry.handlerID]
        else { return nil }
        return box.handler
    }

    /// Return the registered `ToolEntry` for the given name, or nil
    /// (= hermes `get_entry()`).
    func getEntry(name: String) -> ToolEntry? {
        _tools[name]
    }

    // MARK: - Query helpers (= hermes query API)

    /// Sorted list of all registered tool names (= hermes
    /// `get_all_tool_names()`).
    func getAllToolNames() -> [String] {
        _tools.keys.sorted()
    }

    /// Emoji for a given tool, or `default` if unset (= hermes
    /// `get_emoji()`).
    func getEmoji(name: String, default defaultEmoji: String = "⚡") -> String {
        guard let entry = _tools[name] else { return defaultEmoji }
        return entry.emoji.isEmpty ? defaultEmoji : entry.emoji
    }

    // MARK: - Mutation helpers (= hermes `clear()` + generation counter)

    /// Drop all registrations (= testing convenience; hermes equivalent
    /// achieved via `registry._tools.clear()`).
    func clear() {
        _tools.removeAll()
        _handlers.removeAll()
        _lastRegisterError = nil
        _generation += 1
    }

    /// Current mutation generation (= hermes `_generation`).
    /// External callers can key memoization on this (= cache is valid
    /// while generation is unchanged).
    func generation() -> Int {
        _generation
    }

    /// Total number of registered tools (= hermes `len(_tools)`).
    func count() -> Int {
        _tools.count
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
///     silently wins (= re-registration by the same owner is
///     idempotent).
///
/// Generation counter (mirrors hermes `_generation`): bumped on every
/// mutation (= `register`, `deregister`, `clear`). External callers
/// can key their memoization on `generation()` (= equivalent of hermes
