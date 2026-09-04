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
        #expect(title == "what is the meaning of...")
    }
}