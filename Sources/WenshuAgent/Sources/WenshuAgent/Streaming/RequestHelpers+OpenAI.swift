//
//  RequestHelpers+OpenAI.swift
//
//  The OpenAI chat-completions wire: the request builder, the messages
//  builder only it calls, and the response decoder.
//
//  Why: the OpenAI wire is a cluster of its own (= the Anthropic, the
//  MiniMax and the Gemini wires each own theirs), and the shared
//  helpers file was over the file-size cap.
//
import Foundation

public extension RequestHelpers {
    // MARK: - OpenAI chat completions

    /// … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / - Returns: JSON-encoded request body Data
    static func buildOpenAIRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?,
        // / reasoning effort from user setting.
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / nil = omit param (= connector default).
        reasoningEffort: String? = nil,
        // / Tool schemas to advertise to the model. Empty (= default)
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / function:{name, description, parameters}}` objects.
        tools: [ToolRegistrySchema] = [],
        // / The route this request goes to. The cache marker rides on
        // / the message envelope, and only some routes carry it.
        providerSlug: String? = nil
    ) throws -> Data {
        // The route and the model decide whether this wire can carry a
        // cached prefix at all. A provider whose wire has no cache field
        // gets no marker, so it never pretends to cache.
        let ttl = PromptCacheSettings.ttl.effectiveTTL
        let canMark = PromptCachePolicy.carriesEnvelopeMarker(
            providerSlug: providerSlug ?? "",
            model: model
        )
        // The same stable prefix rule the Anthropic and MiniMax paths
        // use: the system prompt plus the last three messages.
        let markedMessages = canMark
            ? PromptCaching.applyCacheControl(
                messages: messages,
                systemPrompt: systemPrompt ?? "",
                ttl: ttl
            )
            : messages
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": buildOpenAIMessages(
                systemPrompt: systemPrompt,
                userMessages: markedMessages,
                providerSlug: providerSlug,
                model: model,
                ttl: ttl
            ),
        ]
        // wire reasoningEffort → OpenAI reasoning_effort param.
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // "xhigh" maps to "high" (= OpenAI's max supported value).
        if let effort = reasoningEffort, !effort.isEmpty {
            let mapped: String
            switch effort {
            case "xhigh", "max": mapped = "high"
            case "low", "medium", "high": mapped = effort
            default: mapped = "medium"
            }
            body["reasoning_effort"] = mapped
        }
        if !tools.isEmpty {
            body["tools"] = tools.map { schema -> [String: Any] in
                var props: [String: Any] = [:]
                for (key, prop) in schema.inputSchema {
                    props[key] = prop.toJSON()
                }
                var function: [String: Any] = [
                    "name": schema.name,
                    "description": schema.description,
                ]
                if !props.isEmpty || !schema.required.isEmpty {
                    function["parameters"] = [
                        "type": "object",
                        "properties": props,
                        "required": schema.required,
                    ]
                }
                return [
                    "type": "function",
                    "function": function,
                ]
            }
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Build the OpenAI messages array (= system prepended + user /
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// Extracted from pre-refactor `OpenAIConnector.swift` `buildOpenAIMessages`.
    ///
    /// The cache marker rides on the message envelope (= the same key the
    /// Anthropic and MiniMax builders write on their message dictionary),
    /// because the OpenAI-compatible wire carries it there.
    private static func buildOpenAIMessages(
        systemPrompt: String?,
        userMessages: [LLMMessage],
        providerSlug: String?,
        model: String,
        ttl: String
    ) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        // The route and the model decide whether this wire can carry a
        // cached prefix at all. A provider whose wire has no cache field
        // gets no marker, so it never pretends to cache.
        let marker = PromptCachePolicy.marker(
            providerSlug: providerSlug ?? "",
            model: model,
            ttl: ttl
        )
        if let sys = systemPrompt, !sys.isEmpty {
            var system: [String: Any] = ["role": "system", "content": sys]
            if let marker {
                system["cache_control"] = marker
            }
            messages.append(system)
        }
        for msg in userMessages {
            // Flatten content blocks to single string (= OpenAI protocol).
            let content = msg.blocks.compactMap { block -> String? in
                switch block {
                case let .text(s): return s
                case let .thinking(t, _): return t
                default: return nil
                }
            }.joined(separator: "\n")
            var dict: [String: Any] = ["role": msg.role.rawValue, "content": content]
            // The per-message marker the cache builder placed on this
            // message (= the last three of the conversation).
            if let own = msg.cacheControl {
                dict["cache_control"] = own
            }
            messages.append(dict)
        }
        return messages
    }

    /// / Decode an OpenAI-format JSON response into an `LLMResponse`.
    /// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    /// / Stop reason mapping: `"length"` -> `.maxTokens`, else `.endTurn`.
    static func decodeOpenAIResponse(
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
            usage = Self.usage(
                from: usageDict,
                inputKey: "prompt_tokens",
                outputKey: "completion_tokens"
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
}
