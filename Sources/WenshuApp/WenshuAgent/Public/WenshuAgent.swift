//
//  WenshuAgent.swift · Wenshu · WenshuAgent public facade (forthcoming)
//
//  This file is the public entry point that chat / settings / import
//  layers will call. It is currently a thin facade over the existing
//  internals (= WenshuConductor + ProviderKeychain + LLMModelDiscovery);
//  the goal is to centralize the call surface so we can later swap
//  the implementation (= e.g. add WALogger call, or a new connector)
//  without touching 14 callers.
//
//  Active contract today:
//
//      await WenshuAgent.shared.providersWithKeys() -> [String]
//      await WenshuAgent.shared.availableModels(for: provider, forceRefresh: false) -> [String]
//
//  RATIONALE (hermes `agent/agent.py` Actor model ported):
//  Hermes uses a single `agent.Agent` actor that owns the provider
//  registry + LLM call + token state. Wenshu does not need that level
//  of state (we have per-conversation SwiftData), but the facade
//  pattern (= one entry point + delegation) is the right shape for
//  future MCP / plugin support.
//
//  Future tickets:
//   - add `chat(messages:system:model:tools:streamCallback:)` (P3.5+).
//   - migrate callers from `WenshuConductor` / `ProviderKeychain` /
//     `LLMModelDiscovery` direct usage to `WenshuAgent.shared.*`.
//

import Foundation

actor WenshuAgent {
    static let shared = WenshuAgent()

    private let modelDiscovery = LLMModelDiscovery()

    private init() {}

    // MARK: - Providers with keys

    /// Returns the slugs of providers that have an API key configured
    /// (= wenshu-internal flag; = no plaintext secrets leave this layer).
    /// Delegates to `ProviderKeychain.listProvidersWithKeys()`.
    func providersWithKeys() async -> [String] {
        await Task.detached {
            ProviderKeychain.listProvidersWithKeys()
        }.value
    }

    // MARK: - Available models

    /// Returns the available model slugs for the given provider.
    /// Delegates to `LLMModelDiscovery.discover()`.
    func availableModels(
        for provider: Provider,
        forceRefresh: Bool = false
    ) async -> [String] {
        let result = await modelDiscovery.discover(
            provider: provider,
            forceRefresh: forceRefresh
        )
        return result.models
    }
}
