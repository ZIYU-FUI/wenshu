// AnthropicConnector.swift
//
// Anthropic native connector. P0 connector profile, full wire format
// support per AGENTS.md §11.2.
//
// Anthropic Messages API native features (vs `MinimaxConnector` which
// is the Anthropic-compatible thin wrapper for non-Anthropic
// providers):
//   - Cache control markers (4 breakpoints, see `PromptCaching.swift`)
//   - Thinking blocks (extended thinking + signatures)
//   - Tool use round-trip (= `tool_use` + `tool_result` blocks)
//   - SSE streaming (= lives in `AnthropicStreaming.swift`)
//
// The request-body + response-decoding marshaling lives in
// `Connector/RequestHelpers.swift` so each connector is a thin
// wrapper over the shared helpers. Connector-specific concerns
// remaining here: credential resolution, URL building, auth headers,
// transport send, and HTTP-status error path.

import Foundation

actor AnthropicConnector: LLMConnector {
    nonisolated let connectorID = "anthropic"

    private let session: URLSession
    private let useCacheControl: Bool

    init(session: URLSession = .shared, useCacheControl: Bool = true) {
        self.session = session
        self.useCacheControl = useCacheControl
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: .anthropic)

        guard !credentials.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching (= `PromptCaching.applyCacheControl`).
        // System prompt gets a structured cache_control marker in the request
        // body (= built by `RequestHelpers.buildAnthropicRequest`); the last
        // 3 non-system messages get per-message + per-text-block markers.
        let cachedMessages = useCacheControl
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: options.systemPrompt ?? "",
                ttl: "5m"
            )
            : messages

        // Build request body via shared helper.
        // pass reasoningEffort from user setting.
        let body = try RequestHelpers.buildAnthropicRequest(
            model: options.model,
            messages: cachedMessages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            reasoningEffort: options.reasoningEffort,
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
            throw LLMConnectorError.transport(provider: connectorID, statusCode: 0, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: http.statusCode, body: bodyPreview)
        }

        // Decode via shared helper.
        return try RequestHelpers.decodeAnthropicResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
    }

    /// T9-ANTHROPIC-STREAMING-WIRE (2026-09-18): override the default
    /// `stream()` (= which would call `send(...)` and emit the whole
    /// response as one chunk) with a real SSE pipeline that yields
    /// Anthropic chunks converted to cross-connector LLMBlock events.
    ///
    /// Pipeline:
    ///   1. AnthropicStreamingWireupFactory.streamingStream(...) opens
    ///      the SSE connection via EventSource (= mattt/EventSource 1.5.1)
    ///      and yields AnthropicStreamingChunk events.
    ///   2. AnthropicChunkToLLMBlockConverter.convert(stream:) maps
    ///      each chunk to an LLMBlock (= textDelta -> .text,
    ///      thinkingDelta -> .thinking, etc).
    ///   3. The resulting AsyncStream<LLMBlock> is returned to
    ///      ConversationLoop's streamCallback path (= ChatView's
    ///      ChatPartView sees live per-token text + reasoning).
    ///
    /// `nonisolated` (= T9 protocol conformance isolation fix): the
    /// stream(...) override reads `self.useCacheControl` (= actor-
    /// isolated) inside the function body. Marking the method
    /// `nonisolated` would normally require a copy of self state,
    /// but `useCacheControl` is a `let` (= Sendable + immutable =
    /// safe to read from any actor context). The default
    /// implementation in LLMConnector extension is also nonisolated,
    /// so this override matches.
    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        let credentials = ConnectorCredentials.resolve(for: .anthropic)

        // Empty key -> emit synthetic error block (= no silent stream end).
        if credentials.apiKey.isEmpty {
            return AnthropicChunkToLLMBlockConverter.errorStream(
                "[stream error] missing API key for anthropic"
            )
        }

        // Apply prompt caching (= same path as send()).
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
        // T11b-WIRE-ANTHROPIC-STATEFUL (2026-09-18): use the stateful
        // converter variant (= accumulates tool_use blocks across 3 SSE
        // event types into a single .toolUse LLMBlock at block close).
        // The stateless variant (= T9) silently dropped input_delta chunks;
        // = this 1-line swap unblocks live tool cards in ChatPartView.
        let accumulator = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        return AnthropicChunkToLLMBlockConverter.convert(
            stream: chunkStream,
            accumulator: accumulator
        )
    }
}
