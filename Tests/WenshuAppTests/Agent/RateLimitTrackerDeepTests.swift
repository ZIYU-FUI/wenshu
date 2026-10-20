//
//  RateLimitAndContextBreakdownTests.swift · Wenshu · v0.38 Batch 3 sub-step 3
//
//  Tests for RateLimitTracker + ContextBreakdown + ContextReferences
//  (= v0.36 ticket 015 + 014).
//
// Per cadence 2026-09-03 'resume' (= auto-pilot mode
// per 'ok' + ') + 'PO execute,
// don't' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = RateLimitTracker + ContextBreakdown
//  + ContextReferences are v0.36 ticket 015/014 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("RateLimitTracker deep (= v0.36 ticket 015)")
struct RateLimitTrackerDeepTests {

    @Test("ProviderRateLimit: construction with all fields")
    func rateLimitConstruction() {
        let limit = ProviderRateLimit(
            providerSlug: "anthropic",
            requestsPerMinute: 60,
            tokensPerMinute: 100_000
        )
        #expect(limit.providerSlug == "anthropic")
        #expect(limit.requestsPerMinute == 60)
        #expect(limit.tokensPerMinute == 100_000)
    }

    @Test("ProviderRateLimit: Codable round-trip")
    func rateLimitCodable() throws {
        let limit = ProviderRateLimit(
            providerSlug: "openai",
            requestsPerMinute: 500,
            tokensPerMinute: 200_000
        )
        let encoded = try JSONEncoder().encode(limit)
        let decoded = try JSONDecoder().decode(ProviderRateLimit.self, from: encoded)
        #expect(decoded == limit)
    }

    @Test("RateLimitBudget: Equatable")
    func budgetEquatable() {
        let a = RateLimitBudget(
            providerSlug: "anthropic",
            requestsRemaining: 50,
            tokensRemaining: 80_000,
            isExhausted: false
        )
        let b = RateLimitBudget(
            providerSlug: "anthropic",
            requestsRemaining: 50,
            tokensRemaining: 80_000,
            isExhausted: false
        )
        #expect(a == b)
    }
}
