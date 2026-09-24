//
// WenshuLLMModel.swift · Wenshu · v0.21 ticket 04 (Settings config)
//

import Foundation

/// MiniMax (2026-08-21 'Settingsconfig', 3 default model, change)
enum WenshuLLMModel: String, CaseIterable, Sendable {
    case m3 = "MiniMax-M3"
    case m2 = "MiniMax-M2"
    case reasoning = "MiniMax-Reasoning"

    /// Settings Picker show label (= rawValue,,)
    var label: String { rawValue }

    /// .001: provider slug for routing.
    /// Maps each model to its provider's slug (used by WenshuVerifier.resolveCredentials
    /// to look up the correct apiKey + baseURL from Keychain + ProviderCatalog).
    /// 
    var providerSlug: String {
        switch self {
        case .m3, .m2, .reasoning:
            return "minimax-cn"
        }
    }
}
