//
//  ContextEngineAndCompressorTests.swift · Wenshu · v0.38 Batch 3 sub-step 7
//
//  Tests for ContextEngine + ContextCompressor + ConversationCompression
//  (= v0.35 ticket 003).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = ContextEngine + ContextCompressor
//  + ConversationCompression are v0.35 ticket 003 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextEngine + ContextCompressor deep (= v0.35 ticket 003)")
struct ContextEngineAndCompressorDeepTests {

    // MARK: - ContextEngine

    @Test("ContextEngine.aggregateContextForTurn: returns empty bundle by default")
    func aggregateEmptyBundle() async {
        let engine = ContextEngine()
        let bundle = await engine.aggregateContextForTurn(
            bookId: "book-1",
            userMessage: "Tell me about Alice"
        )
        #expect(bundle.isEmpty)
    }

    @Test("ContextEngine.formatContextBundle: empty bundle returns empty string")
    func formatEmptyBundle() async {
        let engine = ContextEngine()
        let bundle = await engine.aggregateContextForTurn(
            bookId: nil,
            userMessage: "test"
        )
        let formatted = await await engine.formatContextBundle(bundle)
        #expect(formatted.isEmpty)
    }

    @Test("ContextEngine.formatContextBundle: renders memories section")
    func formatMemoriesSection() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [
                ContextEngine.MemoryEntry(source: "/book/world.md", snippet: "Alice backstory")
            ],
            characterContext: [],
            worldContext: [],
            foreshadowContext: []
        )
        // formatContextBundle is non-async
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("Relevant memories"))
        #expect(formatted.contains("Alice backstory"))
        #expect(formatted.contains("/book/world.md"))
    }

    @Test("ContextEngine.formatContextBundle: renders characters section")
    func formatCharactersSection() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: ["Alice: protagonist", "Bob: antagonist"],
            worldContext: [],
            foreshadowContext: []
        )
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("Characters"))
        #expect(formatted.contains("Alice: protagonist"))
        #expect(formatted.contains("Bob: antagonist"))
    }

    @Test("ContextEngine.formatContextBundle: renders world section")
    func formatWorldSection() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: [],
            worldContext: ["Magic system: ley lines"],
            foreshadowContext: []
        )
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("World"))
        #expect(formatted.contains("ley lines"))
    }

    @Test("ContextEngine.formatContextBundle: renders foreshadow section")
    func formatForeshadowSection() async {
        let engine = ContextEngine()
        let bundle = ContextEngine.ContextBundle(
            memories: [],
            characterContext: [],
            worldContext: [],
            foreshadowContext: ["Alice will betray Bob in chapter 5"]
        )
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.contains("Foreshadowing"))
        #expect(formatted.contains("Alice will betray Bob"))
    }

    @Test("ContextEngine.MemoryEntry: construction")
    func memoryEntryConstruction() {
        let entry = ContextEngine.MemoryEntry(source: "/a.md", snippet: "x")
        #expect(entry.source == "/a.md")
        #expect(entry.snippet == "x")
    }

    // MARK: - ContextCompressor

    @Test("ContextCompressor.Policy: defaults")
    func compressorPolicyDefaults() {
        let policy = ContextCompressor.Policy()
        #expect(policy.keepRecentTurns == 8)
        #expect(policy.maxTokens == 30_000)
    }

    @Test("ContextCompressor.Policy: custom values")
    func compressorPolicyCustom() {
        let policy = ContextCompressor.Policy(keepRecentTurns: 4, maxTokens: 10_000)
        #expect(policy.keepRecentTurns == 4)
        #expect(policy.maxTokens == 10_000)
    }

    @Test("ContextCompressor.compressContext: small history = no compression")
    func compressorSmallHistory() async {
        let compressor = ContextCompressor(policy: .init(keepRecentTurns: 10))
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")]),
            LLMMessage(role: .assistant, blocks: [.text("hello")])
        ]
        let (result, _) = await compressor.compressContext(
            messages: messages,
            systemMessage: "system"
        )
        // No compression = same messages returned
        #expect(result.count == 2)
    }

    @Test("ContextCompressor.compressContext: large history compresses")
    func compressorLargeHistory() async {
        let policy = ContextCompressor.Policy(keepRecentTurns: 2, maxTokens: 50)
        let compressor = ContextCompressor(policy: policy)
        let messages: [LLMMessage] = (1...20).map { i in
            LLMMessage(role: .user, blocks: [.text("msg \(i) is a fairly long message that should consume tokens")])
        }
        let (result, _) = await compressor.compressContext(
            messages: messages,
            systemMessage: "system"
        )
        // 20 messages should be compressed to <= keepRecentTurns + 1 summary
        #expect(result.count <= policy.keepRecentTurns + 1)
    }

    @Test("ContextCompressor.compressContext: system message preserved unchanged")
    func compressorSystemMessagePreserved() async {
        let compressor = ContextCompressor()
        let originalSystem = "important system prompt that should not change"
        let messages: [LLMMessage] = (1...50).map { i in
            LLMMessage(role: .user, blocks: [.text("msg \(i)")])
        }
        let (_, resultSystem) = await compressor.compressContext(
            messages: messages,
            systemMessage: originalSystem
        )
        #expect(resultSystem == originalSystem)
    }

    @Test("ContextCompressor.estimate: returns positive tokens (= via CharacterBasedTokenEstimator)")
    func compressorEstimate() {
        let estimator = CharacterBasedTokenEstimator()
        let message = LLMMessage(role: .user, blocks: [.text("Hello world this is a test")])
        let tokens = estimator.estimate(message)
        #expect(tokens > 0)
    }

    // MARK: - CharacterBasedTokenEstimator (= in ContextCompressor.swift)

    @Test("CharacterBasedTokenEstimator: 4 chars per token heuristic")
    func charBasedEstimator() {
        let estimator = CharacterBasedTokenEstimator()
        let message = LLMMessage(role: .user, blocks: [.text("12345678")])  // 8 chars
        let tokens = estimator.estimate(message)
        #expect(tokens == 2)  // 8 / 4 = 2
    }

    @Test("CharacterBasedTokenEstimator: empty message = 1 token min")
    func charBasedEstimatorEmpty() {
        let estimator = CharacterBasedTokenEstimator()
        let message = LLMMessage(role: .user, blocks: [.text("")])
        let tokens = estimator.estimate(message)
        #expect(tokens == 1)  // max(1, 0/4) = 1
    }

    @Test("CharacterBasedTokenEstimator: thinking block counts text chars")
    func charBasedEstimatorThinking() {
        let estimator = CharacterBasedTokenEstimator()
        let message = LLMMessage(role: .assistant, blocks: [
            .thinking(text: "12345678", signature: nil)
        ])
        let tokens = estimator.estimate(message)
        #expect(tokens == 2)  // 8 / 4 = 2
    }

    // MARK: - ConversationCompression

    @Test("ConversationCompression.historyAfterCompression: small history unchanged")
    func conversationCompressionSmall() async {
        let compressor = ConversationCompression(
            compressor: ContextCompressor(policy: .init(keepRecentTurns: 10))
        )
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")])
        ]
        let result = await compressor.historyAfterCompression(
            messages: messages,
            systemMessage: "system"
        )
        // 1 message + 1 system = 2 total
        #expect(result.messages.count == 1)
        #expect(result.systemMessage == "system")
    }

    @Test("ConversationCompression.manualTrigger: returns compression result")
    func conversationCompressionManualTrigger() async {
        let compressor = ConversationCompression(
            compressor: ContextCompressor(policy: .init(keepRecentTurns: 2, maxTokens: 50))
        )
        let messages: [LLMMessage] = (1...10).map { i in
            LLMMessage(role: .user, blocks: [.text("msg \(i) is a longer message")])
        }
        let result = await compressor.manualTrigger(
            messages: messages,
            systemMessage: "system"
        )
        // Should produce a compression result
        #expect(result.messages.count <= 10)
    }
}
