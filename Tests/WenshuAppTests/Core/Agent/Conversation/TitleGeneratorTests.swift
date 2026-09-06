//
//  TitleGeneratorTests.swift · Wenshu · HERMES-INTERNAL-008 (2026-09-04)
//
//  Round-trip tests for TitleGenerator (= hermes title_generator.py port).
//
//  Tests covered:
//    1. testHeuristicTitle_short             — short text returned verbatim
//    2. testHeuristicTitle_longTruncates     — long text → first 6 words + ...
//    3. testLLMTitle_optional                — connector called + title returned
//    4. testLLMTitle_nilFallsBackToHeuristic — nil connector → heuristic
//

import Testing
import Foundation
@testable import WenshuApp

// MARK: - Stub connector

struct StubTitleConnector: LLMConnector {
    let connectorID = "stub-title"
    let responseText: String

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        return LLMResponse(
            id: "stub",
            model: "stub-model",
            blocks: [.text(responseText)],
            stopReason: .endTurn,
            usage: .init(inputTokens: 0, outputTokens: 0)
        )
    }
}

// MARK: - Suite

@Suite("TitleGenerator (HERMES-INTERNAL-008)")
struct TitleGeneratorTests {

    @Test("heuristicTitle returns short input verbatim")
    func testHeuristicTitle_short() {
        let title = TitleGenerator.heuristicTitle(from: "Hello world")
        #expect(title == "Hello world")
    }

    @Test("heuristicTitle truncates long input to first 6 words + ellipsis")
    func testHeuristicTitle_longTruncates() {
        let long = "one two three four five six seven eight nine ten"
        let title = TitleGenerator.heuristicTitle(from: long)
        #expect(title == "one two three four five six...")
    }

    @Test("llmTitle routes through LLMConnector when supplied")
    func testLLMTitle_optional() async throws {
        let connector = StubTitleConnector(responseText: "Cooking Adventures")
        let title = try await TitleGenerator.llmTitle(
            from: "tell me about cooking",
            connector: connector
        )
        #expect(title == "Cooking Adventures")
    }

    @Test("llmTitle with nil connector falls back to heuristic title")
    func testLLMTitle_nilFallsBackToHeuristic() async throws {
        let title = try await TitleGenerator.llmTitle(
            from: "what is the meaning of life and everything else",
            connector: nil
        )
        // Heuristic title contract (TitleGenerator.swift:9 + :19 + :29-30):
        // first 6 words + ellipsis when input exceeds 6 words. Same file's
        // testHeuristicTitle_longTruncates (L45-L50) asserts this exact
        // contract. Hermes title_generator.py:104-105 only caps at >80 chars
        // and does NOT word-truncate, so wenshu's 6-word cap is a wenshu-side
        // contract documented in production and re-asserted by the sibling
        // test. The prior assertion of "what is the meaning of..." (4 words)
        // contradicted both production and the file's own other test.
        //
        // Input word count: 9 ("what is the meaning of life and everything
        // else"). First 6 words = "what is the meaning of life" (note: "of"
        // is short, so the title looks like 5 words but is actually 6).
        #expect(title == "what is the meaning of life...")
    }
}