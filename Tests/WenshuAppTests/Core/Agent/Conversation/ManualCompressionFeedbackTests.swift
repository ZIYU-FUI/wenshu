//
//  ManualCompressionFeedbackTests.swift · Wenshu · HERMES-INTERNAL-007 (2026-09-04)
//
//  Round-trip tests for ManualCompressionFeedback (= hermes
//  manual_compression_feedback.py port).
//
//  Tests covered:
//    1. testTriggerManualCompression_customPrompt — custom prompt influences outcome
//    2. testTriggerManualCompression_default       — default path returns feedback
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ManualCompressionFeedback (HERMES-INTERNAL-007)")
struct ManualCompressionFeedbackTests {

    @Test("manual trigger with a custom prompt returns feedback + augmented system")
    func testTriggerManualCompression_customPrompt() async throws {
        let compressor = ContextCompressor()
        let compression = ConversationCompression(compressor: compressor)
        let runner = ManualCompressionFeedbackRunner(compression: compression)

        let messages: [LLMMessage] = []
        let system = "base system"

        let result = try await runner.triggerManualCompression(
            messages: messages,
            systemMessage: system,
            customPrompt: "summarise aggressively"
        )
        #expect(result.feedback.headline.contains("No changes") || result.feedback.headline.contains("Compressed"))
        #expect(result.feedback.tokenLine.contains("tokens"))
        #expect(result.systemMessage.contains("summarise aggressively"))
    }

    @Test("manual trigger without a custom prompt leaves system unchanged")
    func testTriggerManualCompression_default() async throws {
        let compressor = ContextCompressor()
        let compression = ConversationCompression(compressor: compressor)
        let runner = ManualCompressionFeedbackRunner(compression: compression)

        let messages: [LLMMessage] = []
        let system = "base system"

        let result = try await runner.triggerManualCompression(
            messages: messages,
            systemMessage: system,
            customPrompt: nil
        )
        #expect(result.systemMessage == system)
    }
}