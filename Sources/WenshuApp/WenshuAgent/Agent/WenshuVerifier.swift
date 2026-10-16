// WenshuVerifier.swift
//
// Verifier that proves the wenshu `AgentProtocol` works against the
// minimax-cn key.
//
// Plain-language summary (user-readable):
//   - wenshu `AgentProtocol` (A2A protocol) → minimax-cn API
//     (Anthropic-compatible protocol).
//   - Goal: use the minimax-cn key to call the `MiniMax-M3` model;
//     verify a "ping" returns HTTP 200.
//   - Tests: (1) ping returns 200. (2) wenshu `AgentProtocol`
//     integrates with the minimax-cn API.

import Foundation
import os

// AUDIT.md §2.6 partial (2026-10-16 boss 2026-10-16 OOB
// "包要有 LOG 能力" arc): WenshuVerifier used to log to
// `com.wenshu/wenshuverifier` (= the legacy WenshuApp
// subsystem). The boss's "包要有 LOG 能力" directive
// means all agent / LLM-related logs should land in
// `com.wenshu.agent/...` (= the canonical WALogger
// subsystem; = matches hermes `agent.Agent` log
// shape; = the boss can filter Console.app by
// subsystem:com.wenshu.agent and see the full LLM
// trace).
private let wenshuLogger = Logger(subsystem: "com.wenshu.agent", category: "agent")

/// minimax-cn ground-truth probe (Anthropic-compatible protocol)
struct WenshuLLMMessage: Codable, Sendable {
    let role: String
    let content: String
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct WenshuLLMRequest: Codable, Sendable {
    let model: String
    let max_tokens: Int
    let messages: [WenshuLLMMessage]
    init(model: String, max_tokens: Int, messages: [WenshuLLMMessage]) {
        self.model = model
        self.max_tokens = max_tokens
        self.messages = messages
    }
}

// union content block (Apple Codable enum ground truth)
// Anthropic-compatible content blocks include text / thinking (CoT) / tool_use variants

// minimax-cn M2.7 returns thinking blocks before text (chain-of-thought pattern)
// returns plain text blocks. JSONDecoder keyed container used to hardcode-require "text" key
// in content[0] → M2.7 thinking block throws DecodingError.keyNotFound.
enum WenshuLLMBlock: Codable, Sendable, Equatable {
    case text(String)
    case thinking(text: String, signature: String?)
    case toolUse(id: String, name: String, input: String)
    case unknown(type: String, raw: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, thinking, signature, id, name, input
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        switch type {
        case "text":
            let text = try c.decode(String.self, forKey: .text)
            self = .text(text)
        case "thinking":
            let thinking = try c.decode(String.self, forKey: .thinking)
            let signature = try? c.decode(String.self, forKey: .signature)
            self = .thinking(text: thinking, signature: signature)
        case "tool_use":
            let id = try c.decode(String.self, forKey: .id)
            let name = try c.decode(String.self, forKey: .name)
            let input = try c.decode(String.self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        default:
            // unknown type: graceful fallback (= principle 1 graceful
            // degradation). `raw` only stores the type name; NSLog
            // already prints allKeys at debug time.
            self = .unknown(type: type, raw: type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .text)
        case .thinking(let s, let sig):
            try c.encode("thinking", forKey: .type)
            try c.encode(s, forKey: .thinking)
            try c.encodeIfPresent(sig, forKey: .signature)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        case .unknown(let type, _):
            try c.encode(type, forKey: .type)
        }
    }

    /// Extract user-visible text (text blocks concatenated). Thinking blocks are not surfaced here; they go through ChatMessage.thinking
    var displayText: String {
        switch self {
        case .text(let s): return s
        case .thinking: return ""
        case .toolUse: return ""
        case .unknown: return ""
        }
    }

    /// Extract thinking content (CoT pattern, Apple HIG footnote)
    var thinkingText: String? {
        if case .thinking(let s, _) = self { return s }
        return nil
    }
}

// real LLM API usage (Apple Anthropic protocol)
// { "usage": { "input_tokens": N, "output_tokens": N, "cache_creation_input_tokens": N, "cache_read_input_tokens": N } }
struct WenshuLLMUsage: Codable, Sendable, Equatable {
    let input_tokens: Int
    let output_tokens: Int
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
    var total_tokens: Int { input_tokens + output_tokens }

    init(
        input_tokens: Int,
        output_tokens: Int,
        cache_creation_input_tokens: Int? = nil,
        cache_read_input_tokens: Int? = nil
    ) {
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens
        self.cache_creation_input_tokens = cache_creation_input_tokens
        self.cache_read_input_tokens = cache_read_input_tokens
    }
}

struct WenshuLLMResponse: Codable, Sendable {
    let id: String
    let model: String
    let role: String
    let content: [WenshuLLMBlock]   // union decode (text / thinking / tool_use)
    let stop_reason: String?
    let usage: WenshuLLMUsage?

    init(id: String, model: String, role: String, content: [WenshuLLMBlock], stop_reason: String? = nil, usage: WenshuLLMUsage? = nil) {
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stop_reason = stop_reason
        self.usage = usage
    }
}

/// WenshuVerifier: ground-truth probe for wenshu AgentProtocol against the minimax-cn API
actor WenshuVerifier {
    /// System prompt injected on every LLM request. English-only rule + forbidden-vocab list + allowed-token clarification.
    /// Source of truth for wenshu pollution-defense. See .scratch/2026-08-22-pollution-mitigation/.
    static let systemPromptEnglishOnly: String = """
    You are an assistant for the wenshu project (English-only output). All committed artifacts (code comments, commit messages, documentation, prompts) must be in English.

    Forbidden vocabulary — NEVER emit under any circumstance, even in quoted text, example snippets, or hypothetical scenarios:
    修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障

    If you catch yourself about to emit one of these tokens, stop the sentence and rewrite using English equivalents (fix / change / replace / adjust / refactor).

    Required literal tokens (these are project-mandated, NOT pollution):
    - the-legacy-term-for-project-owner (legacy term for project owner) (= the user's address — project rule)
    - 文枢 (project brand name)
    - decide (verb: project owner decides X; = the design decision X)
    - decide-formally (verb: project owner formally decides X)
    - ※ (marker glyph used in project notation)
    """

    /// Stop sequences injected for short-output calls. Triggers Anthropic-compatible
    /// protocol to terminate generation on any forbidden token match.
    /// DO NOT use for long-output calls (chapter drafts) — would terminate
    /// the entire generation on first match, catastrophic for novel writing.
    static let shortOutputStopSequences: [String] = [
        "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
        "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
    ]

    private let model: String

    /// .002: apiKey + baseURL no longer frozen at init.
    /// They are resolved PER LLM CALL via resolveCredentials() — (see OOB.md #2026-08-23):
    /// when the user switches model/key, main + sub-agents must switch together,
    /// otherwise mismatch deadlock.
    init(baseURL: String? = nil, apiKey: String? = nil, model: WenshuLLMModel = .m3) {
        // model is the only captured value (it binds to verifier behavior, unlike credentials which are Settings-config).
        // apiKey / baseURL remain override-only parameters (for testing); default = nil → resolveCredentials() goes through UserDefaults + Keychain.
        _ = baseURL  // unused; resolveCredentials() handles via UserDefaults + ProviderCatalog
        _ = apiKey
        self.model = model.rawValue
    }

    /// Resolved credentials struct.
    struct ResolvedCredentials: Sendable {
        let apiKey: String
        let baseURL: String
        let providerSlug: String
    }

    /// resolveCredentials: read provider slug from UserDefaults + key from Keychain.
    /// Called on every send() invocation — no caching (Settings page may change key mid-session).
    /// Strategy:
    ///   1. UserDefaults `wenshu.llm.provider` override (matches the
    ///      `@AppStorage` binding in `SettingView.swift` line 45; =
    ///      `App.swift` line 221 reference is stale).
    ///      (if set, use it; else default to model.providerSlug)
    ///   2. Look up provider in `ProviderCatalog`
    ///   3. Load key from `AppleKeychain` for that provider slug
    ///   4. Return (apiKey, baseURL, providerSlug)
    nonisolated func resolveCredentials(model overrideModel: WenshuLLMModel? = nil) throws -> ResolvedCredentials {
        let modelEnum = overrideModel ?? WenshuLLMModel(rawValue: model) ?? .m3
        // 1. Provider slug: UserDefaults override (if any), else
        // model.providerSlug. NOTE: key name `wenshu.llm.provider`
        // matches the `@AppStorage` binding in `SettingView.swift`
        // line 45 (= `App.swift` line 221 reference is stale).
        // was `wenshu.provider.slug` (= never matched the
        // existing `@AppStorage` binding, so the override never took
        // effect).
        let userDefaultsSlug = UserDefaults.standard.string(forKey: "wenshu.llm.provider")
        // 
        // replaced `userDefaultsSlug?.isEmpty == false ? userDefaultsSlug! : ...`
        // (= audit's LOW smell; = the `!` is logically safe given the
        // predicate but reads as a hidden force-unwrap) with explicit
        // if-let-let (= no force-unwrap; = same behavior).
        let effectiveSlug: String
        if let slug = userDefaultsSlug, !slug.isEmpty {
            effectiveSlug = slug
        } else {
            effectiveSlug = modelEnum.providerSlug
        }
        // 2. Look up provider.
        guard let provider = Provider.by(slug: effectiveSlug) else {
            throw LLMConnectorError.unsupportedProvider(slug: effectiveSlug)
        }
        // 3. Load key from Keychain for that provider.
        // use the shared ProviderKeychain backend (= respects
        // setBackendForTesting for dev/cua verify) instead of constructing
        // a fresh AppleKeychainStore (which would always hit the real
        // keychain regardless of the debug override).
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: effectiveSlug)
        }
        return ResolvedCredentials(
            apiKey: key,
            baseURL: provider.defaultBaseURL,
            providerSlug: effectiveSlug
        )
    }

    /// ping: simple 1-message ground-truth probe
    func ping() async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: model,
            max_tokens: 50,
            messages: [WenshuLLMMessage(role: "user", content: "ping")]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// chat: 1-message user-content ground-truth probe (= the fallback
    /// when the `AgentProtocol` LLM call fails; = routes here via
    /// `ChatViewModel`).
    func chat(_ text: String) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: model,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// chat overload that takes model at call time
    /// used self.model from init = hardcoded)
    /// This overload lets ChatViewModel pass current model from UserDefaults at call time
    func chat(_ text: String, model overrideModel: String) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: overrideModel,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// (Wenshu agent base identity): chat overload that takes an explicit system prompt.
    /// Used by WenshuConductor to prepend the agent identity (WenshuConductorIdentity.systemPrompt).
    /// Default model = self.model (conductor uses runtime model).
    func chat(_ text: String, system: String, model overrideModel: String? = nil) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: overrideModel ?? model,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText, extraSystemPrompt: system)
    }

    /// send: actually call the minimax-cn API (Apple URLSession ground truth)
    /// `extraSystemPrompt` is appended after the built-in English-only constant.
    /// The Anthropic-compatible request body always carries `systemPromptEnglishOnly` as the first system segment.
    /// `outputKind` controls whether `stop_sequences` is attached (short outputs only).
    func send(
        request: WenshuLLMRequest,
        outputKind: OutputKind = .chat,
        extraSystemPrompt: String? = nil
    ) async throws -> WenshuLLMResponse {
        // .002: resolve credentials per call ((see OOB.md #2026-08-23)).
        // UserDefaults + Keychain are read fresh each time so Settings changes
        // take effect immediately on the next LLM call.
        let creds = try resolveCredentials()
        guard !creds.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: creds.providerSlug)
        }
        guard let url = URL(string: "\(creds.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: creds.baseURL)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(creds.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        // Anthropic-compatible protocol: `system` is a top-level body field, NOT in messages array.
        // Built-in English-only constant goes first; caller-supplied extra prompt follows.
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.max_tokens,
            "messages": request.messages.map { ["role": $0.role, "content": $0.content] },
            // concatenate system prompts into a single string
            // instead of array. Some minimax cn API deployments ignore second
            // entry when 'system' is an array (= single-string protocol fallback).
            // Mirrors hermes-agent/gateway/run.py single context_prompt pattern.
            "system": (extraSystemPrompt ?? "").isEmpty
                ? WenshuVerifier.systemPromptEnglishOnly
                : WenshuVerifier.systemPromptEnglishOnly + "\n\n---\n\n" + (extraSystemPrompt ?? ""),
        ]
        // Tier 2 of pollution-defense: stop_sequences for short outputs.
        // Anthropic protocol terminates generation on first match — fine for short
        // outputs (re-generate is cheap), catastrophic for chapter drafts.
        if outputKind == .shortText {
            body["stop_sequences"] = WenshuVerifier.shortOutputStopSequences
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        wenshuLogger.info("verifier request model=\(request.model) max_tokens=\(request.max_tokens) messages=\(request.messages.count)")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
        wenshuLogger.info("verifier response status=\(statusCode) body=\(bodyPreview, privacy: .private)")
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LLMConnectorError.transport(provider: creds.providerSlug, statusCode: statusCode, body: bodyPreview)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WenshuLLMResponse.self, from: data)
        } catch {
            wenshuLogger.info("verifier decoder error: \(String(describing: error), privacy: .private)")
            throw error
        }
    }

    /// sendViaMinimaxConnector: thin façade that delegates to the new
    /// `LLMConnector` protocol via `MinimaxConnector`.
    ///
    /// Translates `WenshuLLMRequest` ↔ `LLMMessage` and
    /// `WenshuLLMResponse` ↔ `LLMResponse`
    /// so the existing WenshuLLMRequest-based call sites (= AgentRuntime,
    /// the chat persistence layer) can opt in to the new LLMConnector protocol
    /// without breaking the established send() path.
    ///
    /// sub-step 8 (= TB-B tracer-bullet). Existing send()
    /// below remains the production path until all call sites migrate.
    func sendViaMinimaxConnector(
        request: WenshuLLMRequest,
        outputKind: OutputKind = .chat,
        extraSystemPrompt: String? = nil
    ) async throws -> WenshuLLMResponse {
        // Translate WenshuLLMRequest → LLMMessage list
        let messages: [LLMMessage] = request.messages.map { msg in
            LLMMessage(role: LLMMessage.Role(rawValue: msg.role) ?? .user, blocks: [.text(msg.content)])
        }

        // Build LLMCallOptions
        let systemPrompt: String? = (extraSystemPrompt ?? "").isEmpty
            ? WenshuVerifier.systemPromptEnglishOnly
            : WenshuVerifier.systemPromptEnglishOnly + "\n\n---\n\n" + (extraSystemPrompt ?? "")
        let options = LLMCallOptions(
            model: request.model,
            maxTokens: request.max_tokens,
            systemPrompt: systemPrompt,
            temperature: nil
        )

        // Delegate to LLMConnector protocol (= wenshu-side wins thin facade)
        let connector = MinimaxConnector()
        let response = try await connector.send(messages: messages, options: options)

        // Translate LLMResponse → WenshuLLMResponse (= preserve public API)
        let content: [WenshuLLMBlock] = response.blocks.map { block in
            switch block {
            case .text(let s):
                return .text(s)
            case .thinking(let text, let signature):
                return .thinking(text: text, signature: signature)
            case .toolUse(let id, let name, let input):
                return .toolUse(id: id, name: name, input: input)
            case .toolResult(_, let output):
                return .text(output)  // collapse to text in legacy surface
            }
        }
        let stopReasonString: String
        switch response.stopReason {
        case .endTurn: stopReasonString = "end_turn"
        case .toolUse: stopReasonString = "tool_use"
        case .maxTokens: stopReasonString = "max_tokens"
        case .stopSequence: stopReasonString = "stop_sequence"
        case .unknown: stopReasonString = "unknown"
        }
        let usage = WenshuLLMUsage(
            input_tokens: response.usage.inputTokens,
            output_tokens: response.usage.outputTokens
        )
        return WenshuLLMResponse(
            id: response.id,
            model: response.model,
            role: "assistant",
            content: content,
            stop_reason: stopReasonString,
            usage: usage
        )
    }

}
