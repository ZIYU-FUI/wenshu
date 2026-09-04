//
//  GeminiNativeConnector.swift · Wenshu · v0.35 ticket 007
//                                         TICKET-HERMES-GAP-002 (request marshaling extracted)
//
//  Gemini native connector (= P1, ticket 007).
//  Google GenAI protocol (= generateContent endpoint).
//  apiMode = 'google_genai' (per Provider enum).
//
//  Per TICKET-HERMES-GAP-002 (= hermes-port gap audit §2.1 #8), the
//  request-body + response-decoding marshaling has been extracted to
//  `Connector/RequestHelpers.swift` so each connector is a thin wrapper.
//  Connector-specific concerns remaining here: credential resolution,
// URL
//  building (= ?key= query param), transport send, and HTTP-status
//  error path.
//
//  Note: DeepSeek + Ollama are already covered by OpenAICompatibleConnector
//  (= ticket 005, since they use the OpenAI chat completions protocol).
//  This file adds only the Google-specific wire format.
//
//  v0.35 ticket 007 (= 1 commit covering Gemini native).
//

import Foundation

public actor GeminiNativeConnector: LLMConnector {
    public nonisolated let connectorID = "gemini"

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        let credentials = ConnectorCredentials.resolve(for: .gemini)

        guard !credentials.apiKey.isEmpty else {
            throw LLMConnectorError.missingAPIKey(provider: connectorID)
        }

        // Gemini generateContent endpoint (use ?key= query param for API key)
        guard let url = URL(string: "\(credentials.baseURL)/models/\(options.model):generateContent?key=\(credentials.apiKey)") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Build Gemini request body via shared helper (= TICKET-HERMES-GAP-002).
        let body = try RequestHelpers.buildGeminiRequest(
            model: options.model,
            messages: messages,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        // Decode via shared helper (= TICKET-HERMES-GAP-002).
        return try RequestHelpers.decodeGeminiResponse(
            data: data,
            model: options.model,
            providerID: connectorID
        )
    }
}