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

    @Test("RateLimitTracker: setLimit + currentBudget")
    func trackerSetAndFetch() async {
        let tracker = RateLimitTracker()
        let limit = ProviderRateLimit(
            providerSlug: "anthropic",
            requestsPerMinute: 60,
            tokensPerMinute: 100_000
        )
        await tracker.setLimit(limit)
        let budget = await tracker.currentBudget(providerSlug: "anthropic")
        #expect(budget != nil)
        #expect(budget?.providerSlug == "anthropic")
    }

    @Test("RateLimitTracker: currentBudget for unknown provider = nil")
    func trackerUnknownProvider() async {
        let tracker = RateLimitTracker()
        let budget = await tracker.currentBudget(providerSlug: "unknown")
        #expect(budget == nil)
    }

    @Test("RateLimitTracker: recordRequest updates count")
    func trackerRecordRequest() async {
        let tracker = RateLimitTracker()
        let limit = ProviderRateLimit(
            providerSlug: "openai",
            requestsPerMinute: 100,
            tokensPerMinute: 0
        )
        await tracker.setLimit(limit)
        await tracker.recordRequest(providerSlug: "openai")
        await tracker.recordRequest(providerSlug: "openai")
        let budget = await tracker.currentBudget(providerSlug: "openai")
        // requestsRemaining = 100 - 2 = 98
        #expect(budget?.requestsRemaining == 98)
    }

    @Test("RateLimitTracker: isExhausted when requestsRemaining == 0")
    func trackerExhausted() async {
        let tracker = RateLimitTracker()
        let limit = ProviderRateLimit(
            providerSlug: "anthropic",
            requestsPerMinute: 3,
            tokensPerMinute: 0
        )
        await tracker.setLimit(limit)
        for _ in 0..<3 {
            await tracker.recordRequest(providerSlug: "anthropic")
        }
        let budget = await tracker.currentBudget(providerSlug: "anthropic")
        #expect(budget?.isExhausted == true)
        #expect(budget?.requestsRemaining == 0)
    }

    @Test("RateLimitTracker: clear() removes all")
    func trackerClearAll() async {
        let tracker = RateLimitTracker()
        await tracker.setLimit(ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 60, tokensPerMinute: 100_000))
        await tracker.setLimit(ProviderRateLimit(providerSlug: "openai", requestsPerMinute: 100, tokensPerMinute: 0))
        await tracker.recordRequest(providerSlug: "anthropic")
        await tracker.clear()
        #expect(await tracker.currentBudget(providerSlug: "anthropic") == nil)
        #expect(await tracker.currentBudget(providerSlug: "openai") == nil)
    }

    @Test("RateLimitTracker: clear(providerSlug:) removes only that provider")
    func trackerClearOneProvider() async {
        let tracker = RateLimitTracker()
        await tracker.setLimit(ProviderRateLimit(providerSlug: "anthropic", requestsPerMinute: 60, tokensPerMinute: 0))
        await tracker.setLimit(ProviderRateLimit(providerSlug: "openai", requestsPerMinute: 100, tokensPerMinute: 0))
        await tracker.clear(providerSlug: "anthropic")
        #expect(await tracker.currentBudget(providerSlug: "anthropic") == nil)
        let openaiBudget = await tracker.currentBudget(providerSlug: "openai")
        #expect(openaiBudget != nil)
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

