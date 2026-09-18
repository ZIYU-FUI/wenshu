//
//  AnthropicConnector.swift · Wenshu · v0.35 ticket 004 sub-step 1
//                                  TICKET-HERMES-GAP-002 (request marshaling extracted)
//  Anthropic native connector (= ticket 004 sub-step 1).
//  P0 connector profile, full wire format support per AGENTS.md §11.2.
//
//  Anthropic Messages API native features (vs MinimaxConnector which
//  is the Anthropic-compatible thin wrapper for non-Anthropic providers):
//    - Cache control markers (4 breakpoints, see PromptCaching.swift)
//    - Thinking blocks (extended thinking + signatures)
//    - Tool use round-trip (= tool_use + tool_result blocks)
//    - SSE streaming (lands in ticket 004 sub-step 2)
//
//  Per TICKET-HERMES-GAP-002 (= hermes-port gap audit §2.1 #8), the
//  request-body + response-decoding marshaling has been extracted to
//  `Connector/RequestHelpers.swift` so each connector is a thin
//  wrapper over the shared helpers. Connector-specific concerns
//  remaining here: credential resolution, URL building, auth headers,
//  transport send, and HTTP-status error path.
//
//  v0.35 ticket 004 (= 1 of N sub-steps).
//

import Foundation

public actor AnthropicConnector: LLMConnector {
    public nonisolated let connectorID = "anthropic"

    private let session: URLSession
    private let useCacheControl: Bool

    public init(session: URLSession = .shared, useCacheControl: Bool = true) {
        self.session = session
        self.useCacheControl = useCacheControl
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: .anthropic)

        guard !credentials.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching (= ticket 002 PromptCaching.applyCacheControl).
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

        // Build request body via shared helper (= TICKET-HERMES-GAP-002).
        // v0.71 cleanup batch 4: pass reasoningEffort from user setting.
        let body = try RequestHelpers.buildAnthropicRequest(
            model: options.model,
            messages: cachedMessages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            reasoningEffort: options.reasoningEffort
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

        // Decode via shared helper (= TICKET-HERMES-GAP-002).
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
    public nonisolated func stream(
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
            messages: cachedMessages
        )
        return AnthropicChunkToLLMBlockConverter.convert(stream: chunkStream)
    }
}