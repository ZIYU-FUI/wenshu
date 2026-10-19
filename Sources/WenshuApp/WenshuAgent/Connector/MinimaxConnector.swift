// MinimaxConnector.swift
//
// Minimax cn connector (= Anthropic-compatible wire format
// peer of AnthropicConnector). Per AGENTS.md §11.2: Minimax cn
// is one of 7 LLM connector profiles, uses Anthropic Messages
// API protocol, base URL = `https://api.minimaxi.com/anthropic`.
//
// This is a peer of `AnthropicConnector` (= NOT a thin
// wrapper). The two share `RequestHelpers.decodeAnthropicResponse`
// (= Minimax returns Anthropic-shaped content blocks) but use
// DIFFERENT request-body helpers (= `buildMinimaxRequest` here
// vs AnthropicConnector's structured `system` block helper; =
// Minimax does not honor structured `system` blocks; = the two
// wire formats are NOT byte-equivalent).
//
// Surface implemented here:
//   - `send(messages:options:)` → `LLMResponse` via URLSession
//   - `x-api-key` + `anthropic-version` headers
//   - text-only request/response (= no tool_use yet; that lands
//     when AnthropicConnector's tool_use surface is reused)
//   - streaming wired (= native SSE via the shared
//     `AnthropicStreamingWireup`; = the Minimax endpoint accepts
//     `stream: true` and emits Anthropic-shaped events; = the
//     wire format is byte-compatible; = before this commit
//     chat on Minimax-cn used the default `LLMConnector.stream()`
//     "fake streaming" path (= whole reply yielded at once;
//     = the user saw a 5-10s blank bubble then the full reply).
//
// Pre-tool guardrail: reuses `ConnectorCredentials` (= AGENTS.md
// §11.3 wenshu-side wins: thin wrapper over existing
// `ProviderKeychain`).
//
// AUDIT.md §2.6 partial (2026-10-16 boss 2026-10-16 OOB
// "包要有 LOG 能力" arc): WALogger.network logs the
// connector-level lifecycle (= auth resolution +
// send/stream start/finish + error); = the underlying
// SSEClient already logs the byte-level events; = the
// two layers combined give Console.app a full trace of
// every Minimax-cn LLM call (= the boss can see
// `WALogger.network` → `SSE attempt=...` for each chat
// turn; = matches the hermes `agent.Agent` log shape).

import Foundation
import os.log

private let connectorLogger = Logger(
    subsystem: "com.wenshu.agent", category: "model"
)

actor MinimaxConnector: LLMConnector {
    nonisolated let connectorID: String

    /// The provider whose keychain slot this connector reads from
    /// (= `Provider.by(slug: "minimax")` for the international
    /// endpoint, `Provider.by(slug: "minimax-cn")` for the china
    /// endpoint). The previous hard-coded `.minimaxCn` lookup made
    /// the connector pick up the wrong key (= "configured in
    /// Settings -> Providers" but for the wrong region) the moment
    /// the user toggled their active provider slug between
    /// `minimax` and `minimax-cn`. Mirroring `OpenAICompatible
    /// Connector(provider:)` so the same factory side that
    /// resolves the Provider shape hands the matching keychain slot
    /// to the connector instance.
    private let provider: Provider

    private let session: URLSession
    private let useCacheControl: Bool

    init(
        provider: Provider = .minimaxCn,
        session: URLSession = .shared,
        useCacheControl: Bool = true
    ) {
        self.provider = provider
        self.session = session
        self.useCacheControl = useCacheControl
        connectorID = provider.slug
        connectorLogger.info("MinimaxConnector init providerSlug=\(provider.slug, privacy: .public) useCacheControl=\(useCacheControl, privacy: .public)")
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: provider)
        connectorLogger.debug("send start model=\(options.model, privacy: .public) messages=\(messages.count)")

        guard !credentials.apiKey.isEmpty else {
            connectorLogger.error("send missing API key")
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/v1/messages") else {
            connectorLogger.error("send invalid baseURL=\(credentials.baseURL, privacy: .public)")
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching (= `PromptCaching.applyCacheControl`).
        // Per-message cache_control marker on the last 3 non-system messages
        // (= the Anthropic-compatible 4th-breakpoint on system is NOT wired
        // for Minimax; Minimax does not honor structured `system` blocks).
        let cachedMessages = useCacheControl
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: options.systemPrompt ?? "",
                ttl: "5m"
            )
            : messages

        // Build Anthropic-compatible request body via shared helper
        // (= TICKET-HERMES-GAP-002). Note: this is the **Minimax-compatible**
        // helper (= plain-string `system`, joined-string `content`), not the
        // Anthropic-native helper (= structured `system`, block-array
        // `content`). The two wire formats are NOT byte-equivalent.
        let body = try RequestHelpers.buildMinimaxRequest(
            model: options.model,
            messages: cachedMessages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            // Wire the tool schemas (= required for the agent
            // driver: the LLM only emits `tool_use` blocks when
            // the request body advertises them; = without this
            // field, Minimax-cn LLM defaults to plain text reply
            // even when the system prompt demands tools).
            tools: options.tools
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body

        // Send
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            connectorLogger.error("send no HTTPURLResponse")
            throw LLMConnectorError.transport(provider: connectorID, statusCode: 0, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            connectorLogger.error("send HTTP \(http.statusCode) body=\(bodyPreview, privacy: .private)")
            throw LLMConnectorError.transport(provider: connectorID, statusCode: http.statusCode, body: bodyPreview)
        }

        // Decode Anthropic-style response (= text only for sub-step 7).
        // Shared with AnthropicConnector via `decodeAnthropicResponse`.
        let decoded = try RequestHelpers.decodeAnthropicResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
        connectorLogger.debug("send finish HTTP \(http.statusCode) tokens=in:\(decoded.usage.inputTokens)/out:\(decoded.usage.outputTokens)")
        return decoded
    }

    // MARK: - Native streaming (P0-AGENT-STREAMING, boss 2026-10-16)
    //
    // The default `LLMConnector.stream()` extension (= the "fake
    // streaming" path; = calls send() then yields blocks) was the
    // user-visible reason Minimax-cn chat showed a 5-10 second
    // blank bubble followed by the full reply. = the user thought
    // the model was broken.
    //
    // Minimax-cn accepts `stream: true` on its Anthropic-compatible
    // `/v1/messages` endpoint and emits byte-compatible Anthropic
    // SSE events; = we can reuse the same
    // `AnthropicStreamingWireupFactory.streamingStream(...)` +
    // `AnthropicChunkToLLMBlockConverter.convert(...)` pair that
    // `AnthropicConnector` uses. The only difference vs the
    // Anthropic path is the credentials resolution (= .minimaxCn
    // vs .anthropic).
    //
    // `nonisolated` (T9 protocol conformance): `useCacheControl` is
    // a `let` (= Sendable + immutable = safe to read from any actor
    // context = matches the AnthropicConnector pattern).
    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        let credentials = ConnectorCredentials.resolve(for: provider)
        connectorLogger.debug("stream start model=\(options.model, privacy: .public) messages=\(messages.count)")

        // Empty key -> emit synthetic error block (= no silent
        // stream end; = matches AnthropicConnector behavior).
        if credentials.apiKey.isEmpty {
            connectorLogger.error("stream missing API key")
            return AnthropicChunkToLLMBlockConverter.errorStream(
                "[stream error] missing API key for \(provider.slug)"
            )
        }

        // Apply prompt caching (same path as send(); = per-message
        // cache_control marker on the last 3 non-system messages;
        // = Minimax does not honor structured `system` blocks, so
        // we skip the system-side cache marker that
        // AnthropicConnector uses).
        let cachedMessages = useCacheControl
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: options.systemPrompt ?? "",
                ttl: "5m"
            )
            : messages

        let chunkStream = AnthropicStreamingWireupFactory.streamingStream(
            credentials: credentials,
            model: options.model,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            messages: cachedMessages,
            tools: options.tools
        )
        // T11b-WIRE-ANTHROPIC-STATEFUL (parity with AnthropicConnector):
        // use the stateful converter variant (= accumulates
        // tool_use blocks across 3 SSE event types into a single
        // .toolUse LLMBlock at block close). = the agent's ReAct
        // loop sees a coherent .toolUse block (= no half-built
        // tool calls in the chat).
        let accumulator = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        return AnthropicChunkToLLMBlockConverter.convert(
            stream: chunkStream,
            accumulator: accumulator
        )
    }
}
