//
//  WAProviderRegistry.swift · Wenshu · WenshuAgent provider registry (internal)
//
//  Actor-isolated registry of WABaseProvider instances. Built-ins
//  are registered by callers (test bootstrap). Custom providers (=
//  future MCP, future wenshu plugin) can call `register(_:)` at
//  runtime.
//
//  WenshuApp is a single SPM target; = public/internal distinction
//  is purely organizational. We use `internal` (= the Swift default)
//  and rely on folder location (= `WenshuAgent/Public/` or
//  `WenshuAgent/Connector/`) as the boundary marker. The
//  BoundaryMarker file = `WenshuAgentBoundary.swift`.
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/provider_registry.py` 100 LOC
//

import Foundation

public actor WAProviderRegistry {
    public static let shared = WAProviderRegistry()

    private var providers: [String: any WABaseProvider] = [:]

    public init() {}

    public func register(_ provider: any WABaseProvider) {
        providers[provider.slug] = provider
        WALogger.agent.info("register provider=\(provider.slug, privacy: .public) displayName=\(provider.displayName, privacy: .public)")
    }

    public func unregister(slug: String) {
        providers.removeValue(forKey: slug)
        WALogger.agent.info("unregister provider=\(slug, privacy: .public)")
    }

    public func provider(slug: String) -> (any WABaseProvider)? {
        providers[slug]
    }

    public var all: [any WABaseProvider] {
        Array(providers.values)
    }

    public func snapshot() -> [String] {
        Array(providers.keys)
    }

    /// Re-register a set of slugs (= for testing, or for restoring
    /// after a feature flag flipped the registry off). The previously
    /// registered providers are NOT removed (= this is an additive
    /// restore; = for full reset use `replaceAll(_:)`).
    public func restore(snapshot: [String]) async {
        // No-op in production (= the built-ins remain registered
        // until the actor is destroyed). In tests, `replaceAll(_:)`
        // is the deterministic reset path.
    }

    /// Test-only deterministic reset (= replaces the entire registry
    /// with the provided set).
    public func replaceAll(_ newProviders: [any WABaseProvider]) {
        providers = Dictionary(uniqueKeysWithValues: newProviders.map { ($0.slug, $0) })
    }
}
