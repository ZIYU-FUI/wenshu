//
//  AnthropicConnector.swift · Wenshu · v0.35 ticket 004 sub-step 1
//                                  TICKET-HERMES-GAP-002 (request marshaling extracted)
//  Anthropic native connector (= ticket 004 sub-step 1).
//  P0 connector profile, full wire format support per AGENTS.md §11.2.
//
//  Anthropic Messages API native features (vs MinimaxConnector which is
//  the Anthropic-compatible thin wrapper):
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
        let body = try RequestHelpers.buildAnthropicRequest(
            model: options.model,
            messages: cachedMessages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt
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
}