//
//  KeylessRing.swift · Wenshu
//
//  Round-robin ring of WebSearchProvider instances with rate-limit-shaped
//  failover. (= 1:1 port of hermes plugins/web/keyless_mcp.py `_walk_ring`.)
//
//  Ring order (= fixed for wenshu single-user single-app; = no
//  round-robin cursor; = hermes's `_ring_cursor` is for fleet-wide
//  load-spreading across multiple invocations, which wenshu does not
//  need):
//
//      ParallelKeylessProvider -> ExaKeylessProvider -> KeenableKeylessProvider
//
//  Failover rules (= hermes `_throttled` shape):
//
//  1. Provider returns non-empty results          -> return first non-empty set
//  2. Provider returns empty results              -> advance to next (= empty != throttle)
//  3. Provider throws an error matching rate-limit markers (= rate-limit, 429,
//     quota exceeded, slow down, too many requests) -> advance to next
//  4. Provider throws any OTHER error             -> STOP and rethrow (= a
//                                                   malformed query fails everywhere;
//                                                   = don't silently round-robin)
//
//  Firecrawl removed (= empirically 403 without API key; = dropped from
//  wenshu ring per spec §"Backends").
//
//  KeylessRing is an `actor` (= Swift-native lock-free serialization)
//  because hermes uses `threading.Lock` around the cursor; = Swift's
//  actor provides the same per-app task-isolation guarantee.
//

import Foundation

actor KeylessRing {

    let providers: [any WebSearchProvider]

    init(providers: [any WebSearchProvider]) {
        self.providers = providers
    }

    /// The canonical wenshu vendor set, in failover order.
    static func defaultProviders() -> [any WebSearchProvider] {
        [
            ParallelKeylessProvider(),
            ExaKeylessProvider(),
            KeenableKeylessProvider(),
        ]
    }

    /// Default ring (= the canonical vendor set, in failover order).
    static func defaultRing() -> KeylessRing {
        KeylessRing(providers: defaultProviders())
    }

    enum RingError: Error, LocalizedError, Equatable {
        case allProvidersThrottled(attempted: [String], lastMessage: String)

        var errorDescription: String? {
            switch self {
            case .allProvidersThrottled(let attempted, let lastMessage):
                let list = attempted.joined(separator: ", ")
                return "All keyless search providers are rate-limited or unreachable (tried: \(list)). Last error: \(lastMessage)"
            }
        }
    }

    private static let rateLimitMarkers: [String] = [
        "rate limit", "rate-limit", "ratelimit",
        "too many requests", "429",
        "quota exceeded", "slow down"
    ]

    /// Heuristic: does this error message look like free-tier throttling?
    /// (= hermes `_is_rate_limitish`.)
    static func isRateLimitish(_ message: String) -> Bool {
        let lower = message.lowercased()
        return rateLimitMarkers.contains(where: lower.contains)
    }

    /// Walk the ring. Stops on first non-empty result set, or when every
    /// provider fails. Rate-limit-shaped errors advance to the next vendor;
    /// any other error stops the walk and rethrows (= malformed query, etc.).
    func search(query: String, limit: Int) async throws -> [WebSearchResult] {
        var lastMessage = "no providers configured"
        var attempted: [String] = []
        for provider in providers {
            attempted.append(provider.name)
            do {
                let results = try await provider.search(query: query, limit: limit)
                if !results.isEmpty {
                    return results
                }
                lastMessage = "provider '\(provider.name)' returned no results"
            } catch {
                let description = (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error)
                if Self.isRateLimitish(description) {
                    lastMessage = description
                    continue
                }
                throw error
            }
        }
        throw RingError.allProvidersThrottled(attempted: attempted, lastMessage: lastMessage)
    }
}