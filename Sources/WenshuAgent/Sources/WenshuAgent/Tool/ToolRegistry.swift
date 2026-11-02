// ToolRegistry.swift
//
// The registry half of the tool contract: registration, definition
// lookup, handler dispatch, and the generation counter callers memoize
// on. The declarations it stores live in ToolSchema.swift.

import Foundation

/// cache invalidation on registry mutation).
public actor ToolRegistry {

    /// Module-level singleton (= hermes `registry = ToolRegistry()`).
    ///
    /// Access also runs the registered production bootstrap, so the
    /// app's tools are present the first time the registry is read.
    /// Swift static properties are lazy, so merely linking the tool
    /// files does not execute their registration initializers.
    public nonisolated static var shared: ToolRegistry {
        let registry = sharedStorage
        ProductionToolRegistryBootstrap.start()
        return registry
    }

    private nonisolated static let sharedStorage = ToolRegistry()

    /// The app's production registration points, supplied by the app.
    ///
    /// The runtime owns the registry; the app owns the tools. The app
    /// installs the closure that touches its own tool types once, and
    /// the registry runs it on first access. The runtime never names an
    /// app type.
    public enum ProductionToolRegistryBootstrap {
        /// Touch every production registration point exactly once.
        public nonisolated(unsafe) static var start: @Sendable () -> Void = {}
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
    /// Callers waiting for tool names to land (= see
    /// `awaitRegistration(of:ceiling:)`).
    private var _registrationWaiters: [RegistrationWaiter] = []

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
        // A waiter may be blocked on this name (= the tool files
        // schedule their registration, so the caller that needs it
        // waits here rather than on a clock).
        wakeRegistrationWaiters()
    }

    /// Last error message from `register()` (= tests inspect; nil =
    /// clean).
    /// thin wrapper for the canonical `_registryBootstrap`
    /// boilerplate (= 14 files repeat the same `Task { await register(...) }`
    /// pattern; = the wrapper schedules the async call off the init
    /// thread; = collapse each call site from 8-line `Task { ... }`
    /// to 1-line `Task { await registerTool(...) }`).
    public func registerTool(
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

    /// Emoji for a given tool, or `default` if unset (= hermes
    /// `get_emoji()`).
    public func getEmoji(name: String, default defaultEmoji: String = "⚡") -> String {
        guard let entry = _tools[name] else { return defaultEmoji }
        return entry.emoji.isEmpty ? defaultEmoji : entry.emoji
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

    // MARK: - Awaitable registration

    /// Suspend until every name in `names` has landed in the registry.
    ///
    /// The app's tool files schedule their registration as a `Task`, so
    /// how long it takes to land depends on what else the process is
    /// doing. A caller that waits on a clock decides its verdict from
    /// the machine's load; a caller that waits here decides it from the
    /// code: the wait ends the moment the last name lands.
    ///
    /// Returns `true` when every name landed, `false` when `ceiling`
    /// elapsed first.
    ///
    /// `ceiling` is a safety net against a registration that never
    /// happens (= a hang), NOT the wait's budget: a wait that is long
    /// because the machine is busy still ends as soon as the
    /// registration lands.
    @discardableResult
    public func awaitRegistration(
        of names: Set<String>,
        ceiling: Duration = .seconds(60)
    ) async -> Bool {
        guard !names.isEmpty else {
            return true
        }
        if names.subtracting(Set(_tools.keys)).isEmpty {
            return true
        }

        let waiter = RegistrationWaiter(names: names)
        _registrationWaiters.append(waiter)

        // A registration may have landed between the check above and the
        // append, so re-check before suspending.
        if names.subtracting(Set(_tools.keys)).isEmpty {
            _registrationWaiters.removeAll { $0 === waiter }
            return true
        }

        let expiration = Task { [weak self] in
            try? await Task.sleep(for: ceiling)
            await self?.expireRegistrationWaiter(waiter)
        }
        defer { expiration.cancel() }

        let landed = await withCheckedContinuation { continuation in
            waiter.install(continuation)
        }
        _registrationWaiters.removeAll { $0 === waiter }
        return landed
    }

    /// Cut a wait short (= the ceiling elapsed before the names landed).
    private func expireRegistrationWaiter(_ waiter: RegistrationWaiter) {
        _registrationWaiters.removeAll { $0 === waiter }
        waiter.resume(outcome: false)
    }

    /// Resume every waiter whose names have all landed.
    private func wakeRegistrationWaiters() {
        guard !_registrationWaiters.isEmpty else { return }
        let registered = Set(_tools.keys)
        var landed: [RegistrationWaiter] = []
        _registrationWaiters.removeAll { waiter in
            if waiter.names.subtracting(registered).isEmpty {
                landed.append(waiter)
                return true
            }
            return false
        }
        for waiter in landed {
            waiter.resume(outcome: true)
        }
    }
}

// MARK: - RegistrationWaiter

/// A caller waiting for a set of tool names to land.
///
/// The registration and the ceiling both try to resume the waiter, so
/// the guard makes exactly one of them win (= a double resume of a
/// continuation traps).
private final class RegistrationWaiter: @unchecked Sendable {
    let names: Set<String>

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var outcome = false
    private var resumed = false

    init(names: Set<String>) {
        self.names = names
    }

    /// Install the continuation, or resume it at once when the waiter
    /// was already resumed (= the names landed before the wait began).
    func install(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        defer { lock.unlock() }
        if resumed {
            continuation.resume(returning: outcome)
        } else {
            self.continuation = continuation
        }
    }

    /// Resume the waiter (= exactly once; the first caller wins).
    func resume(outcome: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        self.outcome = outcome
        continuation?.resume(returning: outcome)
        continuation = nil
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
