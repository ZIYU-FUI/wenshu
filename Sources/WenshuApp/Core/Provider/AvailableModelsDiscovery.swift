//
//  AvailableModelsDiscovery.swift · Wenshu · v0.23 ticket 011.001
//
// [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
// Boss 2026-08-23: 'chat zoneyesnoconfigfile,
// key, shouldgroup'.
//

import Foundation

/// One provider's available models (filtered by Keychain presence).
/// Boss 8/23: provider key show provider defaultModels.
public struct AvailableProviderModels: Sendable, Equatable {
    public let provider: Provider
    public let models: [String]

    public init(provider: Provider, models: [String]) {
        self.provider = provider
        self.models = models
    }
}

/// Discover providers that have keys configured + their defaultModels.
/// Scans `Provider.all` (curated list of 11 providers) and filters by Keychain presence.
public enum AvailableModelsDiscovery {

    /// loadFromKeychain: returns providers with non-empty Keychain keys + their defaultModels.
    /// Returns empty array if no providers are configured (e.g. fresh install).
    /// Sync (AppleKeychainStore.loadKeySync is sync). Caller wraps in async if needed.
    public static func loadFromKeychain() -> [AvailableProviderModels] {
        // v0.28 followup: use the shared ProviderKeychain backend (= respects
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
}