//
//  RequestHelpers.swift · Wenshu · TICKET-HERMES-GAP-002
//
//  Extracted request/response marshaling for the 5 LLM connectors
//  (= AnthropicConnector, OpenAIConnector, OpenAICompatibleConnector,
//  GeminiNativeConnector, MinimaxConnector).
//
//  Ported from hermes-agent `agent/chat_completion_helpers.py` (3,103 LOC).
//  Per the parallel gap audit at `.scratch/2026-09-04-hermes-port-gap-audit.md`
//  §2.1 #8, every connector previously reimplemented dict-to-URLRequest
//  serialization inline (= ~150 LOC each × 5 = ~750 LOC of pure
//  duplication). This file lifts the per-provider wire-format marshaling
//  into one shared layer so each connector becomes a thin wrapper.
//
//  Per AGENTS.md §11.3 wenshu-side wins pattern: 1:1 logic mapping with
//  Swift-idiom names, no hermes runtime state assumptions, no behavior
//  change at the wire level (= golden parity with pre-refactor connector
//  tests still passes).
//
//  Design invariants (= byte-identical to pre-refactor):
//    - Anthropic native (`buildAnthropicRequest`):
//        system = structured dict with cache_control marker
//        content = ARRAY of blocks (= text / thinking / tool_use / tool_result)
//        tool_use.input encoded as `Data` (= preserved quirk)
//    - Minimax-compatible (`buildMinimaxRequest`):
//        system = plain string (= NOT structured, no cache_control)
//        content = joined string of text+thinking only (= tool_use/toolResult dropped)
//        message-level cache_control marker only (= no per-block marker)
//    - OpenAI chat completions (`buildOpenAIRequest`):
//        system prepended as {role:"system", content:"..."}
//        messages = [{role, content: <joined text+thinking>}, ...]
//    - Gemini native (`buildGeminiRequest`):
//        systemInstruction = {parts:[{text:"..."}]}
//        contents[] = {role: "user"|"model", parts: [{text:"..."}]}
//        generationConfig.maxOutputTokens if maxTokens > 0
//
//  Refactor lands in TICKET-HERMES-GAP-002; per ticket scope, only this
//  file + the 5 connectors change. AnthropicStreaming*.swift (SSE wire-up)
//  is out of scope (= different shape: stream:true + SSE chunks).
//
//

import Foundation

/// Shared request/response marshaling for the 5 wenshu LLM connectors.
///
/// All helpers are pure functions (= no actor state, no URLSession, no
/// credential resolution). Each connector still owns the URL building,
/// auth header, transport send, and HTTP-status error path. Helpers
/// focus only on the **JSON body shape** (= the wire format).
///
/// Helpers preserve the pre-existing wire-format quirks (= Anthropic
/// tool_use.input encoded as Data, Minimax-compatible drops
/// tool_use/tool_result blocks, OpenAI flattens blocks to joined
/// string). Any future deviation requires its own connector-specific
/// helper (= no silent unification across providers).
public enum RequestHelpers {

    // MARK: - Anthropic native (= ticket 004)

    /// Build the request body for the Anthropic Messages API native wire
    /// format. Matches the pre-refactor `AnthropicConnector.send`
    /// behavior byte-for-byte.
    ///
    /// - Parameters:
    ///   - model: model identifier
    ///   - messages: cross-connector message list (= cache_control markers
    ///     applied upstream via `PromptCaching.applyCacheControl`).
    ///   - maxTokens: max output tokens (= top-level `max_tokens`)
    ///   - systemPrompt: optional system prompt (= top-level `system`
    ///     with structured dict shape + cache_control marker)
    /// - Returns: JSON-encoded request body Data
    public static func buildAnthropicRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?
    ) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens
        ]
        if let sys = systemPrompt, !sys.isEmpty {
            body["system"] = [
                "type": "text",
                "text": sys,
                "cache_control": ["type": "ephemeral"]
            ]
        }
        body["messages"] = messages.map { msg -> [String: Any] in
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
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Decode an Anthropic-format JSON response into an `LLMResponse`.
    /// Handles text / thinking / tool_use content blocks (= the same
    /// 3 variants the pre-refactor `AnthropicConnector` decoded).
    /// Shared with `MinimaxConnector` (= Minimax's HTTP API returns the
    /// same Anthropic-compatible wire shape on the response side).
    public static func decodeAnthropicResponse(
        data: Data,
        model: String,
        providerID: String
    ) throws -> LLMResponse {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw LLMConnectorError.decode(provider: providerID, underlying: "missing content array")
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

        let resolvedModel = json["model"] as? String ?? model
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
            model: resolvedModel,
            blocks: blocks,
            stopReason: stopReason,
            usage: usage
        )
    }

    // MARK: - Minimax-compatible (= thin Anthropic wrapper for minimax cn)

    /// Build the request body for the Minimax-compatible Anthropic wire
    /// format (= ticket 001 sub-step 7). Differs from native Anthropic
    /// in 2 places (preserved for parity):
    ///   1. `system` is a plain string (= NOT a structured dict with
    ///      cache_control). Minimax does not honor the Anthropic
    ///      `system` block shape.
    ///   2. `content` is a joined `"\n"`-separated string (= NOT a
    ///      block array). tool_use / tool_result blocks are dropped
    ///      (= MinimaxConnector sub-step 7 is text-only).
    /// Per-message `cache_control` markers are preserved (= the 4
    /// breakpoints from `PromptCaching.applyCacheControl`).
    public static func buildMinimaxRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?
    ) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt ?? "",
            "messages": messages.map { msg -> [String: Any] in
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.blocks.compactMap { block -> String? in
                        switch block {
                        case .text(let s): return s
                        case .thinking(let t, _): return t
                        default: return nil
                        }
                    }.joined(separator: "\n")
                ]
                if let marker = msg.cacheControl {
                    dict["cache_control"] = marker
                }
                return dict
            }
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    // MARK: - OpenAI chat completions (= ticket 005)

    /// Build the request body for the OpenAI chat completions wire
    /// format. Matches `OpenAIConnector` + `OpenAICompatibleConnector`
    /// byte-for-byte.
    ///
    /// - Parameters:
    ///   - model: model identifier
    ///   - messages: cross-connector message list
    ///   - maxTokens: max output tokens
    ///   - systemPrompt: optional system prompt (= prepended as a
    ///     `role:"system"` message; empty / nil = no system message)
    /// - Returns: JSON-encoded request body Data
    public static func buildOpenAIRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?
    ) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": buildOpenAIMessages(
                systemPrompt: systemPrompt,
                userMessages: messages
            )
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Build the OpenAI messages array (= system prepended + user /
    /// assistant / tool messages flattened to single content strings).
    /// Extracted from pre-refactor `OpenAIConnector.swift` `buildOpenAIMessages`.
    private static func buildOpenAIMessages(
        systemPrompt: String?,
        userMessages: [LLMMessage]
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        if let sys = systemPrompt, !sys.isEmpty {
            messages.append(["role": "system", "content": sys])
        }
        for msg in userMessages {
            // Flatten content blocks to single string (= OpenAI protocol).
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

    /// Decode an OpenAI-format JSON response into an `LLMResponse`.
    /// Shared between `OpenAIConnector` + `OpenAICompatibleConnector`.
    /// Stop reason mapping: `"length"` -> `.maxTokens`, else `.endTurn`.
    public static func decodeOpenAIResponse(
        data: Data,
        model: String,
        providerID: String
    ) throws -> LLMResponse {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            throw LLMConnectorError.decode(provider: providerID, underlying: "missing choices[0].message")
        }

        let content = message["content"] as? String ?? ""
        let resolvedModel = json["model"] as? String ?? model
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
            model: resolvedModel,
            blocks: content.isEmpty ? [] : [.text(content)],
            stopReason: stopReason,
            usage: usage
        )
    }

    // MARK: - Gemini native (= ticket 007)

    /// Build the request body for the Google GenAI `generateContent`
    /// wire format. Matches `GeminiNativeConnector` byte-for-byte.
    ///
    /// - Parameters:
    ///   - model: model identifier
    ///   - messages: cross-connector message list (= user / assistant /
    ///     tool). Only text blocks are forwarded (= Gemini native has
    ///     no tool_use in the 5-file wenshu port).
    ///   - maxTokens: max output tokens (= `generationConfig.maxOutputTokens`,
    ///     only set if `maxTokens > 0`)
    ///   - systemPrompt: optional system prompt (= top-level
    ///     `systemInstruction` field; empty / nil = no systemInstruction)
    /// - Returns: JSON-encoded request body Data
    public static func buildGeminiRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?
    ) throws -> Data {
        var contents: [[String: Any]] = []
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
        if let sys = systemPrompt, !sys.isEmpty {
            body["systemInstruction"] = ["parts": [["text": sys]]]
        }
        if maxTokens > 0 {
            body["generationConfig"] = ["maxOutputTokens": maxTokens]
        }
        // `model` is wired into the URL by the connector, NOT the body
        // (= Gemini `generateContent` endpoint takes model in path).
        _ = model  // reserved for future body-level model override
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Decode a Gemini-format JSON response into an `LLMResponse`.
    /// Maps `candidates[0].content.parts[].text` to a single text block.
    public static func decodeGeminiResponse(
        data: Data,
        model: String,
        providerID: String
    ) throws -> LLMResponse {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw LLMConnectorError.decode(provider: providerID, underlying: "missing candidates[0].content.parts")
        }

        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        let resolvedModel = json["modelVersion"] as? String ?? model
        let id = "gemini-\(UUID().uuidString.prefix(12))"

        var usage = LLMUsage(inputTokens: 0, outputTokens: 0)
        if let metadata = json["usageMetadata"] as? [String: Any] {
            usage = LLMUsage(
                inputTokens: metadata["promptTokenCount"] as? Int ?? 0,
                outputTokens: metadata["candidatesTokenCount"] as? Int ?? 0
            )
        }

        return LLMResponse(
            id: id,
            model: resolvedModel,
            blocks: text.isEmpty ? [] : [.text(text)],
            stopReason: .endTurn,
            usage: usage
        )
    }
}