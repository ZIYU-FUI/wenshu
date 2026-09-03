//
//  MinimaxConnector.swift · Wenshu · v0.35 ticket 001 sub-step 7
//
//  Minimax cn connector (= thin Anthropic-compatible wire format wrapper).
//
//  Per hermes-core-translation spec §3.2 + AGENTS.md §11.2:
//  Minimax cn is one of 7 LLM connector profiles, uses Anthropic Messages
//  API protocol, base URL = https://api.minimaxi.com/anthropic.
//
//  In sub-step 7 (= TB-B tracer-bullet's first connector), we implement
//  the MINIMUM surface that lets the rest of the agent stack run end-to-end:
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

        guard let url = URL(string: "\\(credentials.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching (= ticket 002 PromptCaching.applyCacheControl)
        // System prompt becomes a separate Anthropic top-level field; markers
        // placed on the last 3 non-system messages. Both are derived from the
        // byte-stable invariant per AGENTS.md §11.3.
        let cachedMessages = useCacheControl
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: options.systemPrompt ?? "",
                ttl: "5m"
            )
            : messages

        // Build Anthropic-compatible request body
        let body: [String: Any] = [
            "model": options.model,
            "max_tokens": options.maxTokens,
            "system": options.systemPrompt ?? "",
            "messages": cachedMessages.map { msg -> [String: Any] in
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.blocks.compactMap { block -> String? in
                        switch block {
                        case .text(let s): return s
                        case .thinking(let t, _): return t
                        default: return nil
                        }
                    }.joined(separator: "\\n")
                ]
                // Attach cache_control marker if present (= PromptCaching output)
                if let marker = msg.cacheControl {
                    dict["cache_control"] = marker
                }
                return dict
            }
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Send
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMConnectorError.transport(provider: connectorID, statusCode: 0, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
            throw LLMConnectorError.transport(provider: connectorID, statusCode: http.statusCode, body: bodyPreview)
        }

        // Decode Anthropic-style response (= text only for sub-step 7)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw LLMConnectorError.decode(provider: connectorID, underlying: "missing content array")
        }

        var blocks: [LLMBlock] = []
        for block in content {
            guard let type = block["type"] as? String else { continue }
            switch type {
            case "text":
                if let text = block["text"] as? String {
                    blocks.append(.text(text))
                }
            case "thinking":
                if let thinking = block["thinking"] as? String {
                    let signature = block["signature"] as? String
                    blocks.append(.thinking(text: thinking, signature: signature))
                }
            default:
                break
            }
        }

        let model = json["model"] as? String ?? options.model
        let id = json["id"] as? String ?? UUID().uuidString
        let stopReasonRaw = json["stop_reason"] as? String ?? "unknown"
        let stopReason = LLMResponse.StopReason(rawValue: stopReasonRaw) ?? .unknown

        var usage = LLMUsage(inputTokens: 0, outputTokens: 0)
        if let usageDict = json["usage"] as? [String: Any] {
            usage = LLMUsage(
                inputTokens: usageDict["input_tokens"] as? Int ?? 0,
                outputTokens: usageDict["output_tokens"] as? Int ?? 0
            )
        }

        return LLMResponse(
            id: id,
            model: model,
            blocks: blocks,
            stopReason: stopReason,
            usage: usage
        )
    }
}