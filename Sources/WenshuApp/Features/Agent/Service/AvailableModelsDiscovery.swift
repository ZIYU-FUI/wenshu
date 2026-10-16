// AvailableModelsDiscovery.swift
//
// Discovers available models for a provider (= the live list
// populated from the provider's `/models` endpoint when reachable,
// with the canonical `Provider.defaultModels` fallback when the
// endpoint is offline or when the user has not yet configured
// a key for the provider).
//
// Per boss 2026-10-16 OOB "配好 KEY 后, 模型设置中的可选
// 模型, 也应该通过 API 查询. 同样不能写死":
//   - This file is the legacy keychain-driven loader (= reads
//     the configured providers from the Keychain and returns
//     their `defaultModels`).
//   - The live model enumeration (= `/models` endpoint
//     query, per-provider response parsing, 5-minute
//     cache) lives in `LLMModelDiscovery` (=
//     `Sources/WenshuApp/Features/Agent/Service/
//     LLMModelDiscovery.swift`).
//   - The Settings UI now uses `LLMModelDiscovery` (= the
//     model picker reflects the live list; = when the
//     endpoint is unreachable, the picker falls back to
//     `Provider.defaultModels` via this legacy function).
//
// The two coexist (= `loadFromKeychain` is still the
// canonical "which providers are configured" query; =
// `LLMModelDiscovery` adds "and what models they serve").

import Foundation

/// One provider's available models (filtered by Keychain presence).
/// 2026-08-23: provider key show provider defaultModels.
struct AvailableProviderModels: Sendable, Equatable {
    let provider: Provider
    let models: [String]

    init(provider: Provider, models: [String]) {
        self.provider = provider
        self.models = models
    }
}

/// Discover providers that have keys configured + their defaultModels.
/// Scans `Provider.all` (curated list of 11 providers) and filters by Keychain presence.
enum AvailableModelsDiscovery {

    /// loadFromKeychain: returns providers with non-empty Keychain keys + their defaultModels.
    /// Returns empty array if no providers are configured (e.g. fresh install).
    /// Sync (AppleKeychainStore.loadKeySync is sync). Caller wraps in async if needed.
    static func loadFromKeychain() -> [AvailableProviderModels] {
        // use the shared ProviderKeychain backend (= respects
        // setBackendForTesting for dev/cua verify) instead of constructing
        // a fresh AppleKeychainStore (which would always hit the real
        // keychain regardless of the debug override).
        return Provider.all.compactMap { provider in
            // Skip providers that don't store keys (e.g. require OAuth).
            guard !provider.requiresOAuth else { return nil }
            // Check Keychain for this provider's key.
            guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else {
                return nil  // user hasn't configured this provider
            }
            return AvailableProviderModels(
                provider: provider,
                models: provider.defaultModels
            )
        }
    }

    /// Async variant (= the new code path). Calls
    /// `LLMModelDiscovery` to get the live list (=
    /// `/models` endpoint), falling back to
    /// `Provider.defaultModels` when the endpoint is
    /// unreachable. Used by the Settings UI's model
    /// picker (= per boss 2026-10-16 OOB "配好 KEY
    /// 后, 模型设置中的可选模型, 也应该通过 API 查询").
    static func loadLive() async -> [AvailableProviderModels] {
        let discovery = LLMModelDiscovery()
        var results: [AvailableProviderModels] = []
        for provider in Provider.all {
            // Skip providers that don't store keys.
            guard !provider.requiresOAuth else { continue }
            // Skip providers the user has not configured
            // (= the Settings UI only shows configured
            // providers in the picker).
            guard let key = ProviderKeychain.loadKeySync(for: provider),
                  !key.isEmpty else {
                continue
            }
            let discovered = await discovery.discover(provider: provider)
            results.append(AvailableProviderModels(
                provider: provider,
                models: discovered.models
            ))
        }
        return results
    }
}
