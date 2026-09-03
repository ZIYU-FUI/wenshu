//
//  OpenAIConnector.swift · Wenshu · v0.35 ticket 005
//
//  OpenAI native + OpenAI-compatible connector (= ticket 005, P0).
//
//  Two connector profiles in one file (= reuse the same wire format):
//    - OpenAIConnector: OpenAI native (gpt-5, gpt-4.1, etc.) via api.openai.com
//    - OpenAICompatibleConnector: thin wrappers over minimax cn + DeepSeek
//      + Ollama + OpenRouter (= all use the OpenAI chat completions protocol)
//
//  Why one file: hermes auxiliary_client.py L1-L7469 handles all
//  OpenAI-compatible providers via the same request/response shape; wenshu
//  follows the same pattern. The Provider enum's apiMode field
//  ('openai_chat') routes via this file.
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

        guard let url = URL(string: "\\(credentials.baseURL)/chat/completions") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // OpenAI chat completions API: messages array with role + content (string)
        let body: [String: Any] = [
            "model": options.model,
            "max_tokens": options.maxTokens,
            "messages": buildOpenAIMessages(
                systemPrompt: options.systemPrompt,
                userMessages: messages
            )
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \\(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        // Decode OpenAI chat completion response
        return try decodeOpenAIResponse(data: data, model: options.model, providerID: connectorID)
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

        guard let url = URL(string: "\\(credentials.baseURL)/chat/completions") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        let body: [String: Any] = [
            "model": options.model,
            "max_tokens": options.maxTokens,
            "messages": buildOpenAIMessages(
                systemPrompt: options.systemPrompt,
                userMessages: messages
            )
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !credentials.apiKey.isEmpty {
            request.setValue("Bearer \\(credentials.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: statusCode, body: bodyPreview)
        }

        return try decodeOpenAIResponse(data: data, model: options.model, providerID: connectorID)
    }
}

// MARK: - Shared OpenAI wire format helpers

/// Build the OpenAI chat completions messages array (= system message
/// prepended to user/assistant/tool messages, all with role + content).
private func buildOpenAIMessages(
    systemPrompt: String?,
    userMessages: [LLMMessage]
) -> [[String: Any]] {
    var messages: [[String: Any]] = []
    if let sys = systemPrompt, !sys.isEmpty {
        messages.append(["role": "system", "content": sys])
    }
    for msg in userMessages {
        // Flatten content blocks to single string (= OpenAI protocol)
        let content = msg.blocks.compactMap { block -> String? in
            switch block {
            case .text(let s): return s
            case .thinking(let t, _): return t
            default: return nil
            }
        }.joined(separator: "\n")
        messages.append(["role": msg.role.rawValue, "content": content])
    }
    return messages
}

/// Decode OpenAI chat completion response (= shared between OpenAIConnector
/// + OpenAICompatibleConnector).
private func decodeOpenAIResponse(data: Data, model: String, providerID: String) throws -> LLMResponse {
    guard
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = json["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any]
    else {
        throw LLMConnectorError.decode(provider: providerID, underlying: "missing choices[0].message")
    }

    let content = message["content"] as? String ?? ""
    let model2 = json["model"] as? String ?? model
    let id = json["id"] as? String ?? UUID().uuidString
    let finishReason = firstChoice["finish_reason"] as? String
    let stopReason: LLMResponse.StopReason = finishReason == "length" ? .maxTokens : .endTurn

    var usage = LLMUsage(inputTokens: 0, outputTokens: 0)
    if let usageDict = json["usage"] as? [String: Any] {
        usage = LLMUsage(
            inputTokens: usageDict["prompt_tokens"] as? Int ?? 0,
            outputTokens: usageDict["completion_tokens"] as? Int ?? 0
        )
    }

    return LLMResponse(
        id: id,
        model: model2,
        blocks: content.isEmpty ? [] : [.text(content)],
        stopReason: stopReason,
        usage: usage
    )
}