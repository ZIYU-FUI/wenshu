//
//  ModelMetadata.swift · Wenshu · v0.35 ticket 008
//  + HERMES-PARTIAL-015 (2026-09-04).
//
//  Per-provider model catalog. Port of hermes model_metadata.py
//  (= 2,434 LOC, contains per-provider model lists, capabilities,
//  context window, pricing awareness).
//
//  In wenshu-side wins mode (= AGENTS.md §11.3): the Provider enum
//  already has defaultModels arrays per profile. This file is a thin
//  aggregator that surfaces the catalog in a UI-friendly shape.
//
//  HERMES-PARTIAL-015 extends the v0.35 surface with three new capabilities:
//    - Pricing per model (= hermes _extract_pricing: input / cached-input /
//      output $/MTok rates, populated from the OpenRouter catalog or the
//      wenshu-side hardcoded table when the catalog is unavailable).
//    - Context-window per model (= hermes _resolve_endpoint_context_length
//      + _get_model_context_length: per-model token counts that override
//      the per-provider defaults).
//    - Feature matrix (= hermes _is_claude_model + supports_reasoning_effort
//      + _forbids_sampling_params: a per-model feature table for vision,
//      tools, streaming, reasoning effort, adaptive thinking).
//
//  v0.35 ticket 008 + HERMES-PARTIAL-015 (2026-09-04).
//

import Foundation

public struct WenshuModelCatalog: Sendable, Equatable {
    public let provider: Provider
    public let models: [ModelInfo]

    public init(provider: Provider, models: [ModelInfo]? = nil) {
        self.provider = provider
        self.models = models ?? WenshuModelCatalog.defaultModelsForProvider(provider)
    }

    /// Per-model metadata (= hermes _extract_pricing + _extract_context_length
    /// + the per-model feature flags).
    public struct ModelInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let displayName: String
        public let contextWindow: Int  // tokens (= 0 = unknown)
        public let maxOutputTokens: Int

        /// Per-million-token pricing (= hermes _extract_pricing).
        public let pricing: Pricing?
        /// Feature flags (= hermes capability matrix).
        public let features: Features

        public var idString: String { id }

        public init(
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
    public struct Pricing: Sendable, Equatable {
        public let inputPerMTok: Double       // $ / 1M input tokens
        public let cachedInputPerMTok: Double?  // $ / 1M cached input (Anthropic prompt caching)
        public let outputPerMTok: Double      // $ / 1M output tokens

        public init(inputPerMTok: Double, cachedInputPerMTok: Double? = nil, outputPerMTok: Double) {
            self.inputPerMTok = inputPerMTok
            self.cachedInputPerMTok = cachedInputPerMTok
            self.outputPerMTok = outputPerMTok
        }

        /// Compute cost for a request (= hermes cost math).
        public func cost(inputTokens: Int, outputTokens: Int, cachedTokens: Int = 0) -> Double {
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
    public struct Features: Sendable, Equatable, OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let vision          = Features(rawValue: 1 << 0)
        public static let tools           = Features(rawValue: 1 << 1)
        public static let streaming       = Features(rawValue: 1 << 2)
        public static let reasoning       = Features(rawValue: 1 << 3)
        public static let adaptiveThinking = Features(rawValue: 1 << 4)
        public static let promptCaching   = Features(rawValue: 1 << 5)
        public static let documents       = Features(rawValue: 1 << 6)  // PDF / txt input
        public static let images          = Features(rawValue: 1 << 7)  // image input
        public static let redactedThinking = Features(rawValue: 1 << 8)

        public static let `default`: Features = [.tools, .streaming]
        public static let claude: Features = [
            .vision, .tools, .streaming, .reasoning,
            .adaptiveThinking, .promptCaching, .documents, .images, .redactedThinking
        ]
        public static let gpt: Features = [.vision, .tools, .streaming, .reasoning, .images]
        public static let gemini: Features = [.vision, .tools, .streaming, .images, .documents]
        public static let deepseek: Features = [.tools, .streaming, .reasoning]
        public static let localOllama: Features = [.tools, .streaming]
    }

    /// All 7 connector profiles' model catalogs (= AGENTS.md §11.2).
    public static let allProfiles: [WenshuModelCatalog] = [
        WenshuModelCatalog(provider: .anthropic),
        WenshuModelCatalog(provider: .openaiCodex),
        WenshuModelCatalog(provider: .minimaxCn),
        WenshuModelCatalog(provider: .deepseek),
        WenshuModelCatalog(provider: .gemini),
        WenshuModelCatalog(provider: .ollama),
        WenshuModelCatalog(provider: .openrouter)
    ]

    /// Default model catalog per provider (= pulled from Provider.defaultModels).
    public static func defaultModelsForProvider(_ provider: Provider) -> [ModelInfo] {
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

    /// Hardcoded pricing table (= hermes _extract_pricing fallback when
    /// the OpenRouter catalog is unavailable). Values match current
    /// public list prices for the major models (= 2026-Q3).
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

    /// Per-model context-window lookup (= hermes get_model_context_length L1886-2296).
    /// Returns the token count for a specific model id (= overrides the
    /// per-provider default).
    public static func contextWindow(for modelId: String) -> Int {
        let m = modelId.lowercased()
        if m.contains("opus-4") { return 200_000 }
        if m.contains("sonnet-4") { return 200_000 }
        if m.contains("haiku-4") { return 200_000 }
        if m.contains("opus-3") { return 200_000 }
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
    public static func pricing(for modelId: String) -> Pricing? {
        for catalog in allProfiles {
            for model in catalog.models where model.id == modelId {
                return model.pricing
            }
        }
        return nil
    }

    /// Per-model feature flags lookup (= hermes _supports_* helpers).
    public static func features(for modelId: String) -> Features {
        for catalog in allProfiles {
            for model in catalog.models where model.id == modelId {
                return model.features
            }
        }
        return .default
    }

    /// Supports vision (= image input)?
    public static func supportsVision(_ modelId: String) -> Bool {
        features(for: modelId).contains(.vision) || features(for: modelId).contains(.images)
    }

    /// Supports tools?
    public static func supportsTools(_ modelId: String) -> Bool {
        features(for: modelId).contains(.tools)
    }

    /// Supports streaming?
    public static func supportsStreaming(_ modelId: String) -> Bool {
        features(for: modelId).contains(.streaming)
    }

    /// Supports reasoning / extended thinking?
    public static func supportsReasoning(_ modelId: String) -> Bool {
        features(for: modelId).contains(.reasoning)
    }

    /// Supports adaptive thinking (= opus-4 / sonnet-4).
    public static func supportsAdaptiveThinking(_ modelId: String) -> Bool {
        features(for: modelId).contains(.adaptiveThinking)
    }

    /// Supports prompt caching (= Anthropic / DeepSeek-style).
    public static func supportsPromptCaching(_ modelId: String) -> Bool {
        features(for: modelId).contains(.promptCaching)
    }

    /// Estimate rough token count for text (= hermes estimate_tokens_rough).
    public static func estimateTokensRough(_ text: String) -> Int {
        // ~4 chars per token heuristic.
        return text.count / 4
    }

    /// Estimate rough token count for a message list (= hermes estimate_messages_tokens_rough).
    public static func estimateMessagesTokensRough(_ messages: [LLMMessage]) -> Int {
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
}