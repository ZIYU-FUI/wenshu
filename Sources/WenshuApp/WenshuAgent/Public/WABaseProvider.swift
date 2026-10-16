//
//  WABaseProvider.swift · Wenshu · WenshuAgent provider protocol (internal)
//
//  Replaces the static `enum Provider` (= 14 hardcoded built-in slugs
//  that could not be extended without touching the enum). Now any
//  module (= future MCP plugin, future wenshu internal feature) can
//  register a custom provider at runtime via `WAProviderRegistry.shared.register(_:)`.
//
//  WenshuApp is a single SPM target; = public/internal distinction
//  between files in the same target is purely organizational. We use
//  `internal` (= the Swift default) and rely on folder location
//  (= `WenshuAgent/Public/` or `WenshuAgent/Connector/`) as the
//  boundary marker. The BoundaryMarker file = `WenshuAgentBoundary.swift`.
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/provider_base.py` CatalogProviderBase ABC + wenshu `Provider.swift` enum
//

import Foundation

enum WireFormat: String, Sendable, Codable {
    /// Anthropic Messages API format (= compatible with minimax-cn's
    /// Anthropic-compatible endpoint).
    case anthropic

    /// OpenAI Chat Completions API format (= used by OpenAI,
    /// DeepSeek, OpenRouter).
    case openai

    /// Google GenAI native format.
    case gemini

    /// Ollama /api/chat local format.
    case ollama
}

protocol WABaseProvider: Sendable {
    var slug: String { get }
    var displayName: String { get }
    var defaultBaseURL: String { get }
    var defaultContextWindowTokens: Int { get }
    var defaultModels: [String] { get }
    var wireFormat: WireFormat { get }
    var authHeader: ProviderAuthMode { get }
    var requiresOAuth: Bool { get }
    var modelListURL: URL? { get }
}
