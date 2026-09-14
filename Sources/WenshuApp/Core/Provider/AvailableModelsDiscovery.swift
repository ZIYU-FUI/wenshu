//
//  AvailableModelsDiscovery.swift · Wenshu · v0.23 ticket 011.001
//
// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
// Boss 2026-08-23: 'chat zoneyesnoconfigfile,
// key, shouldgroup'.
//

import Foundation

// v0.72 SwiftData migration: this file uses ProviderKeychain for metadata read/write.
// Migration to WSProviderKeyRepository is deferred (per AGENTS.md §11 AppleKeychain
// contract; = metadata is the only sqlite piece in this path). Future ticket.
#warning("wenshu.AvailableModelsDiscovery: ProviderKeychain metadata is sqlite-backed; = migrate to WSProviderKeyRepository in future ticket")

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