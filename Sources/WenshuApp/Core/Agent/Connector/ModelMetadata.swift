//
//  ModelMetadata.swift · Wenshu · v0.35 ticket 008
//
//  Per-provider model catalog. Port of hermes model_metadata.py
//  (= 2434 LOC, contains per-provider model lists, capabilities,
//  context window, pricing awareness).
//
//  In wenshu-side wins mode (= AGENTS.md §11.3): the Provider enum
//  already has defaultModels arrays per profile. This file is a thin
//  aggregator that surfaces the catalog in a UI-friendly shape.
//

import Foundation

/// Per-provider model catalog. Port of hermes model_metadata.py
/// (= 2434 LOC, contains per-provider model lists, capabilities,
/// context window, pricing awareness).
///
/// In wenshu-side wins mode (= AGENTS.md §11.3): the Provider enum
/// already has defaultModels arrays per profile. This file is a thin
/// aggregator that surfaces the catalog in a UI-friendly shape.
///
public struct WenshuModelCatalog: Sendable, Equatable {
    public let provider: Provider
    public let models: [ModelInfo]

    public init(provider: Provider, models: [ModelInfo]? = nil) {
        self.provider = provider
        self.models = models ?? WenshuModelCatalog.defaultModelsForProvider(provider)
    }

    public struct ModelInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let displayName: String
        public let contextWindow: Int  // tokens (= 0 = unknown)
        public let maxOutputTokens: Int

        public var idString: String { id }
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
                maxOutputTokens: 4096
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
}