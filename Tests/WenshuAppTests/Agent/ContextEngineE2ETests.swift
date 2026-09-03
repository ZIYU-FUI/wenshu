//
//  ContextEngineE2ETests.swift · Wenshu · v0.35 ticket 003 sub-step 6
//
//  End-to-end integration test for ticket 003 stack:
//  ContextCompressor + ConversationCompression + ContextEngine
//
//  Verifies:
//    1. ConversationCompression.manualTrigger end-to-end returns compressed
//       history when budget is exceeded
//    2. System prompt bytes stable across 50 compression cycles
//       (= AGENTS.md §11.3 invariant)
//    3. Compressed history preserves the most recent N turns verbatim
//    4. ContextEngine + ContextCompressor compose correctly
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ContextEngine e2e (ticket 003 sub-step 6)")
struct ContextEngineE2ETests {

    @Test("End-to-end manual trigger compresses a long conversation history")
    func testManualTriggerE2E() async {
        let cc = ConversationCompression()
        let messages: [LLMMessage] = (1...50).map { i in
            i.isMultiple(of: 2)
                ? LLMMessage.user("long message number \(i) with some content")
                : LLMMessage.assistant("response number \(i) with more content")
        }

        let result = await cc.manualTrigger(messages: messages, systemMessage: "stable system")

        // Compression happened (= fewer messages than input)
        #expect(result.messages.count < messages.count)
        // Last message preserved verbatim
        #expect(result.messages.last?.plainText == messages.last?.plainText)
    }

    @Test("System prompt bytes stable across 50 compression cycles")
    func testSystemPromptByteStabilityAcrossCycles() async {
        let cc = ConversationCompression()
        let systemPrompt = "you are 文枢 writing assistant; timestamp 2026-09-03"
        let baseMessages: [LLMMessage] = (1...20).map { LLMMessage.user("msg \($0)") }

        var results: [String] = []
        for _ in 0..<50 {
            let result = await cc.manualTrigger(messages: baseMessages, systemMessage: systemPrompt)
            results.append(result.systemMessage)
        }

        // All 50 results have identical system message bytes
        let first = results[0]
        for (i, r) in results.enumerated() {
            #expect(r == first, "system message at cycle \(i) differs")
            let firstBytes = Data(first.utf8)
            let rBytes = Data(r.utf8)
            #expect(firstBytes == rBytes)
        }
    }

    @Test("Compressed history preserves most recent N turns verbatim")
    func testRecentTurnsPreserved() async {
        let aggressiveCompressor = ContextCompressor(
            policy: ContextCompressor.Policy(keepRecentTurns: 4, maxTokens: 10)
        )
        let cc = ConversationCompression(compressor: aggressiveCompressor)
        let messages: [LLMMessage] = (1...20).map { i in
            i.isMultiple(of: 2)
                ? LLMMessage.user("msg \(i)")
                : LLMMessage.assistant("reply \(i)")
        }

        let result = await cc.historyAfterCompression(messages: messages, systemMessage: "sys")

        // Last 4 messages (= 2 turns of user+assistant) preserved
        #expect(result.messages.count == 5)  // 1 summary + 4 recent
        #expect(result.messages[1].plainText == "msg 17")
        #expect(result.messages[4].plainText == "reply 20")
    }

    @Test("ContextEngine + ContextCompressor compose (= system prompt dynamic tier injection)")
    func testContextEngineComposesWithCompressor() async {
        // 1. Aggregate context (= empty in sub-step 3, but API exists)
        let engine = ContextEngine()
        let bundle = await engine.aggregateContextForTurn(bookId: nil, userMessage: "test")
        #expect(bundle.isEmpty)

        // 2. Format = empty string (= no system-prompt dynamic tier)
        let formatted = await engine.formatContextBundle(bundle)
        #expect(formatted.isEmpty)

        // 3. Compressor sees no dynamic tier (= system prompt unchanged)
        let compressor = ContextCompressor(policy: ContextCompressor.Policy(maxTokens: 10))
        let messages: [LLMMessage] = (1...20).map { LLMMessage.user("msg \($0)") }
        let result = await compressor.compressContext(messages: messages, systemMessage: formatted)
        #expect(result.systemMessage.isEmpty)
    }
}