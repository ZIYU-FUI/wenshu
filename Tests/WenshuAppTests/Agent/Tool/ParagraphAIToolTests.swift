//
//  ParagraphAIToolTests.swift · Wenshu · P0 #2 (WIRE-AGENT-002)
//
//  Unit-level tests for the ParagraphAITool stub. Verifies the
//  stub contract that the P3 ticket #15 follow-up will replace with
//  the real hermes port of `agent/editing/paragraph_ai.py`:
//
//    1. testParagraphAI_stubReturnsCannedExpansion
//       (= non-empty output, mode echoed, input text preserved)
//
//  Acceptance: `--filter "ParagraphAITool"` = 1/1 pass.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ParagraphAITool stub (P0 #2 / WIRE-AGENT-002)")
struct ParagraphAIToolTests {

    @Test("ParagraphAITool stub returns canned expansion for a valid JSON input")
    func testParagraphAI_stubReturnsCannedExpansion() async throws {
        let tool = ParagraphAITool.shared
        let output = try await tool.execute(input: "{\"text\":\"hello world\",\"mode\":\"expand\"}")
        #expect(!output.isEmpty, "stub must produce non-empty output for valid input")
        #expect(output.contains("hello world"), "stub must echo the input text in the expansion frame")
        #expect(output.contains("expand"), "stub must echo the mode in the expansion frame")
    }
}