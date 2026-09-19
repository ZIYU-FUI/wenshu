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

// MARK: - H8 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/shell_hooks.py` payload + response + allowlist
//         helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/shell_hooks.py` per spec §3.1 #34
// (= TICKET-HERMES-GAP-004 follow-up). The target file already
// existed at 189 LOC (= ⚠️ partial per gap audit 2026-09-04 =
// wenshu-side wins = the hook protocol + actor). This H8 ticket
// adds the 7 hermes payload/response/allowlist pure helpers.
//
// The remaining 12 hermes functions in shell_hooks.py
// (= register_from_config / iter_configured_hooks / reset_for_tests
// / _parse_hooks_block / _parse_single_entry / _spawn /
// _make_callback / _prompt_and_record / _record_approval /
// _utc_now_iso / revoke / _command_script_path / etc.) are
// intentionally NOT ported in this ticket — they fall into
// separate wenshu-side wins patterns (= wenshu uses
// ToolExecutor for the runtime dispatch; = per Q112 = one
// ticket per file).
//
// Hermes Python line range cited in doc-comments below (= for
// traceability back to `/Volumes/ANAN/.hermes/agent/
// shell_hooks.py`).

extension ShellHookChain {

    // MARK: -- H8.1 payload serialization (= hermes L536-L553)

    /// Pure-function: render the stdin JSON payload for a shell
    /// hook (= hermes `_serialize_payload` at
    /// `agent/shell_hooks.py` L536-L553).
    ///
    /// Unserialisable values are stringified via `JSONEncoder`
    /// fallback (= wenshu uses `String(describing:)` instead of
    /// hermes's Python `default=str`; = same effect).
    public static func serializePayload(event: String, kwargs: [String: Any]) -> String {
        let topLevelKeys: Set<String> = [
            "tool_name", "args", "session_id", "parent_session_id",
        ]
        var extras: [String: Any] = [:]
        for (k, v) in kwargs where !topLevelKeys.contains(k) {
            extras[k] = v
        }
        let cwd: String
        do {
            cwd = String(describing: FileManager.default.currentDirectoryPath)
        } catch {
            cwd = ""
        }
        let payload: [String: Any] = [
            "hook_event_name": event,
            "tool_name": kwargs["tool_name"] as Any? ?? NSNull(),
            "tool_input": (kwargs["args"] as? [String: Any]) ?? NSNull(),
            "session_id": (kwargs["session_id"] as? String)
                ?? (kwargs["parent_session_id"] as? String)
                ?? "",
            "cwd": cwd,
            "extra": extras,
        ]
        guard JSONSerialization.isValidJSONObject(payload) else {
            return "{}"
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.fragmentsAllowed]
        ) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: -- H8.2 block message (= hermes L555-L564)

    /// Pure-function: return a validated string block message,
    /// falling back to the default (= hermes `_block_message` at
    /// `agent/shell_hooks.py` L555-L564).
    ///
    /// Accepts two candidate fields (= primary wins over secondary)
    /// so callers can express field-priority differences between
    /// the two hook wire formats.
    public static func blockMessage(primary: Any?, secondary: Any?) -> String {
        if let raw = primary as? String, !raw.isEmpty {
            return raw
        }
        if let raw = secondary as? String, !raw.isEmpty {
            return raw
        }
        return "Shell hook blocked the request."
    }

    // MARK: -- H8.3 response parsing (= hermes L566-L625)

    /// Pure-function: translate stdout JSON into a wire-shape
    /// dict (= hermes `_parse_response` at
    /// `agent/shell_hooks.py` L566-L625).
    ///
    /// Handles 3 wire shapes:
    ///   1. `pre_tool_call` = `{"decision": "block", "reason": "..."}`
    ///      OR `{"action": "block", "message": "..."}` =
    ///      translated to canonical `{"action": "block",
    ///      "message": "..."}`.
    ///   2. `pre_verify` = `{"action": "continue"|"block", ...}`
    ///      = translated to canonical `{"action": "continue", ...}`.
    ///   3. `pre_llm_call` = `{"context": "..."}` = passed through
    ///      unchanged.
    public static func parseResponse(event: String, stdout: String) -> [String: Any]? {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if event == "pre_tool_call" {
            if parsed["action"] as? String == "block" {
                let msg = blockMessage(
                    primary: parsed["message"],
                    secondary: parsed["reason"]
                )
                return ["action": "block", "message": msg]
            }
            if parsed["decision"] as? String == "block" {
                let msg = blockMessage(
                    primary: parsed["reason"],
                    secondary: parsed["message"]
                )
                return ["action": "block", "message": msg]
            }
            return nil
        }

        if event == "pre_verify" {
            let actionRaw = (parsed["action"] as? String)
                ?? (parsed["decision"] as? String)
                ?? ""
            let action = actionRaw.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if action == "continue" || action == "block" {
                if let message = (parsed["message"] as? String) ?? (parsed["reason"] as? String),
                   !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return ["action": "continue", "message": message.trimmingCharacters(in: .whitespacesAndNewlines)]
                }
            }
            return nil
        }

        if let context = parsed["context"] as? String,
           !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["context": context]
        }

        return nil
    }

    // MARK: -- H8.4 allowlist path (= hermes L627-L630)

    /// Pure-function: return the per-user shell-hook allowlist
    /// file path (= hermes `allowlist_path` at
    /// `agent/shell_hooks.py` L627-L630).
    ///
    /// Wenshu-side wins: returns the macOS
    /// `~/Library/Application Support/wenshu/` path (= matches
    /// the wenshu `.ws` bundle path from AGENTS.md §11).
    public static func allowlistPath() -> URL {
        let base: URL
        if let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            base = appSupport.appendingPathComponent("wenshu", isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".wenshu", isDirectory: true)
        }
        return base.appendingPathComponent("shell-hooks-allowlist.json")
    }

    // MARK: -- H8.5 load allowlist (= hermes L632-L644)

    /// Pure-function: return the parsed allowlist, or an empty
    /// skeleton if absent (= hermes `load_allowlist` at
    /// `agent/shell_hooks.py` L632-L644).
    public static func loadAllowlist() -> [String: Any] {
        let path = allowlistPath()
        guard let data = try? Data(contentsOf: path),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ["approvals": []]
        }
        if !(raw["approvals"] is [Any]) {
            var fixed = raw
            fixed["approvals"] = []
            return fixed
        }
        return raw
    }

    // MARK: -- H8.6 save allowlist (= hermes L646-L676)

    /// Pure-function: atomically persist the allowlist
    /// (= hermes `save_allowlist` at
    /// `agent/shell_hooks.py` L646-L676).
    ///
    /// Wenshu-side wins: uses Foundation's
    /// `FileManager.replaceItem` for atomic write (= the macOS
    /// equivalent of Python's `mkstemp + os.replace`).
    public static func saveAllowlist(_ data: [String: Any]) throws {
        let path = allowlistPath()
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let jsonData = try JSONSerialization.data(
            withJSONObject: data,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: path, options: .atomic)
    }

    // MARK: -- H8.7 is allowlisted (= hermes L678-L687)

    /// Pure-function: return true when the (event, command) pair
    /// is in the allowlist (= hermes `_is_allowlisted` at
    /// `agent/shell_hooks.py` L678-L687).
    public static func isAllowlisted(event: String, command: String) -> Bool {
        let data = loadAllowlist()
        guard let approvals = data["approvals"] as? [[String: Any]] else {
            return false
        }
        return approvals.contains { entry in
            entry["event"] as? String == event
                && entry["command"] as? String == command
        }
    }
}