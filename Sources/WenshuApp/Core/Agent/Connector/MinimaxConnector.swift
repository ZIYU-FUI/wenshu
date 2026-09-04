//
//  MinimaxConnector.swift · Wenshu · v0.35 ticket 001 sub-step 7
//                                      TICKET-HERMES-GAP-002 (request marshaling extracted)
//
//  Minimax cn connector (= thin Anthropic-compatible wire format wrapper).
//
//  Per hermes-core-translation spec §3.2 + AGENTS.md §11.2:
//  Minimax cn is one of 7 LLM connector profiles, uses Anthropic Messages
//  API protocol, base URL = https://api.minimaxi.com/anthropic.
//
//  In sub-step 7 (= TB-B tracer-bullet's first connector), we implement
//  the MINIMUM surface that lets the rest of the agent stack run end-to-end:
//:
//    - send(messages:options:) -> LLMResponse via URLSession
//    - x-api-key + anthropic-version headers
//    - text-only request/response (= no tool_use yet, lands in ticket 004)
//    - streaming not yet wired (= SSEClient.swift path continues in ticket 004)
//
//  Ticket 004 will generalize this to a full AnthropicConnector (= cache
//  markers, thinking blocks, tool_use round-trip, streaming). For sub-step 7
//  the goal is end-to-end TB-B verification: wenshu can talk to minimax cn
//  via the LLMConnector protocol.
//
//  Pre-tool guardrail: reuses ConnectorCredentials (= AGENTS.md §11.3
//  wenshu-side wins: thin wrapper over existing ProviderKeychain).
//
//  Per TICKET-HERMES-GAP-002 (= hermes-port gap audit §2.1 #8), the
//  request-body marshaling is in `Connector/RequestHelpers.swift`
//  (= `buildMinimaxRequest`). The response decoder is shared with
//  `AnthropicConnector` (= `decodeAnthropicResponse`) since Minimax
//  returns Anthropic-shaped content blocks.
//
//  v0.35 sub-step 7 of 8 for ticket 001.
//

import Foundation

public actor MinimaxConnector: LLMConnector {
    public nonisolated let connectorID = "minimax-cn"

    private let session: URLSession
    private let useCacheControl: Bool

    public init(session: URLSession = .shared, useCacheControl: Bool = true) {
        self.session = session
        self.useCacheControl = useCacheControl
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: .minimaxCn)

        guard !credentials.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching (= ticket 002 PromptCaching.applyCacheControl).
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

        // Decode Anthropic-style response (= text only for sub-step 7).
        // Shared with AnthropicConnector via `decodeAnthropicResponse`.
        return try RequestHelpers.decodeAnthropicResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
    }
}