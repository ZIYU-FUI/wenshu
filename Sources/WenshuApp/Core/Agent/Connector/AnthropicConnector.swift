//
//  AnthropicConnector.swift · Wenshu · v0.35 ticket 004 sub-step 1
//
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

        guard let url = URL(string: "\\(credentials.baseURL)/v1/messages") else {
            throw LLMConnectorError.unsupportedProvider(slug: connectorID)
        }

        // Apply prompt caching
        let cachedMessages = useCacheControl
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: options.systemPrompt ?? "",
                ttl: "5m"
            )
            : messages

        // Build Anthropic-native request body
        // (= differs from MinimaxConnector by NOT joining text blocks into single string;
        //    Anthropic expects structured content blocks array)
        let body: [String: Any] = [
            "model": options.model,
            "max_tokens": options.maxTokens,
            "system": [
                "type": "text",
                "text": options.systemPrompt ?? "",
                "cache_control": ["type": "ephemeral"]
            ],
            "messages": cachedMessages.map { msg -> [String: Any] in
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.blocks.map { block -> [String: Any] in
                        switch block {
                        case .text(let s):
                            var d: [String: Any] = ["type": "text", "text": s]
                            if let marker = msg.cacheControl {
                                d["cache_control"] = marker
                            }
                            return d
                        case .thinking(let t, let sig):
                            var d: [String: Any] = ["type": "thinking", "thinking": t]
                            if let sig { d["signature"] = sig }
                            return d
                        case .toolUse(let id, let name, let input):
                            return [
                                "type": "tool_use",
                                "id": id,
                                "name": name,
                                "input": input.data(using: .utf8) ?? Data()
                            ]
                        case .toolResult(let toolUseID, let output):
                            return [
                                "type": "tool_result",
                                "tool_use_id": toolUseID,
                                "content": output
                            ]
                        }
                    }
                ]
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

        // Decode Anthropic-native response (= structured content blocks)
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
            case "tool_use":
                if let id = block["id"] as? String,
                   let name = block["name"] as? String,
                   let input = block["input"] {
                    let inputString: String
                    if let inputDict = input as? [String: Any],
                       let data = try? JSONSerialization.data(withJSONObject: inputDict),
                       let s = String(data: data, encoding: .utf8) {
                        inputString = s
                    } else if let s = input as? String {
                        inputString = s
                    } else {
                        inputString = "{}"
                    }
                    blocks.append(.toolUse(id: id, name: name, input: inputString))
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