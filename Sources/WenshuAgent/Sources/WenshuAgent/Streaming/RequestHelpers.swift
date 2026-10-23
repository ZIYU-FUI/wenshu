// 
// … (= 39 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation

// / Shared request/response marshaling for the 5 wenshu LLM connectors.
// … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / helper (= no silent unification across providers).
public enum RequestHelpers {

    // MARK: - Anthropic native
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / - Returns: JSON-encoded request body Data
    public static func buildAnthropicRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?,
        // / reasoning effort from user setting.
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / nil = no thinking block (= connector default).
        reasoningEffort: String? = nil,
        // / Tool schemas to advertise to the model. Empty (= default)
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / `tools` array of `{name, description, input_schema}` objects.
        tools: [ToolRegistrySchema] = []
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
        if !tools.isEmpty {
            // Anthropic native shape: tools[] of {name, description,
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Tools section).
            body["tools"] = tools.map { schema -> [String: Any] in
                var dict: [String: Any] = [
                    "name": schema.name,
                    "description": schema.description
                ]
                if !schema.inputSchema.isEmpty || !schema.required.isEmpty {
                    var props: [String: Any] = [:]
                    for (key, prop) in schema.inputSchema {
                        props[key] = prop.toJSON()
                    }
                    dict["input_schema"] = [
                        "type": "object",
                        "properties": props,
                        "required": schema.required
                    ]
                }
                return dict
            }
        }
        // wire reasoningEffort → Anthropic thinking block.
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // xhigh maps to max (= 32768 = the highest allowed budget).
        if let effort = reasoningEffort, !effort.isEmpty {
            let budgetTokens: Int
            switch effort {
            case "low": budgetTokens = 1024
            case "medium": budgetTokens = 8192
            case "high": budgetTokens = 16384
            case "xhigh", "max": budgetTokens = 32768
            default: budgetTokens = 8192
            }
            body["thinking"] = [
                "type": "enabled",
                "budget_tokens": budgetTokens
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
                        // Anthropic native `tool_use.input` is a JSON
                        // … (= 17 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // is a JSON object, so we prefer that path).
                        let parsedInput: [String: Any]
                        if let data = input.data(using: .utf8),
                           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            parsedInput = object
                        } else {
                            parsedInput = ["_raw": input]
                        }
                        return [
                            "type": "tool_use",
                            "id": id,
                            "name": name,
                            "input": parsedInput
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

    // / Decode an Anthropic-format JSON response into an `LLMResponse`.
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / same Anthropic-compatible wire shape on the response side).
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
            usage = Self.usage(
                from: usageDict,
                inputKey: "input_tokens",
                outputKey: "output_tokens"
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
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / breakpoints from `PromptCaching.applyCacheControl`).
    public static func buildMinimaxRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?,
        // / Tool schemas (= wenshu 1:1 ports the Anthropic Messages API
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / (= matches the prior tool-less behavior).
        tools: [ToolRegistrySchema] = []
    ) throws -> Data {
        // Anthropic-compatible wire shape (= minimax-cn accepts the
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the round-trip context.
        let messagesPayload: [[String: Any]] = messages.map { msg -> [String: Any] in
            // Per-role content shaping.
            switch msg.role {
            case .user, .assistant:
                // Emit the full block array (= text + thinking +
                // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // for user messages). Anthropic-compatible.
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.blocks.compactMap { block -> [String: Any]? in
                        switch block {
                        case .text(let s):
                            return ["type": "text", "text": s]
                        case .thinking(let t, _):
                            return ["type": "thinking", "thinking": t]
                        case .toolUse(let id, let name, let input):
                            // Parse the input JSON string into a dict so
                            // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                            // structured object (= not a string).
                            let parsedInput: Any
                            if let data = input.data(using: .utf8),
                               let parsed = try? JSONSerialization.jsonObject(with: data) {
                                parsedInput = parsed
                            } else {
                                parsedInput = input
                            }
                            return [
                                "type": "tool_use",
                                "id": id,
                                "name": name,
                                "input": parsedInput
                            ]
                        case .toolResult:
                            return nil  // tool_result belongs in user-role, not assistant.
                        }
                    }
                ]
                if let marker = msg.cacheControl {
                    dict["cache_control"] = marker
                }
                return dict
            case .tool:
                // Anthropic tool-role (= the convention is a `user`
                // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // Anthropic Messages API shape).
                let resultBlocks: [[String: Any]] = msg.blocks.compactMap { block -> [String: Any]? in
                    switch block {
                    case .toolResult(let toolUseID, let output):
                        return [
                            "type": "tool_result",
                            "tool_use_id": toolUseID,
                            "content": output
                        ]
                    default:
                        return nil
                    }
                }
                var dict: [String: Any] = [
                    "role": "user",
                    "content": resultBlocks
                ]
                if let marker = msg.cacheControl {
                    dict["cache_control"] = marker
                }
                return dict
            }
        }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt ?? "",
            "messages": messagesPayload
        ]
        if !tools.isEmpty {
            // Anthropic-compatible wire shape (= minimax-cn speaks the
            // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // `{type, description, enum}`).
            body["tools"] = tools.map { schema -> [String: Any] in
                var dict: [String: Any] = [
                    "name": schema.name,
                    "description": schema.description
                ]
                if !schema.inputSchema.isEmpty || !schema.required.isEmpty {
                    var props: [String: Any] = [:]
                    for (key, prop) in schema.inputSchema {
                        props[key] = prop.toJSON()
                    }
                    dict["input_schema"] = [
                        "type": "object",
                        "properties": props,
                        "required": schema.required
                    ]
                }
                return dict
            }
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Read the provider's cache counters out of a usage object.
    ///
    /// The providers disagree on the field names, so both shapes are
    /// read:
    ///   - The Anthropic shape: the counts sit directly in the usage
    ///     object, beside the input and output counts
    ///     (`cache_read_input_tokens` / `cache_creation_input_tokens`).
    ///   - The OpenAI-compatible shape: the cached count is nested
    ///     inside the prompt-token details (`prompt_tokens_details` →
    ///     `cached_tokens`).
    ///
    /// The nested shape is walked, not assumed: a provider that sends no
    /// prompt-token details sends no cached count, and a provider that
    /// sends only the flat shape still reports its counts.
    ///
    /// The counts are returned separately from the input count because a
    /// provider counts the cached prefix INSIDE the input count. Folding
    /// them together would bill the same tokens twice.
    static func cacheCounts(from usage: [String: Any]) -> (read: Int, creation: Int) {
        var read = usage["cache_read_input_tokens"] as? Int ?? 0
        var creation = usage["cache_creation_input_tokens"] as? Int ?? 0

        // The OpenAI-compatible shape: the cached count lives inside the
        // prompt-token details, so the nested dictionary is walked.
        if let details = usage["prompt_tokens_details"] as? [String: Any] {
            if read == 0 {
                read = details["cached_tokens"] as? Int ?? 0
            }
            if creation == 0 {
                creation = details["cache_creation_tokens"] as? Int ?? 0
            }
        }
        return (read, creation)
    }

    /// Build a usage value from a provider's usage object.
    ///
    /// The input and output counts are named by the wire format, so the
    /// caller passes the keys its provider uses. The cache counts are
    /// read by `cacheCounts(from:)`, which understands both provider
    /// shapes.
    static func usage(
        from usage: [String: Any],
        inputKey: String,
        outputKey: String
    ) -> LLMUsage {
        let cache = cacheCounts(from: usage)
        return LLMUsage(
            inputTokens: usage[inputKey] as? Int ?? 0,
            outputTokens: usage[outputKey] as? Int ?? 0,
            cacheReadTokens: cache.read,
            cacheCreationTokens: cache.creation
        )
    }

    // MARK: - OpenAI chat completions
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / - Returns: JSON-encoded request body Data
    public static func buildOpenAIRequest(
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
            )
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
                    "description": schema.description
                ]
                if !props.isEmpty || !schema.required.isEmpty {
                    function["parameters"] = [
                        "type": "object",
                        "properties": props,
                        "required": schema.required
                    ]
                }
                return [
                    "type": "function",
                    "function": function
                ]
            }
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Build the OpenAI messages array (= system prepended + user /
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
                case .text(let s): return s
                case .thinking(let t, _): return t
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

    // / Decode an OpenAI-format JSON response into an `LLMResponse`.
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Stop reason mapping: `"length"` -> `.maxTokens`, else `.endTurn`.
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

    // MARK: - Gemini native
    // … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / - Returns: JSON-encoded request body Data
    public static func buildGeminiRequest(
        model: String,
        messages: [LLMMessage],
        maxTokens: Int,
        systemPrompt: String?,
        // / reasoning effort from user setting.
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / nil = omit thinkingConfig (= Gemini default).
        reasoningEffort: String? = nil
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
        // wire reasoningEffort → Gemini thinkingBudget.
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // nil = omit thinkingConfig (= Gemini default = no thinking).
        if let effort = reasoningEffort, !effort.isEmpty {
            let budgetTokens: Int
            switch effort {
            case "low": budgetTokens = 1024
            case "medium": budgetTokens = 8192
            case "high": budgetTokens = 16384
            case "xhigh", "max": budgetTokens = 32768
            default: budgetTokens = 8192
            }
            // Merge into generationConfig (= if maxOutputTokens already set, extend)
            var genConfig = body["generationConfig"] as? [String: Any] ?? [:]
            genConfig["thinkingConfig"] = [
                "thinkingBudget": budgetTokens,
                "includeThoughts": false
            ]
            body["generationConfig"] = genConfig
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
            // Gemini counts the cached prefix inside its prompt-token
            // count, so the cached count is read from its own field and
            // kept beside the input count.
            usage = LLMUsage(
                inputTokens: metadata["promptTokenCount"] as? Int ?? 0,
                outputTokens: metadata["candidatesTokenCount"] as? Int ?? 0,
                cacheReadTokens: metadata["cachedContentTokenCount"] as? Int ?? 0,
                cacheCreationTokens: metadata["cacheTokens"] as? Int ?? 0
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