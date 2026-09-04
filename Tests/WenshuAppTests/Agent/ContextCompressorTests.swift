//
//  ContextCompressorTests.swift · Wenshu · v0.35 ticket 003 sub-step 1
//
//  Unit tests for ContextCompressor (= hermes-core-translation
//  spec §3.6 + §0.1 + AGENTS.md §11.3 cache-stable invariant).
//
//  Tests verify the deterministic compression policy:
//    - No-op when message count <= keepRecentTurns
//    - No-op when estimated tokens <= maxTokens
//    - Compresses older messages into a single summary block
//    - Preserves recent messages verbatim
//    - Returns tuple matching hermes compress_context() return shape
//    - System message unchanged (= byte-stable invariant)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextCompressor (ticket 003 sub-step 1)")
struct ContextCompressorTests {

    // MARK: - Test 1: No-op when messages already fit

    @Test("No-op when message count <= keepRecentTurns")
    func testNoOpFewMessages() async {
        let compressor = ContextCompressor(policy: ContextCompressor.Policy(keepRecentTurns: 4))
        let messages: [LLMMessage] = (1...3).map { LLMMessage.user("msg \($0)") }

        let result = await compressor.compressContext(messages: messages, systemMessage: "sys")
        #expect(result.messages.count == 3)
        #expect(result.systemMessage == "sys")
    }

    // MARK: - Test 2: No-op when within budget

    @Test("No-op when estimated tokens <= maxTokens")
    func testNoOpWithinBudget() async {
        let compressor = ContextCompressor(policy: ContextCompressor.Policy(maxTokens: 10_000))
        let messages: [LLMMessage] = (1...5).map { LLMMessage.user("short msg \($0)") }

        let result = await compressor.compressContext(messages: messages, systemMessage: "sys")
        #expect(result.messages.count == 5)
    }

    // MARK: - Test 3: Compress when over budget

    @Test("Compresses older messages into a single summary block")
    func testCompressOverBudget() async {
        // Force compression: keepRecentTurns = 2 + maxTokens = 10 (= too low for any real text)
        let compressor = ContextCompressor(
            policy: ContextCompressor.Policy(keepRecentTurns: 2, maxTokens: 10)
        )
        let messages: [LLMMessage] = (1...10).map { LLMMessage.user("msg \($0)") }

        let result = await compressor.compressContext(messages: messages, systemMessage: "sys")

        // 1 summary + 2 recent = 3 messages
        #expect(result.messages.count == 3)
        // First message is the summary
        #expect(result.messages[0].role == .assistant)
        if case .text(let s) = result.messages[0].blocks[0] {
            #expect(s.contains("8 turns omitted"))
        } else {
            Issue.record("expected text block in summary message")
        }
    }

    // MARK: - Test 4: Recent messages preserved verbatim

    @Test("Recent messages preserved verbatim (= last keepRecentTurns)")
    func testRecentMessagesPreserved() async {
        let compressor = ContextCompressor(
            policy: ContextCompressor.Policy(keepRecentTurns: 2, maxTokens: 10)
        )
        let messages: [LLMMessage] = (1...5).map { LLMMessage.user("msg \($0)") }

        let result = await compressor.compressContext(messages: messages, systemMessage: "sys")
        // Last 2 messages preserved (= "msg 4", "msg 5")
        #expect(result.messages[1].plainText == "msg 4")
        #expect(result.messages[2].plainText == "msg 5")
    }

    // MARK: - Test 5: System message preserved (byte-stable invariant)

    @Test("System message preserved byte-stable (= AGENTS.md §11.3 invariant)")
    func testSystemMessagePreserved() async {
        let compressor = ContextCompressor(policy: ContextCompressor.Policy(maxTokens: 10))
        let systemPrompt = "you are a stable prompt with timestamp 2026-09-03"

        let messages: [LLMMessage] = (1...20).map { LLMMessage.user("msg \($0)") }
        let result = await compressor.compressContext(messages: messages, systemMessage: systemPrompt)

        #expect(result.systemMessage == systemPrompt)
        let originalBytes = Data(systemPrompt.utf8)
        let returnedBytes = Data(result.systemMessage.utf8)
        #expect(originalBytes == returnedBytes)
    }

    // MARK: - Test 6: Custom summary template

    @Test("Custom summary template is honored")
    func testCustomSummaryTemplate() async {
        let customTemplate = "Compressed: skipped %d older turns"
        let compressor = ContextCompressor(
            policy: ContextCompressor.Policy(
                keepRecentTurns: 1,
                maxTokens: 5,
                summaryTemplate: customTemplate
            )
        )
        let messages: [LLMMessage] = (1...10).map { LLMMessage.user("msg \($0)") }

        let result = await compressor.compressContext(messages: messages, systemMessage: "sys")
        if case .text(let s) = result.messages[0].blocks[0] {
            #expect(s == "Compressed: skipped 9 older turns")
        } else {
            Issue.record("expected custom template text")
        }
    }

    // MARK: - Test 7: CharacterBasedTokenEstimator

    @Test("CharacterBasedTokenEstimator divides char count by 4")
    func testTokenEstimator() {
        let estimator = CharacterBasedTokenEstimator()
        let msg = LLMMessage.user("hello world")  // 11 chars → ~2 tokens
        let estimate = estimator.estimate(msg)
        #expect(estimate == 2 || estimate == 3)  // rounding tolerance
    }
}