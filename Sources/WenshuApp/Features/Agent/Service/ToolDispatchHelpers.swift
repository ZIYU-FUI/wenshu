//
//  ToolDispatchHelpers.swift
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
import WenshuData

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
protocol ToolDispatchHook: Sendable {
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
actor ToolDispatchHookChain {
    private var hooks: [ToolDispatchHook] = []

    init() {}

    /// Append a hook. Duplicate `name` is allowed (= caller's
    /// responsibility to deduplicate before registering).
    func register(_ hook: ToolDispatchHook) { hooks.append(hook) }

    /// Remove the first hook whose `name` matches `hook.name`.
    func unregister(_ hook: ToolDispatchHook) {
        hooks.removeAll { $0.name == hook.name }
    }

    /// Clear every registered hook (= useful for tests + hot reload).
    func unregisterAll() { hooks.removeAll() }

    /// Snapshot of currently-registered hooks, in registration order.
    var current: [ToolDispatchHook] { hooks }

    /// Fire all pre-dispatch hooks in order. First throw short-
    /// circuits the rest (= matches hermes pre-tool semantics).
    func firePreDispatch(toolName: String, input: [String: String]) async throws {
        for hook in hooks {
            try await hook.preDispatch(toolName: toolName, input: input)
        }
    }

    /// Fire all post-dispatch hooks in order. Throws are SWALLOWED
    /// (= observability hooks must not break the tool execution).
    func firePostDispatch(toolName: String, input: [String: String], output: String) async {
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
enum ToolDispatchInputParser {
    static func parse(_ json: String) -> [String: String] {
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
    /// wenshu port wire-up: ToolExecutor's pre-dispatch validator
    /// returns a `[String: String]` (= the dispatch-layer dict); this
    /// method reverses ToolDispatchInputParser.parse so the tool receives
    /// the canonical input envelope.
    ///
    /// Returns "{}" for an empty dict (= the parser's empty-dict input).
    static func serialize(_ input: [String: String]) -> String {
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

// MARK: - H4 Hermes-Python gap port (= the multimodal envelope helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/tool_dispatch_helpers.py` per spec §3.1 #20
// (= TICKET-HERMES-GAP-008 follow-up). The target file already existed at
// 207 LOC (= ⚠️ partial per gap audit 2026-09-04 = wenshu-s
// partial port = the hook-chain + input-parser layer).
// This H4 ticket added the 2 hermes multimodal envelope helpers
// (= `isMultimodalToolResult` = hermes L177-L185; =
// `multimodalTextSummary` = hermes L188-L208).
//
// NOT PORTED (= the untrusted-tool-result wrapper):
//   - `isUntrustedTool` (= hermes L414-L418)
//   - `neutralizeDelimiters` (= hermes L420-L424)
//   - `maybeWrapUntrusted` (= hermes L427-L463)
//   - `makeToolResultMessage` (= hermes L342-L386)
// The wrapper is the promptware defense = it marks a tool's output as
// untrusted data before the model reads it. It is not in this app, and the
// hermes source it would be ported from is not on this machine, so the port
// needs its own ticket and its own design. Until then, a tool result reaches
// the model unwrapped.
//
// Hermes Python line ranges cited in doc-comments below (= for traceability
// back to `/Volumes/ANAN/.hermes/agent/tool_dispatch_helpers.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - Pre-existing ToolDispatchHookChain + ToolDispatchInputParser
//     preserved (= wenshu chose hook-chain pattern over hermes's
//     batch-parallelism-gate pattern).
//   - The `_NEVER_PARALLEL_TOOLS` / `_PARALLEL_SAFE_TOOLS` /
//     `_PATH_SCOPED_TOOLS` hermes tool classifications (= specific to
//     hermes's tool ecosystem) are NOT ported = wenshu's tools
//     have different concurrency semantics (= wenshu's ToolExecutor
//     uses per-tool Sendable isolation per wenshu-side wins).

// MARK: - H4.1 Multimodal envelope helpers (= hermes L177-L208)

extension ToolDispatchInputParser {

    /// True if the value is a multimodal tool-result envelope (= hermes
    /// `_is_multimodal_tool_result` at
    /// `agent/tool_dispatch_helpers.py` L177-L185).
    ///
    /// Multimodal handlers (= e.g. hermes computer_use / wenshu vision)
    /// return a dict with `_multimodal == true`, a `content` key holding
    /// OpenAI-style content parts, and an optional `text_summary` for
    /// string-only fallbacks.
    ///
    /// Pure function (= no side effects; = hermes equivalent).
    static func isMultimodalToolResult(_ value: Any) -> Bool {
        guard let dict = value as? [String: Any] else { return false }
        let hasMultimodal = (dict["_multimodal"] as? Bool) == true
        let contentIsList = dict["content"] is [Any]
        return hasMultimodal && contentIsList
    }

    /// Extract a plain-text view of a multimodal tool result (= hermes
    /// `_multimodal_text_summary` at
    /// `agent/tool_dispatch_helpers.py` L188-L208).
    ///
    /// Used wherever downstream code needs a string (= logging, previews,
    /// persistence size heuristics, fall-back content for providers
    /// that don't support multipart tool messages).
    ///
    /// Pure function (= no side effects; = hermes equivalent).
    static func multimodalTextSummary(_ value: Any) -> String {
        if isMultimodalToolResult(value), let dict = value as? [String: Any] {
            if let summary = dict["text_summary"] as? String, !summary.isEmpty {
                return summary
            }
            var parts: [String] = []
            if let content = dict["content"] as? [Any] {
                for part in content {
                    if let p = part as? [String: Any],
                       let type = p["type"] as? String,
                       type == "text",
                       let text = p["text"] as? String
                    {
                        parts.append(text)
                    }
                }
            }
            if !parts.isEmpty {
                return parts.joined(separator: "\n")
            }
            return "[multimodal tool result]"
        }
        if let s = value as? String {
            return s
        }
        // Best-effort JSON encoding for arbitrary values (= hermes
        // L206-L208 = `json.dumps(value, default=str)`).
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(
               withJSONObject: value,
               options: [.fragmentsAllowed]
           ),
           let encoded = String(data: data, encoding: .utf8)
        {
            return encoded
        }
        // Fallback for non-JSON-encodable values (= hermes
        // L208 = `str(value)`).
        return String(describing: value)
    }
}
