//
//  ToolDispatchHelpers.swift · Wenshu · TICKET-HERMES-GAP-008
//
//  Ported from hermes-agent `agent/tool_dispatch_helpers.py` (503 LOC).
//
//  Hermes' tool_dispatch_helpers is a bag of stateless utilities
//  (= parallelism gating, multimodal envelopes, mutation tracking,
//  trajectory normalization). For v0.40 the wenshu-side wins
//  pattern narrows to the parallel hook-chain layer that
//  `ToolExecutor.execute` consults around every tool invocation
//  (= the spec's "parallel tool-dispatch layer" mentioned in the
//  ticket body).
//
//  NB: this is a PARALLEL layer to the GAP-004 `ShellHookChain`,
//  not a replacement. `ShellHookChain` fires at the runtime surface
//  (= pre/post LLM call, pre/post turn, pre/post tool call via
//  `ToolCall`). `ToolDispatchHookChain` here is a thinner
//  `preDispatch` / `postDispatch` pair keyed by `(toolName, input)`
//  for tool-call-only observation (= e.g. dispatch metrics, audit
//  log, input redaction). The two layers coexist; default both =
//  empty = no behavior change.
//
//  The other hermes helpers in `tool_dispatch_helpers.py` (=
//  `_should_parallelize_tool_batch`, `_is_multimodal_tool_result`,
//  `_extract_file_mutation_targets`, etc.) are intentionally NOT
//  ported in this ticket (= documented in the gap audit as
//  out-of-scope; wenshu's existing `ToolGuardrails` covers
//  path validation, and `ToolExecutor.executeSequential` /
//  `executeConcurrent` already encodes the concurrency surface).
//
//  Per AGENTS.md §11 hard rule: Apple Foundation only; no
//  third-party imports.
//

import Foundation

// MARK: - ToolDispatchHook protocol

/// One dispatch-layer hook (observation + optional veto) at the
/// per-tool-call surface inside `ToolExecutor.execute`.
///
/// Default-off; register via `ToolDispatchHookChain.register(_:)`.
/// Hooks fire sequentially in registration order; first throw from
/// `preDispatch` short-circuits (= matches hermes'
/// fire-and-abort-on-error semantics for pre-tool gates).
///
/// `preDispatch` throws to ABORT the tool call (= the executor
/// surfaces the error to the LLM as a tool result with isError
/// true). `postDispatch` is observational; throws are swallowed
/// by `ToolDispatchHookChain.firePostDispatch` to avoid breaking
/// the tool execution path (= hermes post-tool errors are non-
/// fatal).
public protocol ToolDispatchHook: Sendable {
    /// Stable identifier; used for `unregister(_:)` deduplication
    /// (= name-based, since protocol types don't compare by `==`).
    var name: String { get }

    /// Before the tool is invoked. Throwing aborts the dispatch
    /// (= the LLM sees the error message as a tool result).
    func preDispatch(toolName: String, input: [String: String]) async throws

    /// After the tool returns (= success or error). Observation-
    /// only by convention; implementations should not throw.
    func postDispatch(toolName: String, input: [String: String], output: String) async throws
}

// MARK: - ToolDispatchHookChain actor

/// Thread-safe registry + dispatcher for `ToolDispatchHook`s.
/// Hooks fire in registration order. `firePreDispatch` propagates
/// the first throw (= aborts the tool call); `firePostDispatch`
/// swallows throws (= observability hooks must not break the tool
/// execution path).
public actor ToolDispatchHookChain {
    private var hooks: [ToolDispatchHook] = []

    public init() {}

    /// Append a hook. Duplicate `name` is allowed (= caller's
    /// responsibility to deduplicate before registering).
    public func register(_ hook: ToolDispatchHook) { hooks.append(hook) }

    /// Remove the first hook whose `name` matches `hook.name`.
    public func unregister(_ hook: ToolDispatchHook) {
        hooks.removeAll { $0.name == hook.name }
    }

    /// Clear every registered hook (= useful for tests + hot reload).
    public func unregisterAll() { hooks.removeAll() }

    /// Snapshot of currently-registered hooks, in registration order.
    public var current: [ToolDispatchHook] { hooks }

    /// Fire all pre-dispatch hooks in order. First throw short-
    /// circuits the rest (= matches hermes pre-tool semantics).
    public func firePreDispatch(toolName: String, input: [String: String]) async throws {
        for hook in hooks {
            try await hook.preDispatch(toolName: toolName, input: input)
        }
    }

    /// Fire all post-dispatch hooks in order. Throws are SWALLOWED
    /// (= observability hooks must not break the tool execution).
    public func firePostDispatch(toolName: String, input: [String: String], output: String) async {
        for hook in hooks {
            do {
                try await hook.postDispatch(toolName: toolName, input: input, output: output)
            } catch {
                // Swallow (= observability contract). Future
                // enhancement: surface via `os.Logger`.
                _ = error
            }
        }
    }
}

// MARK: - ToolExecutor wire-up
//
// ToolDispatchHookChain is wired into ToolExecutor.execute around
// every `tool.execute(input:)` call (= before + after). The chain
// is stored as a `let` property on the executor; default =
// `ToolDispatchHookChain()` = empty = no behavior change.
//
// This wire-up is in the same `Tool/` folder as ToolExecutor for
// cohesion. The actual `let dispatchHookChain` declaration + the
// fire calls live in `ToolExecutor.swift` (see the
// `// TICKET-HERMES-GAP-008` markers there).

// MARK: - No-op default

/// Empty hook = no-op default. Useful for "subscribe to one event
/// without implementing both." (= Swift has no default method
/// implementations on protocols; this is the wenshu-side equivalent
/// of hermes' `_noop_hook`.)
public struct NoopToolDispatchHook: ToolDispatchHook {
    public let name: String
    public init(name: String) { self.name = name }

    public func preDispatch(toolName: String, input: [String: String]) async throws {
        _ = toolName; _ = input
    }

    public func postDispatch(toolName: String, input: [String: String], output: String) async throws {
        _ = toolName; _ = input; _ = output
    }
}

// MARK: - Input parsing helper

/// Parse a `Tool.execute(input:)` JSON-string into a `[String: String]`
/// for the hook layer.
///
/// The dispatch layer works with key-value inputs (= matches the
/// tool_dispatch_helpers `_extract_parallel_scope_path(toolName, args)`
/// shape). Top-level JSON strings map directly; nested objects /
/// arrays are JSON-encoded into a single string value (= preserves
/// structure without forcing the hook layer to know about every
/// tool's schema).
///
/// Returns an empty dict when the input is not valid JSON (= matches
/// hermes' "couldn't parse → fall through" semantics in
/// `_should_parallelize_tool_batch`).
public enum ToolDispatchInputParser {
    public static func parse(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any]
        else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in dict {
            if let s = value as? String {
                result[key] = s
                continue
            }
            // JSONSerialization.isValidJSONObject only accepts the
            // top-level container shapes (Array / Dictionary). Primitives
            // (Bool / Number / NSNull) and Foundation types outside that
            // contract raise an NSException at runtime, NOT a Swift Error
            // that `try?` can catch. Guard with isValidJSONObject so we
            // never call into the serializer with an unsupported top-level
            // value (= matches hermes' "couldn't parse → fall through").
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(
                   withJSONObject: value,
                   options: [.fragmentsAllowed]
               ),
               let encoded = String(data: data, encoding: .utf8) {
                result[key] = encoded
            }
            // Primitives (Bool, Number, NSNull) are silently dropped
            // (= same fall-through semantics as a parse failure).
        }
        return result
    }

    /// Serialize a `[String: String]` dispatch-layer dictionary back into
    /// a JSON string suitable for passing to `Tool.execute(input:)`.
    /// HERMES-PARTIAL-003 wire-up: ToolExecutor's pre-dispatch validator
    /// returns a `[String: String]` (= the dispatch-layer dict); this
    /// method reverses ToolDispatchInputParser.parse so the tool receives
    /// the canonical input envelope.
    ///
    /// Returns "{}" for an empty dict (= the parser's empty-dict input).
    public static func serialize(_ input: [String: String]) -> String {
        guard !input.isEmpty,
              JSONSerialization.isValidJSONObject(input),
              let data = try? JSONSerialization.data(
                  withJSONObject: input,
                  options: [.fragmentsAllowed, .sortedKeys]
              ),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return encoded
    }
}
