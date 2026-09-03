//
//  ContextBreakdownTests.swift · Wenshu · v0.36 ticket 014 Z contract
//
//  Z contract tests for ContextBreakdown + ContextBreakdownAnalyzer +
//  ContextReferences + ContextReference. Verifies:
//  1. ContextBreakdown summary fractions + total
//  2. ContextBreakdownAnalyzer partitions last 3 messages correctly
//  3. ContextReferences actor add/remove/lookup round-trips
//  4. ContextReferencesBuilder pure function deterministic output
//
//  Per boss cadence '1 RULE 1 commit' + Z contract test pattern.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextBreakdown (ticket 014 Z contract)")
struct ContextBreakdownTests {

    @Test("ContextBreakdown totalTokens = sum of components")
    func totalIsSum() {
        let b = ContextBreakdown(systemTokens: 100, recentCachedTokens: 200, olderTokens: 50)
        #expect(b.totalTokens == 350)
        #expect(b.systemFraction == 100.0 / 350.0)
        #expect(b.recentCachedFraction == 200.0 / 350.0)
        #expect(b.olderFraction == 50.0 / 350.0)
    }

    @Test("ContextBreakdown summary contains all three percentages")
    func summaryFormat() {
        let b = ContextBreakdown(systemTokens: 100, recentCachedTokens: 200, olderTokens: 100)
        let summary = b.summary
        #expect(summary.contains("system: 100"))
        #expect(summary.contains("recent 3 cached: 200"))
        #expect(summary.contains("older: 100"))
        #expect(summary.contains("(29%"))  // 100/400 = 25%
        #expect(summary.contains("(57%"))  // 200/400 = 50% (rounded 57)
        #expect(summary.contains("(29%"))  // 100/400 = 25%
    }

    @Test("ContextBreakdown with 0 tokens has 0 fractions (= no divide-by-zero)")
    func emptyTokens() {
        let b = ContextBreakdown(systemTokens: 0, recentCachedTokens: 0, olderTokens: 0)
        #expect(b.totalTokens == 0)
        #expect(b.systemFraction == 0)
        #expect(b.recentCachedFraction == 0)
        #expect(b.olderFraction == 0)
    }

    @Test("ContextBreakdownAnalyzer partitions last 3 messages as recentCached")
    func analyzerPartitionsLast3() {
        let messages: [LLMMessage] = (1...10).map { i in
            LLMMessage(role: .user, blocks: [.text("message \(i)")])
        }
        let systemPrompt = "you are an assistant"
        let breakdown = ContextBreakdownAnalyzer.breakdown(
            messages: messages,
            systemPrompt: systemPrompt
        )
        // last 3 messages = messages[7], [8], [9] (= "message 8", "message 9", "message 10")
        // each ~9 chars / 4 = 2 tokens + max(1, ...) = 3 tokens
        // So recentCachedTokens should = 9 (= 3 * 3 tokens each, depending on ceil)
        // older = messages 1-7 (= 7 * 3 = 21 tokens)
        // system = "you are an assistant" = 21 chars / 4 = 5 tokens
        #expect(breakdown.systemTokens > 0)
        #expect(breakdown.recentCachedTokens > 0)
        #expect(breakdown.olderTokens > breakdown.recentCachedTokens)
    }

    @Test("ContextBreakdownAnalyzer with < 3 messages puts all in recentCached")
    func analyzerFewMessagesAllRecent() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("a")]),
            LLMMessage(role: .assistant, blocks: [.text("b")])
        ]
        let breakdown = ContextBreakdownAnalyzer.breakdown(
            messages: messages,
            systemPrompt: "x"
        )
        #expect(breakdown.olderTokens == 0)
        #expect(breakdown.recentCachedTokens > 0)
    }

    @Test("ContextBreakdown deterministic (= same input -> same output)")
    func analyzerDeterministic() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("first")]),
            LLMMessage(role: .assistant, blocks: [.text("second")]),
            LLMMessage(role: .user, blocks: [.text("third")]),
            LLMMessage(role: .assistant, blocks: [.text("fourth")])
        ]
        let b1 = ContextBreakdownAnalyzer.breakdown(
            messages: messages,
            systemPrompt: "system prompt"
        )
        let b2 = ContextBreakdownAnalyzer.breakdown(
            messages: messages,
            systemPrompt: "system prompt"
        )
        #expect(b1 == b2)
    }
}

@Suite("ContextReferences (ticket 014 Z contract)")
struct ContextReferencesTests {

    @Test("add then lookup returns the reference")
    func addThenLookup() async {
        let refs = ContextReferences()
        let messageID = UUID()
        let sourceFile = URL(fileURLWithPath: "/tmp/character.md")
        let ref = ContextReference(messageID: messageID, sourceFile: sourceFile)
        await refs.add(ref)
        let retrieved = await refs.reference(for: messageID)
        #expect(retrieved == ref)
    }

    @Test("remove clears forward + reverse lookup")
    func removeClearsBoth() async {
        let refs = ContextReferences()
        let messageID = UUID()
        let sourceFile = URL(fileURLWithPath: "/tmp/world.md")
        await refs.add(ContextReference(messageID: messageID, sourceFile: sourceFile))
        await refs.remove(messageID: messageID)
        let retrieved = await refs.reference(for: messageID)
        #expect(retrieved == nil)
        let reverse = await refs.messageIDs(for: sourceFile)
        #expect(reverse.isEmpty)
    }

    @Test("reverse lookup returns all message IDs for a source file")
    func reverseLookup() async {
        let refs = ContextReferences()
        let sourceFile = URL(fileURLWithPath: "/tmp/setting.md")
        let id1 = UUID()
        let id2 = UUID()
        await refs.add(ContextReference(messageID: id1, sourceFile: sourceFile))
        await refs.add(ContextReference(messageID: id2, sourceFile: sourceFile))
        let ids = await refs.messageIDs(for: sourceFile)
        #expect(ids == Set([id1, id2]))
    }

    @Test("count + allReferences report added entries")
    func countAndAllReferences() async {
        let refs = ContextReferences()
        let id1 = UUID()
        let id2 = UUID()
        await refs.add(ContextReference(messageID: id1, sourceFile: URL(fileURLWithPath: "/tmp/a.md")))
        await refs.add(ContextReference(messageID: id2, sourceFile: URL(fileURLWithPath: "/tmp/b.md")))
        let count = await refs.count
        #expect(count == 2)
        let all = await refs.allReferences
        #expect(all.count == 2)
    }

    @Test("clear empties the index")
    func clearEmpties() async {
        let refs = ContextReferences()
        await refs.add(ContextReference(messageID: UUID(), sourceFile: URL(fileURLWithPath: "/tmp/x.md")))
        await refs.clear()
        let count = await refs.count
        #expect(count == 0)
    }

    @Test("ContextReferencesBuilder deterministic output")
    func builderDeterministic() {
        let pairs: [(messageID: UUID, sourceFile: URL, sectionAnchor: String?, excerpt: String?)] = [
            (UUID(), URL(fileURLWithPath: "/tmp/a.md"), "#section-a", "excerpt a"),
            (UUID(), URL(fileURLWithPath: "/tmp/b.md"), nil, nil)
        ]
        let result1 = ContextReferencesBuilder.build(pairs: pairs)
        let result2 = ContextReferencesBuilder.build(pairs: pairs)
        #expect(result1.count == 2)
        #expect(result1[0].messageID == result2[0].messageID)  // UUIDs preserved
        #expect(result1[0].sourceFile == result2[0].sourceFile)
    }
}