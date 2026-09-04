//
//  RateLimitAndContextBreakdownTests.swift · Wenshu · v0.38 Batch 3 sub-step 3
//
//  Tests for RateLimitTracker + ContextBreakdown + ContextReferences
//  (= v0.36 ticket 015 + 014).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
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

@Suite("ContextBreakdown + ContextReferences (= v0.36 ticket 014)")
struct ContextBreakdownDeepTests {

    @Test("ContextBreakdownAnalyzer.breakdown: 4 messages produces breakdown")
    func contextBreakdown4Messages() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("msg 1")]),
            LLMMessage(role: .assistant, blocks: [.text("reply 1")]),
            LLMMessage(role: .user, blocks: [.text("msg 2")]),
            LLMMessage(role: .assistant, blocks: [.text("reply 2")])
        ]
        let breakdown = ContextBreakdownAnalyzer.breakdown(
            messages: messages,
            systemPrompt: "you are a helpful assistant"
        )
        // System prompt + 4 messages = some token count
        #expect(breakdown.totalTokens > 0)
        // 4 messages, cachedBreakpointsCount default = 3
        // So: systemTokens from prompt + recentTokens from last 3 + olderTokens from msg 1
        #expect(breakdown.recentCachedTokens >= 0)
        #expect(breakdown.olderTokens >= 0)
    }

    @Test("ContextBreakdownAnalyzer.breakdown: empty messages still works")
    func contextBreakdownEmpty() {
        let breakdown = ContextBreakdownAnalyzer.breakdown(
            messages: [],
            systemPrompt: "system"
        )
        #expect(breakdown.totalTokens >= 1)  // system prompt at least
        #expect(breakdown.recentCachedTokens == 0)
        #expect(breakdown.olderTokens == 0)
    }

    @Test("ContextBreakdown: systemFraction + recentCachedFraction")
    func contextBreakdownFractions() {
        let breakdown = ContextBreakdown(
            systemTokens: 100,
            recentCachedTokens: 50,
            olderTokens: 50
        )
        #expect(breakdown.systemFraction == 0.5)
        #expect(breakdown.recentCachedFraction == 0.25)
        #expect(breakdown.olderFraction == 0.25)
    }

    @Test("ContextBreakdown: summary format")
    func contextBreakdownSummary() {
        let breakdown = ContextBreakdown(
            systemTokens: 100,
            recentCachedTokens: 50,
            olderTokens: 50
        )
        let summary = breakdown.summary
        #expect(summary.contains("system"))
        #expect(summary.contains("recent 3"))
        #expect(summary.contains("older"))
    }

    @Test("ContextBreakdown: Codable round-trip")
    func contextBreakdownCodable() throws {
        let breakdown = ContextBreakdown(
            systemTokens: 100,
            recentCachedTokens: 50,
            olderTokens: 50
        )
        let encoded = try JSONEncoder().encode(breakdown)
        let decoded = try JSONDecoder().decode(ContextBreakdown.self, from: encoded)
        #expect(decoded == breakdown)
    }

    @Test("ContextReferences: add + reference(for:)")
    func contextReferencesAddLookup() async {
        let store = ContextReferences()
        let ref = ContextReference(
            messageID: UUID(),
            sourceFile: URL(fileURLWithPath: "/book/world.md"),
            excerpt: "Alice backstory"
        )
        await store.add(ref)
        let found = await store.reference(for: ref.messageID)
        #expect(found?.messageID == ref.messageID)
        #expect(found?.sourceFile == ref.sourceFile)
    }

    @Test("ContextReferences: messageIDs(for: sourceFile)")
    func contextReferencesMessageIDsForFile() async {
        let store = ContextReferences()
        let url = URL(fileURLWithPath: "/book/world.md")
        let ref1 = ContextReference(messageID: UUID(), sourceFile: url)
        let ref2 = ContextReference(messageID: UUID(), sourceFile: url)
        await store.add(ref1)
        await store.add(ref2)
        let ids = await store.messageIDs(for: url)
        #expect(ids.count == 2)
        #expect(ids.contains(ref1.messageID))
        #expect(ids.contains(ref2.messageID))
    }

    @Test("ContextReferences: remove(messageID:)")
    func contextReferencesRemove() async {
        let store = ContextReferences()
        let ref = ContextReference(
            messageID: UUID(),
            sourceFile: URL(fileURLWithPath: "/book/test.md")
        )
        await store.add(ref)
        await store.remove(messageID: ref.messageID)
        let found = await store.reference(for: ref.messageID)
        #expect(found == nil)
    }

    @Test("ContextReferences: count + allReferences")
    func contextReferencesCountAndAll() async {
        let store = ContextReferences()
        let url = URL(fileURLWithPath: "/book/x.md")
        await store.add(ContextReference(messageID: UUID(), sourceFile: url))
        await store.add(ContextReference(messageID: UUID(), sourceFile: url))
        let count = await store.count
        #expect(count == 2)
        let all = await store.allReferences
        #expect(all.count == 2)
    }

    @Test("ContextReferences: clear removes all")
    func contextReferencesClear() async {
        let store = ContextReferences()
        let url = URL(fileURLWithPath: "/a.md")
        await store.add(ContextReference(messageID: UUID(), sourceFile: url))
        await store.add(ContextReference(messageID: UUID(), sourceFile: url))
        await store.clear()
        #expect(await store.count == 0)
    }

    @Test("ContextReference: Codable round-trip")
    func contextReferenceCodable() throws {
        let ref = ContextReference(
            messageID: UUID(),
            sourceFile: URL(fileURLWithPath: "/book/world.md"),
            sectionAnchor: "chapter-1",
            excerpt: "Alice is the protagonist"
        )
        let encoded = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(ContextReference.self, from: encoded)
        #expect(decoded.messageID == ref.messageID)
        #expect(decoded.sourceFile == ref.sourceFile)
        #expect(decoded.sectionAnchor == "chapter-1")
        #expect(decoded.excerpt == "Alice is the protagonist")
    }
}
