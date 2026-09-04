//
//  OpenAIConnector.swift · Wenshu · v0.35 ticket 005
//                                  TICKET-HERMES-GAP-002 (request marshaling extracted)
//
//  OpenAI native + OpenAI-compatible connector (= ticket 005, P0).
//
//  Two connector profiles in one file (= reuse the same wire format):
//    - OpenAIConnector: OpenAI native (gpt-5, gpt-4.1, etc.) via api.openai.com
//    - OpenAICompatibleConnector: thin wrappers over minimax cn + DeepSeek
//      + Ollama + OpenRouter (= all use the OpenAI chat completions protocol)
//
//  Per TICKET-HERMES-GAP-002 (= hermes-port gap audit §2.1 #8), the
//  request-body + response-decoding marshaling has been extracted to
//  `Connector/RequestHelpers.swift`. Both connectors now share
//  `RequestHelpers.buildOpenAIRequest` + `RequestHelpers.decodeOpenAIResponse`.
//  Connector-specific concerns remaining here: credential resolution, URL
//  building, auth headers (= Bearer for OpenAI native, optional Bearer
//  for OpenAI-compatible to support Ollama's no-auth local), transport
//  send, and HTTP-status error path.
//
//  v0.35 ticket 005 (= 1 commit covering both connectors).
//

import Foundation

// MARK: - OpenAI native

public actor OpenAIConnector: LLMConnector {
    public nonisolated let connectorID = "openai-codex"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: .openaiCodex)

        guard !credentials.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/chat/completions") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Build OpenAI chat completions request body via shared helper.
        let body = try RequestHelpers.buildOpenAIRequest(
            model: options.model,
            messages: messages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        // Decode via shared helper (= TICKET-HERMES-GAP-002).
        return try RequestHelpers.decodeOpenAIResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
    }
}

// MARK: - OpenAI-compatible (minimax cn / DeepSeek / Ollama / OpenRouter)

public actor OpenAICompatibleConnector: LLMConnector {
    public nonisolated let connectorID: String  // = provider.slug (set at init)

    private let session: URLSession
    private let provider: Provider

    public init(provider: Provider, session: URLSession = .shared) {
        self.provider = provider
        self.session = session
        self.connectorID = provider.slug
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: provider)

        guard credentials.apiKey.isEmpty || provider.slug == "ollama" else {
            // For non-Ollama providers, apiKey is required
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        guard let url = URL(string: "\(credentials.baseURL)/chat/completions") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Build OpenAI-compatible request body via shared helper.
        let body = try RequestHelpers.buildOpenAIRequest(
            model: options.model,
            messages: messages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !credentials.apiKey.isEmpty {
            request.setValue("Bearer \(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        // Decode via shared helper (= TICKET-HERMES-GAP-002).
        return try RequestHelpers.decodeOpenAIResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
    }
}