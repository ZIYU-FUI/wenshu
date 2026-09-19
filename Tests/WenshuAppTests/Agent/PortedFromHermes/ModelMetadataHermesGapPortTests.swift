//
//  ModelMetadataHermesGapPortTests.swift · Wenshu · H7-CHAT-COMPLETION-HELPERS-HERMES-PORT (2026-09-19)
//
//  Verifies the 1 new hermes port addition to
//  `Core/Agent/Connector/ModelMetadata.swift` (= hermes
//  `agent/chat_completion_helpers.py`).
//
//  Hermes pure helper ported:
//    - estimateRequestContextTokens(_:) (= hermes
//      `estimate_request_context_tokens` at L66-L117)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure-function port; = no
//  interruptible_api_call / build_api_kwargs / try_activate_fallback
//  (= those live in ConversationLoop per the wenshu-side-wins
//  pattern; = per Q112 = one ticket per file = the remaining 14
//  hermes functions deferred).

import XCTest
@testable import WenshuApp

final class ModelMetadataHermesGapPortTests: XCTestCase {

    // MARK: -- H7.1 estimateRequestContextTokens tests (= hermes L66-L117)

    func testEstimateRequestContextTokens_bareList_treatsAsMessages() {
        let messages: [Any] = ["hello world", "foo bar baz"]
        // 11 + 11 = 22 chars, /4 = 5 tokens
        let result = WenshuModelCatalog.estimateRequestContextTokens(messages)
        XCTAssertEqual(result, 5)
    }

    func testEstimateRequestContextTokens_chatCompletionsDictWithMessages() {
        let payload: [String: Any] = [
            "messages": ["msg1", "msg2 long", "msg3"],
            "model": "gpt-5",
        ]
        // 4 + 8 + 4 = 16 chars, /4 = 4
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 4)
    }

    func testEstimateRequestContextTokens_chatCompletionsDictWithTools() {
        let payload: [String: Any] = [
            "messages": ["msg1"],
            "tools": ["tool1", "tool2"],
        ]
        // (4) + (5+5) = 14 chars, /4 = 3
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 3)
    }

    func testEstimateRequestContextTokens_responsesAPIDictWithInput() {
        let payload: [String: Any] = [
            "input": "long input text",
            "instructions": "system prompt",
            "tools": ["tool1"],
        ]
        // 15 + 13 + 5 = 33 chars, /4 = 8
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 8)
    }

    func testEstimateRequestContextTokens_responsesAPIPartial() {
        let payload: [String: Any] = [
            "input": "abc",
        ]
        // 3 chars, /4 = 0
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 0)
    }

    func testEstimateRequestContextTokens_dictWithoutMessagesOrInput_fallsBackToValues() {
        let payload: [String: Any] = [
            "key1": "abc",
            "key2": "defg",
        ]
        // 3 + 4 = 7 chars, /4 = 1
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 1)
    }

    func testEstimateRequestContextTokens_stringValue_returnsCharCountDividedBy4() {
        let result = WenshuModelCatalog.estimateRequestContextTokens("hello world!")
        // 12 chars, /4 = 3
        XCTAssertEqual(result, 3)
    }

    func testEstimateRequestContextTokens_intValue_returnsStringRepDividedBy4() {
        let result = WenshuModelCatalog.estimateRequestContextTokens(42)
        // "42" = 2 chars, /4 = 0
        XCTAssertEqual(result, 0)
    }

    func testEstimateRequestContextTokens_emptyList_returnsZero() {
        let result = WenshuModelCatalog.estimateRequestContextTokens([Any]())
        XCTAssertEqual(result, 0)
    }

    func testEstimateRequestContextTokens_emptyDict_returnsZero() {
        let result = WenshuModelCatalog.estimateRequestContextTokens([String: Any]())
        XCTAssertEqual(result, 0)
    }

    func testEstimateRequestContextTokens_nsNullTreatedAsZero() {
        let payload: [String: Any] = [
            "messages": ["real message"],
            "tools": NSNull(),
        ]
        // 12 chars /4 = 3
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 3)
    }

    func testEstimateRequestContextTokens_nestedDict_summedRecursively() {
        let payload: [String: Any] = [
            "outer": ["inner1", "inner22"],
        ]
        // 6 + 7 = 13 chars, /4 = 3
        let result = WenshuModelCatalog.estimateRequestContextTokens(payload)
        XCTAssertEqual(result, 3)
    }

    func testEstimateRequestContextTokens_largeList_estimationIsRough() {
        // Build a 1000-char payload (= 1000/4 = 250 tokens).
        let longText = String(repeating: "a", count: 1000)
        let result = WenshuModelCatalog.estimateRequestContextTokens(longText)
        XCTAssertEqual(result, 250)
    }

    // MARK: -- H7.2 spec check (= hermes line-range citations in source)

    func testEstimateRequestContextTokens_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "ModelMetadataHermesGapPortTests.swift", with: "")
            + "ModelMetadata.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read ModelMetadata.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("H7 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("L66-L117"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
    }

    // MARK: -- H7.3 pre-existing API preservation (= Q112 no regressions)

    func testEstimateTokensRough_stillWorks() {
        let result = WenshuModelCatalog.estimateTokensRough("hello world")
        XCTAssertEqual(result, 2) // 11 chars / 4 = 2
    }
}
