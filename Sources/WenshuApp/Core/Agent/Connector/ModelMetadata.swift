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

    // MARK: - H7 Hermes-Python gap port (= 1:1 port of hermes
    //         `agent/chat_completion_helpers.py` `estimate_request_context_tokens`).
    //
    // Wenshu-side wins (= per AGENTS.md §11.3):
    //
    // Direct port of hermes `agent/chat_completion_helpers.py` per
    // spec §3.1 #26 (= TICKET-HERMES-GAP-001 follow-up). The target
    // file already had the basic `estimateTokensRough` + `estimateMessagesTokensRough`
    // (= ⚠️ partial per gap audit 2026-09-04 = wenshu-side wins =
    // the per-text + per-message-list estimators). This H7 ticket
    // adds `estimateRequestContextTokens(_:)` (= 53 LOC hermes at
    // L66-L117) which handles the request-payload-level estimate
    // (= Chat Completions + Responses API + bare list + dict
    // fallback).
    //
    // The remaining 14 hermes functions in chat_completion_helpers.py
    // (= interruptible_api_call / build_api_kwargs /
    // build_assistant_message / try_activate_fallback /
    // handle_max_iterations / cleanup_task_resources /
    // interruptible_streaming_api_call / etc.) are intentionally
    // NOT ported in this ticket — they fall into separate wenshu-side
    // wins patterns (= ConversationLoop owns the request-building
    // + interruptible-call concerns; = per Q112 = one ticket per
    // file).
    //
    // Hermes Python line range cited in doc-comment below (= for
    // traceability back to `/Volumes/ANAN/.hermes/agent/
    // chat_completion_helpers.py`).

    /// Pure-function: estimate context/load tokens from an API
    /// payload (= dict or messages list) (= hermes
    /// `estimate_request_context_tokens` at
    /// `agent/chat_completion_helpers.py` L66-L117).
    ///
    /// Handles 4 shapes:
    ///   1. bare list -> treat as Chat Completions ``messages``
    ///   2. dict with ``messages`` -> Chat Completions (+ ``tools`` if present)
    ///   3. dict with ``input`` -> Responses API (+ ``instructions``/``tools``)
    ///   4. any other dict -> fall back to summing string values
    public static func estimateRequestContextTokens(_ apiPayload: Any) -> Int {
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
//         `agent/model_metadata.py` context-length-from-error
//         parsing helpers).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/model_metadata.py` per spec
// §3.1 #26 follow-up. The target file already had
// `contextWindow(for:)` (= hermes `get_model_context_length`)
// + `pricing(for:)` (= hermes `_extract_pricing`) at 419 LOC.
// This P7 ticket adds the 3 hermes error-message parsing
// helpers that close the audit-described gap
// (= parsing context-limit + output-cap info from
// provider error messages; = essential for context-
// overflow recovery + output-cap retry):
//
//   1. parseContextLimitFromError(_:) (= hermes L1068-L1096)
//   2. getContextLengthFromProviderError(...) (= hermes
//      L1098-L1116)
//   3. parseAvailableOutputTokensFromError(_:)
//      (= hermes L1118-L1140)
//
// Hermes Python line ranges cited in doc-comments below
// (= for traceability back to `/Volumes/ANAN/.hermes/agent/
// model_metadata.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - Pre-existing WenshuModelCatalog + ModelInfo + Pricing
//     + Features preserved (= Q112 no regressions).
//   - The 7 regex patterns from hermes L1076-L1084 preserved
//     1:1 (= vLLM "max_model_len" + Anthropic "max context
//     length" + OpenAI "context_length_exceeded" etc.).
//   - The sanity check `1024 <= limit <= 10_000_000`
//     preserved (= hermes explicit sanity range).
//   - The "lower than current" filter (= hermes
//     `get_context_length_from_provider_error`) preserved.
//   - The output-cap-error parsing (= hermes
//     `parse_available_output_tokens_from_error`)
//     preserved 1:1.
//
// The remaining 50+ hermes functions in model_metadata.py
// (= local endpoint detection / Codex OAuth / Nous portal /
// Anthropic direct / Gemini / etc.) are intentionally NOT
// ported in this ticket — they fall into separate wenshu-
// side wins patterns (= LLMConnector layer owns the
// provider-specific URL detection + auth flows; = per
// Q112 = one ticket per file).
//
// Per AGENTS.md §11 hard rule: Apple Foundation only. No
// third-party imports.

extension WenshuModelCatalog {

    // MARK: -- P7.1 parse context limit from error (= hermes L1068-L1096)

    /// Try to extract the actual context limit from an API
    /// error message (= hermes `parse_context_limit_from_error`
    /// at `agent/model_metadata.py` L1068-L1096).
    ///
    /// Many providers include the limit in their error text
    /// (= e.g. "maximum context length is 32768 tokens",
    /// "context_length_exceeded: 131072", "Maximum context
    /// size 32768 exceeded", "model's max context length
    /// is 65536").
    ///
    /// - Parameters:
    ///   - errorMessage: The error message to parse.
    /// - Returns: The parsed context limit, or nil if no
    ///   reasonable value was found (= outside the
    ///   `1024 <= limit <= 10_000_000` sanity range).
    public static func parseContextLimitFromError(_ errorMessage: String) -> Int? {
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

    /// Return a provider-reported lower context limit, if
    /// one is present (= hermes
    /// `get_context_length_from_provider_error` at
    /// `agent/model_metadata.py` L1098-L1116).
    ///
    /// Context-overflow recovery must not invent a new
    /// model window size. Some providers only say that the
    /// input exceeds the context window without reporting
    /// the actual maximum. In that case callers should
    /// keep the configured context length and try
    /// compression only, rather than stepping down through
    /// guessed probe tiers.
    ///
    /// - Parameters:
    ///   - errorMessage: The error message to parse.
    ///   - currentContextLength: The current configured
    ///     context length (= used to filter out values
    ///     that are not actually lower than current).
    /// - Returns: The lower limit (= parsed_limit if
    ///   `< currentContextLength`), or nil otherwise.
    public static func getContextLengthFromProviderError(
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

    /// Detect an "output cap too large" error and return
    /// how many output tokens are available (= hermes
    /// `parse_available_output_tokens_from_error` at
    /// `agent/model_metadata.py` L1118-L1140).
    ///
    /// Patterns: "max_tokens ... must be <= 8192",
    /// "max_output_tokens 4096", etc.
    ///
    /// - Parameters:
    ///   - errorMessage: The error message to parse.
    /// - Returns: The parsed output cap, or nil if no
    ///   reasonable value was found.
    public static func parseAvailableOutputTokensFromError(
        _ errorMessage: String
    ) -> Int? {
        let errorLower = errorMessage.lowercased()
        let patterns = [
            // "max_tokens ... must be <= 8192"
            #"max_tokens[^.]{0,80}<=\s*(\d{2,})"#,
            #"max_tokens[^.]{0,80}less than or equal to\s*(\d{2,})"#,
            // "max_output_tokens 4096"
            #"max_output_tokens\s*(?:is|of|:)?\s*(\d{2,})"#,
            // "max_completion_tokens ... 4096"
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