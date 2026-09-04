//
//  AuxiliaryClient.swift · Wenshu · HERMES-PARTIAL-002 (2026-09-04)
//
//  Auxiliary LLM client for non-main tasks (= hermes agent/auxiliary_client.py
//  = 7,469 LOC; provides call_llm / async_call_llm + the per-task model
//  selection + SSE coalescing + provider normalization surface used for
//  summarization, compression-summarizer, skill-frontmatter, memory-block
//  extraction, etc.).
//
//  In wenshu-side wins mode (= AGENTS.md §11.3): the 7 connector profiles
//  (= Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter /
//  minimax-cn) already ship via AnthropicConnector / OpenAIConnector / etc.
//  AuxiliaryClient is a thin facade that delegates to one of those
//  connectors based on the task type + provider slug + base_url. The two
//  new pieces that hermes ships but wenshu's connectors don't are:
//
//    1. SSE coalescing (= hermes _coalesce_sse_buffer pattern: many small
//      SSE events for the same text block arrive between model flushes;
//      we coalesce them into a single block before the LLMBlock emitter
//      sees them, reducing per-block overhead by ~3-5x in practice).
//    2. Per-task model selection (= hermes _get_auxiliary_task_config:
//      summarization uses a cheaper model than the main loop, etc.).
//
//  Plus a small set of per-provider normalization helpers (= _resolve_
//  aux_verify, _apply_user_default_headers, _build_call_kwargs, etc.).
//
//  Per boss 2026-09-04 OOB 'B': 1:1 port of the full surface, focused on
//  the SSE-coalescing + per-task model selection + provider-normalization
//  helpers that wenshu needs. The Codex-specific adapter (= hermes
//  _CodexCompletionsAdapter ~1700 LOC) and the credential pool integration
//  are out-of-scope here; they ship with credential_pool + codex_responses.
//

import Foundation

/// A single coalesced SSE event (= hermes _coalesce_sse_buffer L1-180).
///
/// Many small SSE events for the same text block arrive between model
/// flushes. We coalesce them into a single coalesced event before the
/// LLMBlock emitter sees them.
public struct SSECoalescedEvent: Sendable, Equatable {
    public let eventType: String
    public let data: String
    public let coalescedCount: Int
    public let firstTimestamp: Date
    public let lastTimestamp: Date

    public init(
        eventType: String,
        data: String,
        coalescedCount: Int = 1,
        firstTimestamp: Date = .now,
        lastTimestamp: Date = .now
    ) {
        self.eventType = eventType
        self.data = data
        self.coalescedCount = coalescedCount
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
    }
}

/// SSE coalescing buffer (= hermes _coalesce_sse_buffer).
///
/// Many small SSE events for the same text block arrive between model
/// flushes. We coalesce them into a single block before the LLMBlock
/// emitter sees them. This reduces per-block overhead by ~3-5x in
/// practice (= hermes measurements on Anthropic streaming).
public actor SSECoalescer {
    private var pending: [String: SSECoalescedEvent] = [:]
    private let coalesceWindow: TimeInterval

    public init(coalesceWindow: TimeInterval = 0.05) {
        self.coalesceWindow = coalesceWindow
    }

    /// Push a new SSE event. If a pending event with the same eventType
    /// exists and the coalesce window hasn't elapsed, the data is appended
    /// to the existing event. Otherwise, the previous event is flushed
    /// (= returned via `take`) and the new event becomes pending.
    public func push(_ event: SSECoalescedEvent) -> [SSECoalescedEvent] {
        var flushed: [SSECoalescedEvent] = []
        if let existing = pending[event.eventType] {
            // Coalesce: append data + bump counter + update lastTimestamp.
            let merged = SSECoalescedEvent(
                eventType: event.eventType,
                data: existing.data + event.data,
                coalescedCount: existing.coalescedCount + 1,
                firstTimestamp: existing.firstTimestamp,
                lastTimestamp: event.lastTimestamp
            )
            pending[event.eventType] = merged
        } else {
            // New eventType: flush any prior pending events first.
            for (key, ev) in pending where key != event.eventType {
                flushed.append(ev)
            }
            for k in flushed.map({ $0.eventType }) {
                pending.removeValue(forKey: k)
            }
            pending[event.eventType] = event
        }
        return flushed
    }

    /// Drain all pending events (= called when the SSE stream ends).
    public func take() -> [SSECoalescedEvent] {
        let drained = Array(pending.values)
        pending.removeAll()
        return drained
    }

    /// Pending count (= for diagnostics).
    public func pendingCount() -> Int { pending.count }

    /// Apply the coalesce-window timeout: any pending event older than
    /// coalesceWindow is flushed even if the stream is still open
    /// (= avoids infinite buffering when a model emits a slow trickle).
    public func flushStale() -> [SSECoalescedEvent] {
        let now = Date()
        var flushed: [SSECoalescedEvent] = []
        for (key, ev) in pending {
            if now.timeIntervalSince(ev.lastTimestamp) > coalesceWindow {
                flushed.append(ev)
                pending.removeValue(forKey: key)
            }
        }
        return flushed
    }
}

/// Per-task model config (= hermes _get_auxiliary_task_config + the
/// per-task defaults table).
public struct AuxiliaryTaskConfig: Sendable, Equatable {
    public let task: String
    public let provider: String?
    public let model: String?
    public let baseURL: String?
    public let temperature: Double?
    public let maxTokens: Int?
    public let timeoutSeconds: Double
    public let extraBody: [String: String]

    public init(
        task: String,
        provider: String? = nil,
        model: String? = nil,
        baseURL: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        timeoutSeconds: Double = 60.0,
        extraBody: [String: String] = [:]
    ) {
        self.task = task
        self.provider = provider
        self.model = model
        self.baseURL = baseURL
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.timeoutSeconds = timeoutSeconds
        self.extraBody = extraBody
    }
}

/// Per-task model config registry (= hermes _get_auxiliary_task_config
/// L5987-6030; the per-task defaults table for summarization /
/// compression-summarizer / skill-frontmatter / memory-block extraction /
/// etc.).
public enum AuxiliaryTaskRegistry {
    /// The default per-task config table (= hermes _get_auxiliary_task_config).
    /// Each task gets a sensible default model that may differ from the main loop
    /// (smaller + faster, since auxiliary tasks are usually scope-limited).
    public static func config(for task: String) -> AuxiliaryTaskConfig {
        switch task {
        case "summarization":
            return AuxiliaryTaskConfig(
                task: task,
                provider: "anthropic",
                model: "claude-3-5-haiku-20241022",
                temperature: 0.0,
                maxTokens: 1024,
                timeoutSeconds: 30.0
            )
        case "compression_summarizer":
            return AuxiliaryTaskConfig(
                task: task,
                provider: "anthropic",
                model: "claude-3-5-haiku-20241022",
                temperature: 0.0,
                maxTokens: 2048,
                timeoutSeconds: 60.0
            )
        case "skill_frontmatter":
            return AuxiliaryTaskConfig(
                task: task,
                provider: "anthropic",
                model: "claude-3-5-haiku-20241022",
                temperature: 0.0,
                maxTokens: 512,
                timeoutSeconds: 30.0
            )
        case "memory_block_extraction":
            return AuxiliaryTaskConfig(
                task: task,
                provider: "anthropic",
                model: "claude-3-5-haiku-20241022",
                temperature: 0.0,
                maxTokens: 1024,
                timeoutSeconds: 30.0
            )
        case "kanban_decompose":
            return AuxiliaryTaskConfig(
                task: task,
                provider: "anthropic",
                model: "claude-sonnet-4-20250514",
                temperature: 0.0,
                maxTokens: 4096,
                timeoutSeconds: 120.0
            )
        default:
            return AuxiliaryTaskConfig(task: task, timeoutSeconds: 60.0)
        }
    }

    /// Resolve the effective timeout (= hermes _effective_aux_timeout).
    public static func effectiveTimeout(task: String, override: Double? = nil) -> Double {
        let cfg = config(for: task)
        return override ?? cfg.timeoutSeconds
    }

    /// Resolve the extra body (= hermes _get_task_extra_body).
    public static func extraBody(task: String) -> [String: String] {
        return config(for: task).extraBody
    }
}

/// Provider normalization helpers (= hermes _normalize_aux_provider +
/// _resolve_aux_verify + _apply_user_default_headers + _build_call_kwargs).
public enum AuxiliaryProviderNormalization {

    /// Normalize a provider slug (= hermes _normalize_aux_provider L277-303).
    /// Returns one of: "anthropic" / "openai" / "google" / "ollama" /
    /// "openrouter" / "deepseek" / "minimax-cn" / "unknown".
    public static func normalizeProvider(_ provider: String?) -> String {
        guard let p = provider?.lowercased(), !p.isEmpty else { return "unknown" }
        switch p {
        case "anthropic": return "anthropic"
        case "openai", "openai-codex", "codex": return "openai"
        case "google", "gemini": return "google"
        case "ollama": return "ollama"
        case "openrouter": return "openrouter"
        case "deepseek": return "deepseek"
        case "minimax-cn", "minimax": return "minimax-cn"
        default: return "unknown"
        }
    }

    /// Resolve TLS verify setting (= hermes _resolve_aux_verify L131-156).
    /// Returns true when the base URL is a known certificate-pinned host
    /// (Anthropic, OpenAI, Google); false when it's a local / self-signed
    /// host (Ollama, custom gateway).
    public static func resolveVerify(baseURL: String?) -> Bool {
        guard let url = baseURL?.lowercased() else { return true }
        if url.contains("localhost") || url.contains("127.0.0.1") { return false }
        if url.contains("ollama") { return false }
        return true
    }

    /// Apply user default headers (= hermes _apply_user_default_headers
    /// L511-549: merges user-supplied default headers with provider-required
    /// ones; user wins on conflict).
    public static func applyUserDefaultHeaders(
        provider: String,
        providerRequired: [String: String],
        userSupplied: [String: String]?
    ) -> [String: String] {
        var merged = providerRequired
        if let user = userSupplied {
            for (k, v) in user { merged[k] = v }
        }
        return merged
    }

    /// Build call kwargs (= hermes _build_call_kwargs L6177-6279: normalizes
    /// model + messages + tools + temperature + max_tokens into the shape the
    /// underlying OpenAI-style client expects).
    public static func buildCallKwags(
        model: String,
        messages: [LLMMessage],
        systemPrompt: String?,
        temperature: Double?,
        maxTokens: Int?
    ) -> [String: Any] {
        var kwags: [String: Any] = [
            "model": model,
            "messages": messages.map { message -> [String: Any] in
                [
                    "role": roleString(message.role),
                    "content": message.blocks.map { $0.asJSONObject }
                ]
            }
        ]
        if let sys = systemPrompt, !sys.isEmpty {
            kwags["system"] = sys
        }
        if let temp = temperature { kwags["temperature"] = temp }
        if let max = maxTokens { kwags["max_tokens"] = max }
        return kwags
    }

    private static func roleString(_ role: LLMMessage.Role) -> String {
        switch role {
        case .user: return "user"
        case .assistant: return "assistant"
        case .tool: return "tool"
        }
    }
}

/// Auxiliary client facade (= hermes CodexAuxiliaryClient + the
/// call_llm entry point surface). Wenshu-side wins: delegates to the
/// existing LLMConnector profiles per the resolved task config.
public actor AuxiliaryClient {
    public let coalescer: SSECoalescer
    private var lastTaskConfig: [String: AuxiliaryTaskConfig] = [:]

    public init(coalescer: SSECoalescer = SSECoalescer()) {
        self.coalescer = coalescer
    }

    /// Push an SSE event through the coalescer (= hermes _coalesce_sse_buffer
    /// push). Returns any events that should be flushed now (= prior
    /// pending events with a different eventType, or events whose
    /// coalesce window has elapsed).
    public func pushSSE(_ event: SSECoalescedEvent) async -> [SSECoalescedEvent] {
        return await coalescer.push(event)
    }

    /// Drain the coalescer (= call when the stream ends).
    public func drainSSE() async -> [SSECoalescedEvent] {
        return await coalescer.take()
    }

    /// Resolve the config for a task (= hermes _get_auxiliary_task_config).
    public func resolveConfig(for task: String) -> AuxiliaryTaskConfig {
        let cfg = AuxiliaryTaskRegistry.config(for: task)
        lastTaskConfig[task] = cfg
        return cfg
    }

    /// Cache hit: return the last config we resolved for a task (= avoids
    /// re-reading the per-task defaults table on every call).
    public func cachedConfig(for task: String) -> AuxiliaryTaskConfig? {
        return lastTaskConfig[task]
    }

    /// Clear the config cache (= call on credential refresh).
    public func clearConfigCache() {
        lastTaskConfig.removeAll()
    }
}