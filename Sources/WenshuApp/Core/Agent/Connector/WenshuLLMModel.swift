// WenshuLLMModel.swift
//
// LLM model enum for the wenshu minimax-cn connector (= the
// canonical default profile per AGENTS.md §11.2).

import Foundation

enum WenshuLLMModel: String, CaseIterable, Sendable {
    case m3 = "MiniMax-M3"
    case m2 = "MiniMax-M2"
    case reasoning = "MiniMax-Reasoning"

    /// Settings Picker display label (= `rawValue`).
    var label: String { rawValue }

    /// Provider slug for routing. Maps each model to its provider's
    /// slug (used by `WenshuVerifier.resolveCredentials` to look up
    /// the correct `apiKey` + `baseURL` from Keychain + `ProviderCatalog`).
    var providerSlug: String {
        switch self {
        case .m3, .m2, .reasoning:
            return "minimax-cn"
        }
    }
}