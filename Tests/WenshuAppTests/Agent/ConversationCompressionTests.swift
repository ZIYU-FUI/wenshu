//
//  ConversationCompressionTests.swift · Wenshu · v0.35 ticket 003 sub-step 2
//
//  Unit tests for ConversationCompression (= thin wrapper around
//  ContextCompressor).
//
//  Test surface:
//  1. historyAfterCompression delegates to ContextCompressor (= same return shape)
//  2. No-op case (= returns original messages unchanged)
//  3. Compress case (= returns compressed messages)
//  4. manualTrigger forces compression even when budget allows
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ConversationCompression (ticket 003 sub-step 2)")
struct ConversationCompressionTests {

    @Test("historyAfterCompression delegates to ContextCompressor (= no-op case)")
    func testHistoryAfterCompressionNoOp() async {
        let cc = ConversationCompression()
        let messages: [LLMMessage] = (1...3).map { LLMMessage.user("msg \($0)") }

        let result = await cc.historyAfterCompression(messages: messages, systemMessage: "sys")
        #expect(result.messages.count == 3)
        #expect(result.systemMessage == "sys")
    }

    @Test("historyAfterCompression delegates to ContextCompressor (= compress case)")
    func testHistoryAfterCompressionCompress() async {
        let aggressiveCompressor = ContextCompressor(
            policy: ContextCompressor.Policy(keepRecentTurns: 2, maxTokens: 10)
        )
        let cc = ConversationCompression(compressor: aggressiveCompressor)
        let messages: [LLMMessage] = (1...10).map { LLMMessage.user("msg \($0)") }

        let result = await cc.historyAfterCompression(messages: messages, systemMessage: "sys")
        #expect(result.messages.count < messages.count)  // compressed
    }

    @Test("manualTrigger forces compression even when budget allows")
    func testManualTriggerForcesCompression() async {
        let cc = ConversationCompression()
        let messages: [LLMMessage] = (1...10).map { LLMMessage.user("msg \($0)") }

        // Without manual trigger, no compression would happen (= within budget)
        let passive = await cc.historyAfterCompression(messages: messages, systemMessage: "sys")
        #expect(passive.messages.count == 10)

        // With manual trigger, compression IS forced
        let active = await cc.manualTrigger(messages: messages, systemMessage: "sys")
        #expect(active.messages.count < messages.count)
    }

    @Test("System message preserved byte-stable across both methods")
    func testSystemMessageStable() async {
        let cc = ConversationCompression()
        let systemMessage = "stable prompt 2026-09-03"
        let messages: [LLMMessage] = (1...20).map { LLMMessage.user("msg \($0)") }

        let passive = await cc.historyAfterCompression(messages: messages, systemMessage: systemMessage)
        let active = await cc.manualTrigger(messages: messages, systemMessage: systemMessage)

        #expect(passive.systemMessage == systemMessage)
        #expect(active.systemMessage == systemMessage)
    }
}