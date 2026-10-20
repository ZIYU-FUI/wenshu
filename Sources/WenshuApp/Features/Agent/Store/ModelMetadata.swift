// ModelMetadata.swift
// … (= 20 rationale lines collapsed; = A112 docblock collapse per §1.8)
// reasoning effort, adaptive thinking).
import Foundation
import WenshuAgent

struct WenshuModelCatalog: Sendable, Equatable {
    let provider: Provider
    let models: [ModelInfo]

    init(provider: Provider, models: [ModelInfo]? = nil) {
        self.provider = provider
        self.models = models ?? WenshuModelCatalog.defaultModelsForProvider(provider)
    }

    /// Per-model metadata (= hermes _extract_pricing + _extract_context_length
    /// + the per-model feature flags).
    struct ModelInfo: Sendable, Equatable, Identifiable {
        let id: String
        let displayName: String
        let contextWindow: Int  // tokens (= 0 = unknown)
        let maxOutputTokens: Int

        /// Per-million-token pricing (= hermes _extract_pricing).
        let pricing: Pricing?
        /// Feature flags (= hermes capability matrix).
        let features: Features

        var idString: String { id }

        init(
            id: String,
            displayName: String,
            contextWindow: Int,
            maxOutputTokens: Int,
            pricing: Pricing? = nil,
            features: Features = .default
        ) {
            self.id = id
            self.displayName = displayName
            self.contextWindow = contextWindow
            self.maxOutputTokens = maxOutputTokens
            self.pricing = pricing
            self.features = features
        }
    }

    /// Pricing per million tokens (= hermes _extract_pricing).
    struct Pricing: Sendable, Equatable {
        let inputPerMTok: Double       // $ / 1M input tokens
        let cachedInputPerMTok: Double?  // $ / 1M cached input (Anthropic prompt caching)
        let outputPerMTok: Double      // $ / 1M output tokens

        init(inputPerMTok: Double, cachedInputPerMTok: Double? = nil, outputPerMTok: Double) {
            self.inputPerMTok = inputPerMTok
            self.cachedInputPerMTok = cachedInputPerMTok
            self.outputPerMTok = outputPerMTok
        }

        /// Compute cost for a request (= hermes cost math).
        func cost(inputTokens: Int, outputTokens: Int, cachedTokens: Int = 0) -> Double {
            let uncachedInput = max(inputTokens - cachedTokens, 0)
            let inputCost = Double(uncachedInput) / 1_000_000.0 * inputPerMTok
            let cachedCost: Double
            if let cached = cachedInputPerMTok {
                cachedCost = Double(cachedTokens) / 1_000_000.0 * cached
            } else {
                cachedCost = 0
            }
            let outputCost = Double(outputTokens) / 1_000_000.0 * outputPerMTok
            return inputCost + cachedCost + outputCost
        }
    }

    /// Per-model feature matrix (= hermes _supports_* helpers).
    struct Features: Sendable, Equatable, OptionSet {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }

        static let vision          = Features(rawValue: 1 << 0)
        static let tools           = Features(rawValue: 1 << 1)
        static let streaming       = Features(rawValue: 1 << 2)
        static let reasoning       = Features(rawValue: 1 << 3)
        static let adaptiveThinking = Features(rawValue: 1 << 4)
        static let promptCaching   = Features(rawValue: 1 << 5)
        static let documents       = Features(rawValue: 1 << 6)  // PDF / txt input
        static let images          = Features(rawValue: 1 << 7)  // image input
        static let redactedThinking = Features(rawValue: 1 << 8)

        static let `default`: Features = [.tools, .streaming]
        static let claude: Features = [
            .vision, .tools, .streaming, .reasoning,
            .adaptiveThinking, .promptCaching, .documents, .images, .redactedThinking
        ]
        static let gpt: Features = [.vision, .tools, .streaming, .reasoning, .images]
        static let gemini: Features = [.vision, .tools, .streaming, .images, .documents]
        static let deepseek: Features = [.tools, .streaming, .reasoning]
        static let localOllama: Features = [.tools, .streaming]
    }

    /// All 14 first-class + custom connector profiles' model catalogs (= AGENTS.md §11.2).
    static let allProfiles: [WenshuModelCatalog] = [
        WenshuModelCatalog(provider: .anthropic),
        WenshuModelCatalog(provider: .openaiCodex),
        WenshuModelCatalog(provider: .minimaxCn),
        WenshuModelCatalog(provider: .deepseek),
        WenshuModelCatalog(provider: .gemini),
        WenshuModelCatalog(provider: .ollama),
        WenshuModelCatalog(provider: .openrouter)
    ]

    /// Default model catalog per provider (= pulled from Provider.defaultModels).
    static func defaultModelsForProvider(_ provider: Provider) -> [ModelInfo] {
        provider.defaultModels.map { modelId in
            ModelInfo(
                id: modelId,
                displayName: modelId,
                contextWindow: defaultContextWindow(for: provider),
                maxOutputTokens: defaultMaxOutput(for: provider, model: modelId),
                pricing: defaultPricing(for: provider, model: modelId),
                features: defaultFeatures(for: provider, model: modelId)
            )
        }
    }

    private static func defaultContextWindow(for provider: Provider) -> Int {
        switch provider.slug {
        case "anthropic": return 200_000
        case "minimax-cn": return 1_000_000
        case "openai-codex": return 128_000
        case "deepseek": return 64_000
        case "gemini": return 1_000_000
        case "ollama": return 0  // model-dependent
        case "openrouter": return 0  // model-dependent
        default: return 0
        }
    }

    private static func defaultMaxOutput(for provider: Provider, model: String) -> Int {
        switch provider.slug {
        case "anthropic":
            return AnthropicAdapter.maxOutputTokens(for: model)
        case "minimax-cn": return 8_192
        case "openai-codex": return 16_384
        case "deepseek": return 8_192
        case "gemini": return 8_192
        case "ollama": return 4_096
        case "openrouter": return 4_096
        default: return 4_096
        }
    }

    // / Hardcoded pricing table (= hermes _extract_pricing fallback when
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / public list prices for the major models (third quarter of 2026).
    private static func defaultPricing(for provider: Provider, model: String) -> Pricing? {
        switch provider.slug {
        case "anthropic":
            if model.contains("opus") {
                return Pricing(inputPerMTok: 15.0, cachedInputPerMTok: 1.50, outputPerMTok: 75.0)
            }
            if model.contains("sonnet") {
                return Pricing(inputPerMTok: 3.0, cachedInputPerMTok: 0.30, outputPerMTok: 15.0)
            }
            if model.contains("haiku") {
                return Pricing(inputPerMTok: 0.80, cachedInputPerMTok: 0.08, outputPerMTok: 4.0)
            }
            return nil
        case "openai-codex":
            if model.contains("gpt-5") || model.contains("o3") || model.contains("o4") {
                return Pricing(inputPerMTok: 2.50, outputPerMTok: 10.0)
            }
            if model.contains("gpt-4o") {
                return Pricing(inputPerMTok: 2.50, outputPerMTok: 10.0)
            }
            return Pricing(inputPerMTok: 1.0, outputPerMTok: 3.0)
        case "minimax-cn":
            return Pricing(inputPerMTok: 1.0, outputPerMTok: 4.0)
        case "deepseek":
            return Pricing(inputPerMTok: 0.27, cachedInputPerMTok: 0.07, outputPerMTok: 1.10)
        case "gemini":
            if model.contains("pro") {
                return Pricing(inputPerMTok: 1.25, outputPerMTok: 5.0)
            }
            return Pricing(inputPerMTok: 0.075, outputPerMTok: 0.30)
        case "ollama", "openrouter":
            return nil  // local / routed
        default:
            return nil
        }
    }

    private static func defaultFeatures(for provider: Provider, model: String) -> Features {
        switch provider.slug {
        case "anthropic":
            // Opus/Sonnet get the full feature set; Haiku drops adaptive thinking.
            if model.contains("haiku") {
                return [.vision, .tools, .streaming, .reasoning, .promptCaching, .documents, .images, .redactedThinking]
            }
            return .claude
        case "openai-codex":
            return .gpt
        case "minimax-cn":
            return [.vision, .tools, .streaming, .reasoning, .images]
        case "deepseek":
            return .deepseek
        case "gemini":
            return .gemini
        case "ollama":
            return .localOllama
        case "openrouter":
            return [.vision, .tools, .streaming, .images, .documents]
        default:
            return .default
        }
    }

    // MARK: - Helpers (= hermes _is_claude_model + _supports_reasoning_effort + _get_model_context_length)
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / per-provider default).
    static func contextWindow(for modelId: String) -> Int {
        let m = modelId.lowercased()
        if m.contains("opus-4") { return 200_000 }
        if m.contains("sonnet-4") { return 200_000 }
        if m.contains("haiku-4") { return 200_000 }
        if m.contains("opus-3") { return 200_000 }
        // Claude 3.5 family (= "claude-3-5-sonnet" + "claude-3-5-haiku")
        if m.contains("sonnet-3-5") || m.contains("3-5-sonnet") { return 200_000 }
        if m.contains("haiku-3-5") || m.contains("3-5-haiku") { return 200_000 }
        // Catch-all for older sonnet-3 / haiku-3 (= "claude-3-sonnet-...")
        if m.contains("sonnet-3") { return 200_000 }
        if m.contains("haiku-3") { return 200_000 }
        if m.contains("gpt-5") || m.contains("gpt-4o") { return 128_000 }
        if m.contains("o3") || m.contains("o4") { return 128_000 }
        if m.contains("deepseek") { return 64_000 }
        if m.contains("gemini-2") || m.contains("gemini-1.5") { return 1_000_000 }
        if m.contains("minimax") || m.contains("MiniMax") { return 1_000_000 }
        return 0
    }

    /// Per-model pricing lookup (= hermes _extract_pricing).
    static func pricing(for modelId: String) -> Pricing? {
        for catalog in allProfiles {
            for model in catalog.models where model.id == modelId {
                return model.pricing
            }
        }
        return nil
    }

    /// Per-model feature flags lookup (= hermes _supports_* helpers).
    static func features(for modelId: String) -> Features {
        for catalog in allProfiles {
            for model in catalog.models where model.id == modelId {
                return model.features
            }
        }
        return .default
    }

    /// Supports vision (= image input)?
    static func supportsVision(_ modelId: String) -> Bool {
        features(for: modelId).contains(.vision) || features(for: modelId).contains(.images)
    }

    /// Supports tools?
    static func supportsTools(_ modelId: String) -> Bool {
        features(for: modelId).contains(.tools)
    }

    /// Supports streaming?
    static func supportsStreaming(_ modelId: String) -> Bool {
        features(for: modelId).contains(.streaming)
    }

    /// Supports reasoning / extended thinking?
    static func supportsReasoning(_ modelId: String) -> Bool {
        features(for: modelId).contains(.reasoning)
    }

    /// Supports adaptive thinking (= opus-4 / sonnet-4).
    static func supportsAdaptiveThinking(_ modelId: String) -> Bool {
        features(for: modelId).contains(.adaptiveThinking)
    }

    /// Supports prompt caching (= Anthropic / DeepSeek-style).
    static func supportsPromptCaching(_ modelId: String) -> Bool {
        features(for: modelId).contains(.promptCaching)
    }

    /// Estimate rough token count for text (= hermes estimate_tokens_rough).
    static func estimateTokensRough(_ text: String) -> Int {
        // ~4 chars per token heuristic.
        return text.count / 4
    }

    /// Estimate rough token count for a message list (= hermes estimate_messages_tokens_rough).
    static func estimateMessagesTokensRough(_ messages: [LLMMessage]) -> Int {
        var total = 0
        for m in messages {
            for block in m.blocks {
                total += block.textValue.count / 4
            }
            // Per-message overhead.
            total += 4
        }
        return total
    }

    // MARK: - H7 Hermes-Python gap port (= 1:1 port of hermes
    // … (= 35 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   4. any other dict -> fall back to summing string values
    static func estimateRequestContextTokens(_ apiPayload: Any) -> Int {
        func chars(_ value: Any) -> Int {
            if value is NSNull { return 0 }
            if let s = value as? String { return s.count }
            if let n = value as? NSNumber { return n.stringValue.count }
            if let arr = value as? [Any] {
                return arr.reduce(0) { $0 + chars($1) }
            }
            if let dict = value as? [String: Any] {
                return dict.values.reduce(0) { $0 + chars($1) }
            }
            return String(describing: value).count
        }

        func messageChars(_ messages: Any) -> Int {
            if let arr = messages as? [Any] {
                return arr.reduce(0) { $0 + chars($1) }
            }
            return chars(messages)
        }

        if let messages = apiPayload as? [Any] {
            return messageChars(messages) / 4
        }

        if let dict = apiPayload as? [String: Any] {
            if let messages = dict["messages"] as? [Any] {
                var totalChars = messageChars(messages)
                if let tools = dict["tools"] {
                    totalChars += chars(tools)
                }
                return totalChars / 4
            }

            if dict["input"] != nil {
                let totalChars = chars(dict["input"] ?? NSNull())
                    + chars(dict["instructions"] ?? NSNull())
                    + chars(dict["tools"] ?? NSNull())
                return totalChars / 4
            }

            return dict.values.reduce(0) { $0 + chars($1) } / 4
        }

        return chars(apiPayload) / 4
    }
}

// MARK: - P7 Hermes-Python gap port (= 1:1 port of hermes
// … (= 48 rationale lines collapsed; = A112 docblock collapse per §1.8)
// third-party imports.
extension WenshuModelCatalog {

    // MARK: -- P7.1 parse context limit from error (= hermes L1068-L1096)
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   `1024 <= limit <= 10_000_000` sanity range).
    static func parseContextLimitFromError(_ errorMessage: String) -> Int? {
        let errorLower = errorMessage.lowercased()

        // The 7 hermes regex patterns (= L1076-L1084).
        let patterns = [
            // vLLM: "max_model_len 32768", "=32768", ": 32768", "(32768)", "is 32768"
            #"max_model_len\s*(?:is\s*)?[:=(]?\s*(\d{4,})"#,
            // vLLM alt: "maximum model length 131072", "... is 131072"
            #"maximum model length\s*(?:is\s*)?[:=(]?\s*(\d{4,})"#,
            // "(?:max(?:imum)?|limit)\s*(?:context\s*)?(?:length|size|window)?\s*(?:is|of|:)?\s*(\d{4,})"
            #"(?:max(?:imum)?|limit)\s*(?:context\s*)?(?:length|size|window)?\s*(?:is|of|:)?\s*(\d{4,})"#,
            // "context\s*(?:length|size|window)\s*(?:is|of|:)?\s*(\d{4,})"
            #"context\s*(?:length|size|window)\s*(?:is|of|:)?\s*(\d{4,})"#,
            // "(\d{4,})\s*(?:token)?\s*(?:context|limit)"
            #"(\d{4,})\s*(?:token)?\s*(?:context|limit)"#,
            // ">\s*(\d{4,})\s*(?:max|limit|token)"  -- "250000 tokens > 200000 maximum"
            #">\s*(\d{4,})\s*(?:max|limit|token)"#,
            // "(\d{4,})\s*(?:max(?:imum)?)\b"
            #"(\d{4,})\s*(?:max(?:imum)?)\b"#,
            // OpenAI: "context_length_exceeded: 131072" (= colons after
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // Google error formats).
            #"context_length(?:_exceeded)?\s*[:=]?\s*(\d{4,})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(errorLower.startIndex..., in: errorLower)
            if let match = regex.firstMatch(in: errorLower, options: [], range: range),
               match.numberOfRanges >= 2 {
                let captureRange = match.range(at: 1)
                guard captureRange.location != NSNotFound,
                      let swiftRange = Range(captureRange, in: errorLower),
                      let limit = Int(errorLower[swiftRange])
                else { continue }
                if (1024...10_000_000).contains(limit) {
                    return limit
                }
            }
        }
        return nil
    }

    // MARK: -- P7.2 get context length from provider error (= hermes L1098-L1116)
    // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   `< currentContextLength`), or nil otherwise.
    static func getContextLengthFromProviderError(
        errorMessage: String,
        currentContextLength: Int
    ) -> Int? {
        guard let parsedLimit = parseContextLimitFromError(errorMessage) else {
            return nil
        }
        if parsedLimit < currentContextLength {
            return parsedLimit
        }
        return nil
    }

    // MARK: -- P7.3 parse available output tokens (= hermes L1118-L1140)
    // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   reasonable value was found.
    static func parseAvailableOutputTokensFromError(
        _ errorMessage: String
    ) -> Int? {
        let errorLower = errorMessage.lowercased()
        let patterns = [
            // "max_tokens ... must be <= 8192"
            #"max_tokens[^.]{0,80}<=\s*(\d{2,})"#,
            #"max_tokens[^.]{0,80}less than or equal to\s*(\d{2,})"#,
            // "max_output_tokens 4096"
            #"max_output_tokens\s*(?:is|of|:)?\s*(\d{2,})"#,
            // "max_completion_tokens 4096" (= no intervening prose,
            // common in OpenAI gpt-5 family errors)
            #"max_completion_tokens\s*[:=]?\s*(\d{2,})"#,
            // "max_completion_tokens ... 4096" (= with prose before number)
            #"max_completion_tokens[^.]{0,80}(\d{2,})"#,
            // generic "output token limit ... 4096"
            #"output\s*(?:token)?\s*(?:limit|cap)\s*(?:is|of|:)?\s*(\d{2,})"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(errorLower.startIndex..., in: errorLower)
            if let match = regex.firstMatch(in: errorLower, options: [], range: range),
               match.numberOfRanges >= 2 {
                let captureRange = match.range(at: 1)
                guard captureRange.location != NSNotFound,
                      let swiftRange = Range(captureRange, in: errorLower),
                      let cap = Int(errorLower[swiftRange])
                else { continue }
                if (16...10_000_000).contains(cap) {
                    return cap
                }
            }
        }
        return nil
    }
}
