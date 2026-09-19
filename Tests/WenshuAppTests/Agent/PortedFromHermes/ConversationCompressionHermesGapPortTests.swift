//
//  ConversationCompressionHermesGapPortTests.swift · Wenshu · P8-CONVERSATION-COMPRESSION-HERMES-PORT (2026-09-19)
//
//  Verifies the new hermes port addition to
//  `Core/Agent/Conversation/ConversationCompression.swift`
//  (= hermes `agent/conversation_compression.py` 1367 LOC Python).
//
//  Hermes pure helper ported:
//    - ensureCompressedHasUserTurn(originalMessages:compressed:)
//      (= hermes `_ensure_compressed_has_user_turn` at L394-L432)
//
//  Per AGENTS.md §11.3 wenshu-side wins: pure helper port; = no
//  compress_context / _compress_context_via_codex_app_server /
//  _compression_lock_holder (= those are actor-state-bound
//  per the wenshu-side-wins pattern; = per Q112 = one ticket
//  per file = the remaining 9 hermes functions deferred).
//

import XCTest
@testable import WenshuApp

final class ConversationCompressionHermesGapPortTests: XCTestCase {

    // MARK: -- P8.1 ensureCompressedHasUserTurn tests (= hermes L394-L432)

    func testEnsureCompressedHasUserTurn_compressedHasUserTurn_earlyReturn() {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = []
        var compressed: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")])
        ]
        let initialCount = compressed.count
        Task {
            await compressor.ensureCompressedHasUserTurn(
                originalMessages: original,
                compressed: &compressed
            )
        }
        // Note: actor isolation means we can't easily await
        // here. The test verifies the early-return logic via
        // synchronous fallback (= we'll do that next).
    }

    func testEnsureCompressedHasUserTurn_syncTest_compressedHasUser_earlyReturn() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = []
        var compressed: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")])
        ]
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        XCTAssertEqual(compressed.count, 1)
        XCTAssertEqual(compressed.first?.role, .user)
        XCTAssertEqual(compressed.first?.blocks.first?.textValue, "hi")
    }

    func testEnsureCompressedHasUserTurn_noUserTurnInCompressed_copiesFromOriginal() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("first user")]),
            LLMMessage(role: .assistant, blocks: [.text("first assistant")]),
            LLMMessage(role: .user, blocks: [.text("last user")]),
        ]
        var compressed: [LLMMessage] = [
            LLMMessage(role: .assistant, blocks: [.text("summary")]),
            LLMMessage(role: .tool, blocks: [.text("tool result")]),
        ]
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        XCTAssertEqual(compressed.count, 3)
        XCTAssertEqual(compressed.last?.role, .user)
        // Most-recent user turn is copied (= hermes
        // reversed(original_messages) walk).
        XCTAssertEqual(compressed.last?.blocks.first?.textValue, "last user")
    }

    func testEnsureCompressedHasUserTurn_noUserTurnAnywhere_appendsBackstop() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = [
            LLMMessage(role: .assistant, blocks: [.text("only assistant")]),
            LLMMessage(role: .tool, blocks: [.text("only tool")]),
        ]
        var compressed: [LLMMessage] = [
            LLMMessage(role: .assistant, blocks: [.text("summary")]),
        ]
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        XCTAssertEqual(compressed.count, 2)
        XCTAssertEqual(compressed.last?.role, .user)
        XCTAssertTrue(
            compressed.last?.blocks.first?.textValue.contains("Continue from the compressed conversation context above") ?? false
        )
    }

    func testEnsureCompressedHasUserTurn_emptyBoth_messages_emptyAfterCall() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = []
        var compressed: [LLMMessage] = []
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        // Defensive backstop: a user message IS appended even
        // when both are empty.
        XCTAssertEqual(compressed.count, 1)
        XCTAssertEqual(compressed.first?.role, .user)
    }

    func testEnsureCompressedHasUserTurn_alreadyHasUserTurn_notDuplicated() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("original user")])
        ]
        var compressed: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("existing user")]),
            LLMMessage(role: .assistant, blocks: [.text("response")]),
        ]
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        XCTAssertEqual(compressed.count, 2)
        XCTAssertEqual(compressed.first?.blocks.first?.textValue, "existing user")
    }

    func testEnsureCompressedHasUserTurn_findsMostRecentUserTurn() async {
        let compressor = ConversationCompression()
        let original: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("old user 1")]),
            LLMMessage(role: .assistant, blocks: [.text("response 1")]),
            LLMMessage(role: .user, blocks: [.text("old user 2")]),
            LLMMessage(role: .assistant, blocks: [.text("response 2")]),
            LLMMessage(role: .user, blocks: [.text("most recent user")]),
            LLMMessage(role: .assistant, blocks: [.text("response 3")]),
        ]
        var compressed: [LLMMessage] = [
            LLMMessage(role: .tool, blocks: [.text("tool only")]),
        ]
        await compressor.ensureCompressedHasUserTurn(
            originalMessages: original,
            compressed: &compressed
        )
        XCTAssertEqual(compressed.last?.blocks.first?.textValue, "most recent user")
    }

    // MARK: -- Spec check

    func testSourceFile_documentedAsHermesPort() {
        let sourcePath = #file
            .replacingOccurrences(of: "ConversationCompressionHermesGapPortTests.swift", with: "")
            + "ConversationCompression.swift"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            XCTFail("Could not read ConversationCompression.swift at \(sourcePath)")
            return
        }
        XCTAssertTrue(source.contains("P8 Hermes-Python gap port"))
        XCTAssertTrue(source.contains("agent/conversation_compression.py"))
        XCTAssertTrue(source.contains("Wenshu-side wins"))
        XCTAssertTrue(source.contains("ensureCompressedHasUserTurn"))
        XCTAssertTrue(source.contains("L394-L432"))
    }
}
