//
//  WenshuVerifier.swift · Wenshu · v0.18 ticket 31 (verify MiniMax key)
//
//  验证 wenshu AgentProtocol 用 MiniMax key 调通.
//  老板 2026-08-19 拍 "验证, 用我们的 MiniMax 的 key 看能否真的用你复刻的 hermes 核心调通 anget".
//
//  业务语言描述 (老板懂):
//  - wenshu AgentProtocol (A2A 协议) → MiniMax API (Anthropic 兼容协议)
//  - 真值: 用 MiniMax key 调 MiniMax-M3 模型, 验证 "ping" 返 200
//  - 测试: 1) ping 返 200 2) wenshu AgentProtocol 跟 MiniMax API 集成
//

import Foundation

/// MiniMax 真值 (Anthropic 兼容协议)
public struct WenshuLLMMessage: Codable, Sendable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct WenshuLLMRequest: Codable, Sendable {
    public let model: String
    public let max_tokens: Int
    public let messages: [WenshuLLMMessage]
    public init(model: String, max_tokens: Int, messages: [WenshuLLMMessage]) {
        self.model = model
        self.max_tokens = max_tokens
        self.messages = messages
    }
}

// v0.21 ticket 39: union content block (Apple Codable enum 真值)
// Anthropic-compatible content blocks include text / thinking (CoT) / tool_use variants
// MiniMax M2.7 returns thinking blocks before text (chain-of-thought 范式)
// M3 returns plain text blocks. JSONDecoder keyed container 之前 hardcoded require "text" key
// 在 content[0] → M2.7 thinking block 抛 DecodingError.keyNotFound.
public enum WenshuLLMBlock: Codable, Sendable, Equatable {
    case text(String)
    case thinking(text: String, signature: String?)
    case toolUse(id: String, name: String, input: String)
    case unknown(type: String, raw: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, thinking, signature, id, name, input
    }

    public init(from decoder: Decoder) throws {
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
            // unknown type: 容错 (Q26 原则 1 优雅降级). raw 只存 type 名, 调试时 NSLog 已印 allKeys
            self = .unknown(type: type, raw: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
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

    /// 提取用户可见文本 (text blocks concat). Thinking blocks 不在此暴露, 走 ChatMessage.thinking 字段
    public var displayText: String {
        switch self {
        case .text(let s): return s
        case .thinking: return ""
        case .toolUse: return ""
        case .unknown: return ""
        }
    }

    /// 提取 thinking 内容 (CoT 范式, Apple HIG footnote)
    public var thinkingText: String? {
        if case .thinking(let s, _) = self { return s }
        return nil
    }
}

// v0.21 ticket 34: real LLM API usage (Apple Anthropic protocol)
// { "usage": { "input_tokens": N, "output_tokens": N, "cache_creation_input_tokens": N, "cache_read_input_tokens": N } }
public struct WenshuLLMUsage: Codable, Sendable, Equatable {
    public let input_tokens: Int
    public let output_tokens: Int
    public let cache_creation_input_tokens: Int?
    public let cache_read_input_tokens: Int?
    public var total_tokens: Int { input_tokens + output_tokens }

    public init(
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

public struct WenshuLLMResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let role: String
    public let content: [WenshuLLMBlock]   // v0.21 ticket 39: union decode (text / thinking / tool_use)
    public let stop_reason: String?
    public let usage: WenshuLLMUsage?

    public init(id: String, model: String, role: String, content: [WenshuLLMBlock], stop_reason: String? = nil, usage: WenshuLLMUsage? = nil) {
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stop_reason = stop_reason
        self.usage = usage
    }
}

/// WenshuVerifier: 验证 wenshu AgentProtocol 调 MiniMax API 真值
public actor WenshuVerifier {
    /// System prompt injected on every LLM request. English-only rule + forbidden-vocab list + allowed-token clarification.
    /// Source of truth for wenshu pollution-defense. See .scratch/2026-08-22-pollution-mitigation/.
    public static let systemPromptEnglishOnly: String = """
    You are an assistant for the wenshu project (English-only output). All committed artifacts (code comments, commit messages, documentation, prompts) must be in English.

    Forbidden vocabulary — NEVER emit under any circumstance, even in quoted text, example snippets, or hypothetical scenarios:
    修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障

    If you catch yourself about to emit one of these tokens, stop the sentence and rewrite using English equivalents (fix / change / replace / adjust / refactor).

    Required literal tokens (these are project-mandated, NOT pollution):
    - 老板 (boss, the user's address — project rule)
    - 文枢 (project brand name)
    - 拍 (verb: 老板 拍 X = boss decides X)
    - 拍板 (verb: 老板 拍板 X = boss board-decides X)
    - ※ (marker glyph used in project notation)
    """

    /// Stop sequences injected for short-output calls. Triggers Anthropic-compatible
    /// protocol to terminate generation on any forbidden token match.
    /// DO NOT use for long-output calls (chapter drafts) — would terminate
    /// the entire generation on first match, catastrophic for novel writing.
    public static let shortOutputStopSequences: [String] = [
        "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
        "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
    ]

    private let model: String

    /// v0.23 ticket 010.002: apiKey + baseURL no longer frozen at init.
    /// They are resolved PER LLM CALL via resolveCredentials() — boss 8/23 拍:
    /// 用户切 model/key 后主 + 子 agent 必须同步切,否则 mismatch 卡死.
    public init(baseURL: String? = nil, apiKey: String? = nil, model: WenshuLLMModel = .m3) {
        // model 是唯一 capture 的 (它跟 verifier 行为绑定,不像 credentials 是 Settings 配置).
        // apiKey / baseURL 留作 override-only 参数 (测试用), default = nil → resolveCredentials() 走 UserDefaults + Keychain.
        _ = baseURL  // unused; resolveCredentials() handles via UserDefaults + ProviderCatalog
        _ = apiKey
        self.model = model.rawValue
    }

    /// Resolved credentials struct.
    public struct ResolvedCredentials: Sendable {
        public let apiKey: String
        public let baseURL: String
        public let providerSlug: String
    }

    /// resolveCredentials: read provider slug from UserDefaults + key from Keychain.
    /// Called on every send() invocation — no caching (Settings page may change key mid-session).
    /// Strategy:
    ///   1. UserDefaults "wenshu.llm.provider" override (matches @AppStorage in App.swift line 221)
    ///      (if set, use it; else default to model.providerSlug)
    ///   2. Look up provider in ProviderCatalog
    ///   3. Load key from AppleKeychain for that provider slug
    ///   4. Return (apiKey, baseURL, providerSlug)
    public nonisolated func resolveCredentials(model overrideModel: WenshuLLMModel? = nil) throws -> ResolvedCredentials {
        let modelEnum = overrideModel ?? WenshuLLMModel(rawValue: model) ?? .m3
        // 1. Provider slug: UserDefaults override (if any), else model.providerSlug.
        // NOTE: key name 'wenshu.llm.provider' matches @AppStorage in App.swift line 221.
        // (v0.23 ticket 010.005 fix — was 'wenshu.provider.slug' which never matched the
        // existing @AppStorage binding, so the override never took effect.)
        let userDefaultsSlug = UserDefaults.standard.string(forKey: "wenshu.llm.provider")
        let effectiveSlug = userDefaultsSlug?.isEmpty == false ? userDefaultsSlug! : modelEnum.providerSlug
        // 2. Look up provider.
        guard let provider = Provider.by(slug: effectiveSlug) else {
            throw WenshuLLMError.invalidBaseURL(url: "unknown provider slug: \(effectiveSlug)")
        }
        // 3. Load key from Keychain for that provider.
        // v0.28 followup: use the shared ProviderKeychain backend (= respects
        // setBackendForTesting for dev/cua verify) instead of constructing
        // a fresh AppleKeychainStore (which would always hit the real
        // keychain regardless of the debug override).
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else {
            throw WenshuLLMError.missingAPIKey  // existing error type
        }
        return ResolvedCredentials(
            apiKey: key,
            baseURL: provider.defaultBaseURL,
            providerSlug: effectiveSlug
        )
    }

    /// ping: 简单 1 消息真值
    public func ping() async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: model,
            max_tokens: 50,
            messages: [WenshuLLMMessage(role: "user", content: "ping")]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// chat: 1 消息 user content 真值 (v0.21 ticket 03 fallback 用, AgentProtocol LLM 失败后 ChatViewModel 走这条)
    public func chat(_ text: String) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: model,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// v0.21 ticket 38: chat overload that takes model at call time
    /// (boss 2026-08-22 反馈 "切换了 AI 没有真的换" = original chat() uses self.model from init = hardcoded)
    /// This overload lets ChatViewModel pass current model from UserDefaults at call time
    public func chat(_ text: String, model overrideModel: String) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: overrideModel,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText)
    }

    /// v0.22 ticket 001 (文枢 agent 基础设定): chat overload that takes an explicit system prompt.
    /// Used by WenshuConductor to prepend the agent identity (WenshuConductorIdentity.systemPrompt).
    /// Default model = self.model (conductor uses runtime model).
    public func chat(_ text: String, system: String, model overrideModel: String? = nil) async throws -> WenshuLLMResponse {
        let request = WenshuLLMRequest(
            model: overrideModel ?? model,
            max_tokens: 1024,
            messages: [WenshuLLMMessage(role: "user", content: text)]
        )
        return try await send(request: request, outputKind: .shortText, extraSystemPrompt: system)
    }

    /// send: 实际调 MiniMax API (Apple URLSession 真值)
    /// `extraSystemPrompt` is appended after the built-in English-only constant.
    /// The Anthropic-compatible request body always carries `systemPromptEnglishOnly` as the first system segment.
    /// `outputKind` controls whether `stop_sequences` is attached (short outputs only).
    public func send(
        request: WenshuLLMRequest,
        outputKind: OutputKind = .chat,
        extraSystemPrompt: String? = nil
    ) async throws -> WenshuLLMResponse {
        // v0.23 ticket 010.002: resolve credentials per call (boss 8/23 拍).
        // UserDefaults + Keychain are read fresh each time so Settings changes
        // take effect immediately on the next LLM call.
        let creds = try resolveCredentials()
        guard !creds.apiKey.isEmpty else {
            throw WenshuLLMError.missingAPIKey
        }
        guard let url = URL(string: "\(creds.baseURL)/v1/messages") else {
            throw WenshuLLMError.invalidBaseURL(url: creds.baseURL)
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
            // v0.24 boss验收fix (Boss 8/24 OOB): concat system prompts into single string
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
        NSLog("[wenshu.chat] request: model=%@ max_tokens=%d messages=%d", request.model, request.max_tokens, request.messages.count)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
        NSLog("[wenshu.chat] response status=%d body=%@", statusCode, bodyPreview)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WenshuLLMError.httpError(statusCode: statusCode, body: bodyPreview)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(WenshuLLMResponse.self, from: data)
        } catch {
            NSLog("[wenshu.chat] decoder error: %@", String(describing: error))
            throw error
        }
    }

    /// sendViaMinimaxConnector: thin facade that delegates to the new
    /// LLMConnector protocol via MinimaxConnector (= ticket 001 sub-step 8).
    ///
    /// Translates WenshuLLMRequest ↔ LLMMessage and WenshuLLMResponse ↔ LLMResponse
    /// so the existing WenshuLLMRequest-based call sites (= AgentRuntime,
    /// ChatSessionStore) can opt in to the new LLMConnector protocol without
    /// breaking the established send() path.
    ///
    /// v0.35 ticket 001 sub-step 8 (= TB-B tracer-bullet). Existing send()
    /// below remains the production path until all call sites migrate.
    public func sendViaMinimaxConnector(
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
            case .toolResult(let toolUseID, let output):
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

    // MARK: - v0.34 SSE streaming (= Issue 07)

    /// Streaming variant of `chat()`. Returns an `AsyncThrowingStream`
    /// of `WenshuLLMBlock` (= `.text` for incremental text chunks,
    /// `.thinking` for thinking-mode deltas, `.toolUse` for tool-call
    /// deltas). Caller iterates with `for try await block in stream`
    /// and renders each text chunk as it arrives (= user sees
    /// streaming output character-by-character, like ChatGPT).
    ///
    /// Anthropic Messages API SSE format (= W3C SSE envelope):
    /// `event: <name>\n data: <json>\n\n`; we only consume `event:`
    /// names matching `content_block_delta` (= yields the inner
    /// `delta.text` chunk per event) and `message_delta` (= yields
    /// final usage; the last event is `message_stop` which we use
    /// to finish the stream).
    ///
    /// Apple-API-first check: `URLSession.bytes(for:)` (= macOS 12+;
    /// async stream of HTTP response bytes = Apple canonical SSE
    /// transport; no third-party HTTP client needed). The
    /// `SSEClient` actor (= AI/SSEClient.swift) parses the W3C SSE
    /// envelope; here we only interpret Anthropic's content_block_delta
    /// JSON.
    ///
    /// Cancellation: drop the AsyncThrowingStream (= the URLSession
    /// bytes task is automatically cancelled; partial chunks are
    /// discarded).
    public nonisolated func streamChat(
        _ text: String,
        system: String,
        model overrideModel: String? = nil
    ) -> AsyncThrowingStream<WenshuLLMBlock, Error> {
        let effectiveModel = overrideModel ?? model
        // v0.34: build the request URL + headers the same way as
        // `send()` (= avoid duplicating credential resolution logic).
        // We resolve credentials here (= we don't `throw` from a
        // streaming init; we surface errors via the stream's first
        // iteration).
        let request: WenshuLLMRequest
        do {
            request = WenshuLLMRequest(
                model: effectiveModel,
                max_tokens: 1024,
                messages: [WenshuLLMMessage(role: "user", content: text)]
            )
        }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let creds = try resolveCredentials()
                    guard !creds.apiKey.isEmpty else {
                        throw WenshuLLMError.missingAPIKey
                    }
                    guard let url = URL(string: "\(creds.baseURL)/v1/messages") else {
                        throw WenshuLLMError.invalidBaseURL(url: creds.baseURL)
                    }
                    // Build POST body with `stream: true` (= Anthropic
                    // SSE handshake).
                    var body: [String: Any] = [
                        "model": effectiveModel,
                        "max_tokens": 1024,
                        "stream": true,
                        "messages": [["role": "user", "content": text]],
                        "system": system.isEmpty
                            ? WenshuVerifier.systemPromptEnglishOnly
                            : WenshuVerifier.systemPromptEnglishOnly + "\n\n---\n\n" + system
                    ]
                    let jsonBody = try JSONSerialization.data(withJSONObject: body)
                    let sse = SSEClient(url: url, headers: [
                        "x-api-key": creds.apiKey,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json"
                    ])
                    let stream = await sse.stream()
                    var textBuffer = ""
                    for try await event in stream {
                        if Task.isCancelled { break }
                        // Anthropic SSE payload is JSON in `event.data`.
                        guard let data = event.data.data(using: .utf8) else { continue }
                        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        let type = json["type"] as? String ?? ""
                        if type == "content_block_delta" {
                            // Inner shape: { delta: { type: "text_delta", text: "Hello" } }
                            if let delta = json["delta"] as? [String: Any],
                               let dType = delta["type"] as? String,
                               dType == "text_delta",
                               let text = delta["text"] as? String {
                                textBuffer += text
                                continuation.yield(.text(text))
                            }
                        } else if type == "content_block_start" {
                            // Inner shape: { content_block: { type: "thinking" | "text" | "tool_use", ... } }
                            // We don't yield here; deltas follow.
                            _ = json
                        } else if type == "message_stop" {
                            break
                        } else if type == "error" {
                            // Anthropic SSE error envelope:
                            // { type: "error", error: { type: "...", message: "..." } }
                            if let errDict = json["error"] as? [String: Any],
                               let msg = errDict["message"] as? String {
                                throw WenshuLLMError.httpError(statusCode: -1, body: msg)
                            }
                        }
                    }
                    NSLog("[wenshu.stream] complete, textBuffer length=%d", textBuffer.count)
                    continuation.finish()
                } catch {
                    NSLog("[wenshu.stream] error: %@", String(describing: error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

public enum WenshuLLMError: Error, LocalizedError {
    case missingAPIKey
    case invalidBaseURL(url: String)
    case httpError(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key 未配置. 请在 Settings → Provider 配置 API key."
        case .invalidBaseURL(let url):
            return "Provider base URL 无效: \(url). 请在 Settings 检查 provider 选择."
        case .httpError(let statusCode, let body):
            // Show status code + brief body (truncated for UI).
            let brief = body.prefix(120)
            return "LLM HTTP \(statusCode): \(brief)"
        }
    }
}