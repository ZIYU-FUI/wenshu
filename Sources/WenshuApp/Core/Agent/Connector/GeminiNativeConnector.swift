//
//  GeminiNativeConnector.swift · Wenshu · v0.35 ticket 007
//
//  Gemini native connector (= P1, ticket 007).
//  Google GenAI protocol (= generateContent endpoint).
//  apiMode = 'google_genai' (per Provider enum).
//
//  v0.35 ticket 007 (= 1 commit covering Gemini native).
//
//  Note: DeepSeek + Ollama are already covered by OpenAICompatibleConnector
//  (= ticket 005, since they use the OpenAI chat completions protocol).
//  This file adds only the Google-specific wire format.
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
        guard let url = URL(string: "\\(credentials.baseURL)/models/\\(options.model):generateContent?key=\\(credentials.apiKey)") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Build Gemini request body (= contents array with parts)
        var contents: [[String: Any]] = []
        if let sys = options.systemPrompt, !sys.isEmpty {
            // Gemini uses systemInstruction field (= top-level)
            // (= system message is a separate field, not in contents)
            _ = sys  // captured separately
        }
        for msg in messages {
            let role = msg.role == .user ? "user" : "model"
            let parts: [[String: Any]] = msg.blocks.compactMap { block in
                switch block {
                case .text(let s): return ["text": s]
                default: return nil
                }
            }
            if !parts.isEmpty {
                contents.append(["role": role, "parts": parts])
            }
        }

        var body: [String: Any] = [
            "contents": contents
        ]
        if let sys = options.systemPrompt, !sys.isEmpty {
            body["systemInstruction"] = ["parts": [["text": sys]]]
        }
        if options.maxTokens > 0 {
            body["generationConfig"] = ["maxOutputTokens": options.maxTokens]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        // Decode Gemini response (= candidates[0].content.parts)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw LLMConnectorError.decode(provider: connectorID, underlying: "missing candidates[0].content.parts")
        }

        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        let model = json["modelVersion"] as? String ?? options.model
        let id = "gemini-\\(UUID().uuidString.prefix(12))"

        var usage = LLMUsage(inputTokens: 0, outputTokens: 0)
        if let metadata = json["usageMetadata"] as? [String: Any] {
            usage = LLMUsage(
                inputTokens: metadata["promptTokenCount"] as? Int ?? 0,
                outputTokens: metadata["candidatesTokenCount"] as? Int ?? 0
            )
        }

        return LLMResponse(
            id: id,
            model: model,
            blocks: text.isEmpty ? [] : [.text(text)],
            stopReason: .endTurn,
            usage: usage
        )
    }
}