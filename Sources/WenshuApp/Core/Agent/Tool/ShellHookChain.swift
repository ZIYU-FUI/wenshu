//
//  ShellHookChain.swift · Wenshu · TICKET-HERMES-GAP-004
//
//  Ported from hermes-agent `agent/shell_hooks.py` (928 LOC).
//  Per spec §2.2 thin-port: extract the hook-chain protocol only;
//  user scripts are optional + default off. The wenshu-side
//  implementation = a Swift `ShellHook` protocol + a `ShellHookChain`
//  actor that composes hooks in order. No runtime dispatch (= tool
//  calls are dispatched by `ToolExecutor`, not `ShellHookChain`).
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern: Python's hook
//  callback registration is replaced with a Swift `ShellHookChain`
//  actor that calls each hook in order. The hook points are:
//    - pre-tool-call: before ToolExecutor.execute() invokes the tool
//    - post-tool-call: after ToolExecutor receives the tool result
//    - pre-llm-call: before LLMConnector.send() invokes the provider
//    - post-llm-call: after LLMConnector receives the response
//    - pre-turn: before ConversationLoop.runTurn() begins
//    - post-turn: after ConversationLoop.runTurn() completes
//
//  Default-off: `ShellHookChain()` starts empty; no behavior change
//  unless a hook is registered. Wire-up lands in ToolExecutor
//  (pre/post tool call only — other 4 hook points are exercised by
//  LLMConnector + ConversationLoop in future tickets).
//
//  Placeholder types: `ToolCall`, `ToolResult`, and `LLMRequest` are
//  thin placeholder structs (= no equivalent in the existing wenshu
//  tree at the time of this port; the real types land in future
//  tickets for tool dispatch and connector surface). When those land,
//  ShellHook protocol signatures stay the same; only the type bodies
//  change (= thin adapters per §11.3).
//

import Foundation

// MARK: - Placeholder types
//
// These exist solely so the ShellHook protocol is self-contained. They
// mirror the conceptual shape used by ToolExecutor / LLMConnector but
// do not replace the real wire types. Future tickets will replace each
// placeholder with the canonical type (= e.g. ToolCall will reuse the
// (toolUseID, toolName, input) tuple that ToolExecutor currently uses
// internally, wrapped in a struct).

/// Placeholder for an outbound tool invocation (= pre-tool-call payload).
/// Future: real struct will live alongside `Tool.swift` and reuse the
/// (toolUseID, toolName, input) tuple currently threaded through
/// ToolExecutor.
public struct ToolCall: Sendable, Equatable {
    public let id: String
    public let name: String
    public let input: String
    public init(id: String, name: String, input: String) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// Placeholder for a tool execution result (= post-tool-call payload).
/// Future: real struct will wrap `LLMBlock.toolResult(toolUseID:output:)`
/// or the tool's raw return value, plus an `isError` flag.
public struct ToolResult: Sendable, Equatable {
    public let toolCallID: String
    public let output: String
    public let isError: Bool
    public init(toolCallID: String, output: String, isError: Bool = false) {
        self.toolCallID = toolCallID
        self.output = output
        self.isError = isError
    }
}

/// Placeholder for an LLM request (= pre-llm-call + post-llm-call payload).
/// Future: real struct will wrap `LLMConnector.send(messages:options:)`
/// = the canonical wire envelope used by all 7 connector profiles.
/// Currently `LLMCallOptions` + `[LLMMessage]` are passed separately; a
/// unified request type is a future refactor.
public struct LLMRequest: Sendable {
    public let messages: [LLMMessage]
    public let options: LLMCallOptions
    public init(messages: [LLMMessage], options: LLMCallOptions) {
        self.messages = messages
        self.options = options
    }
}

// MARK: - Hook protocol

/// One shell-style hook (= observation + optional mutation point) at
/// each of the 6 lifecycle moments. Default-off; register via
/// `ShellHookChain.register(_:)`.
///
/// All methods are `async throws` (= matches hermes' async hook
/// signature) and `Sendable` (= hook can be passed across actor
/// boundaries). Hooks fire sequentially in registration order.
public protocol ShellHook: Sendable {
    /// Stable identifier; used by `ShellHookChain.unregister(_:)`.
    var name: String { get }

    /// Before ToolExecutor invokes a tool. Throwing aborts execution.
    func preToolCall(_ call: ToolCall) async throws

    /// After ToolExecutor receives the tool result (= success or error).
    func postToolCall(_ call: ToolCall, result: ToolResult) async throws

    /// Before LLMConnector.send() invokes the provider. Throwing
    /// aborts the call (= matches hermes pre-LLM hook semantics).
    func preLLMCall(_ request: LLMRequest) async throws

    /// After LLMConnector receives the response.
    func postLLMCall(_ request: LLMRequest, response: LLMResponse) async throws

    /// Before ConversationLoop.runTurn() begins (= one user message
    /// = one turn).
    func preTurn(_ userMessage: String) async throws

    /// After ConversationLoop.runTurn() completes (= final response).
    func postTurn(_ response: LLMResponse) async throws
}

// MARK: - Hook chain actor

/// Thread-safe registry + dispatcher for `ShellHook` callbacks.
/// Hooks fire in registration order; first throw short-circuits the
/// remaining hooks in that batch (= matches hermes `shell_hooks.py`
/// fire-and-abort-on-error semantics).
public actor ShellHookChain {
    private var hooks: [ShellHook] = []

    public init() {}

    /// Append a hook to the chain. Duplicate `name` is allowed (= caller's
    /// responsibility to deduplicate before registering).
    public func register(_ hook: ShellHook) { hooks.append(hook) }

    /// Remove the first hook whose `name` matches the given hook's `name`.
    public func unregister(_ hook: ShellHook) {
        hooks.removeAll { $0.name == hook.name }
    }

    /// Remove every registered hook (= useful for tests + hot reload).
    public func unregisterAll() { hooks.removeAll() }

    /// Snapshot of currently-registered hooks (= in registration order).
    public var current: [ShellHook] { hooks }

    // MARK: - Fire methods

    public func firePreToolCall(_ call: ToolCall) async throws {
        for hook in hooks { try await hook.preToolCall(call) }
    }

    public func firePostToolCall(_ call: ToolCall, result: ToolResult) async throws {
        for hook in hooks { try await hook.postToolCall(call, result: result) }
    }

    public func firePreLLMCall(_ request: LLMRequest) async throws {
        for hook in hooks { try await hook.preLLMCall(request) }
    }

    public func firePostLLMCall(_ request: LLMRequest, response: LLMResponse) async throws {
        for hook in hooks { try await hook.postLLMCall(request, response: response) }
    }

    public func firePreTurn(_ userMessage: String) async throws {
        for hook in hooks { try await hook.preTurn(userMessage) }
    }

    public func firePostTurn(_ response: LLMResponse) async throws {
        for hook in hooks { try await hook.postTurn(response) }
    }
}

// MARK: - No-op default

/// Empty hook = no-op default. Useful for "I want to subscribe to one
/// event without implementing all 6." (= Swift has no default method
/// implementations on protocols; this is the wenshu-side equivalent.)
public struct NoopShellHook: ShellHook {
    public let name: String
    public init(name: String) { self.name = name }

    public func preToolCall(_: ToolCall) async throws {}
    public func postToolCall(_: ToolCall, result: ToolResult) async throws {}
    public func preLLMCall(_: LLMRequest) async throws {}
    public func postLLMCall(_: LLMRequest, response: LLMResponse) async throws {}
    public func preTurn(_: String) async throws {}
    public func postTurn(_: LLMResponse) async throws {}
}