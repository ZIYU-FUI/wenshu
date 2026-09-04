//
//  TurnContextTests.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Unit tests for 5 actor-isolated turn-context structs (hermes turn_context.py +
//  turn_finalizer.py + turn_retry_state.py + message_sanitization.py +
//  message_content.py ports).
//
//  These are per-turn state bundles that compose with ConversationLoop
//  (= sub-step 3) and ToolExecutor (= sub-step 5). Each struct is small +
//  Sendable + immutable (= Swift value types where possible, actor classes
//  where mutation needs serialization).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TurnContext bundle (ticket 001 sub-step 4)")
struct TurnContextTests {

    // MARK: - TurnContext

    @Test("TurnContext bundles per-turn state immutably")
    func testTurnContextBundle() throws {
        let ctx = TurnContext(
            taskId: "task-1",
            userMessage: "hello",
            systemMessage: "you are an assistant",
            conversationHistory: [LLMMessage.user("prior")],
            model: "MiniMax-M3",
            maxTokens: 4096,
            attemptNumber: 0
        )

        #expect(ctx.taskId == "task-1")
        #expect(ctx.userMessage == "hello")
        #expect(ctx.systemMessage == "you are an assistant")
        #expect(ctx.conversationHistory.count == 1)
        #expect(ctx.model == "MiniMax-M3")
        #expect(ctx.maxTokens == 4096)
        #expect(ctx.attemptNumber == 0)
    }

    // MARK: - TurnFinalizer

    @Test("TurnFinalizer normalizes text + tool_use + thinking blocks into final message")
    func testTurnFinalizerNormalizes() throws {
        let response = LLMResponse(
            id: "resp-1",
            model: "MiniMax-M3",
            blocks: [
                .thinking(text: "reasoning", signature: "sig"),
                .text("answer"),
                .toolUse(id: "t1", name: "ReadFile", input: "{}")
            ],
            stopReason: .toolUse,
            usage: LLMUsage(inputTokens: 10, outputTokens: 20)
        )

        let finalized = TurnFinalizer.finalize(response: response)

        // All 3 blocks preserved in order
        #expect(finalized.blocks.count == 3)
        // Stop reason propagated
        #expect(finalized.stopReason == .toolUse)
        // Usage propagated
        #expect(finalized.usage.totalTokens == 30)
    }

    @Test("TurnFinalizer drops empty text blocks (= sanitization)")
    func testTurnFinalizerDropsEmptyText() throws {
        let response = LLMResponse(
            id: "resp-2",
            model: "MiniMax-M3",
            blocks: [
                .text(""),
                .text("actual answer"),
                .text("")
            ],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 5, outputTokens: 5)
        )

        let finalized = TurnFinalizer.finalize(response: response)
        #expect(finalized.blocks.count == 1)
        if case .text(let s) = finalized.blocks[0] {
            #expect(s == "actual answer")
        } else {
            Issue.record("expected text block")
        }
    }

    // MARK: - TurnRetryState

    @Test("TurnRetryState tracks attempt budget (= hermes IterationBudget)")
    func testTurnRetryStateBudget() {
        var state = TurnRetryState(maxAttempts: 3)

        #expect(state.canRetry)
        #expect(state.attemptNumber == 0)

        state.recordAttempt()
        #expect(state.canRetry)
        #expect(state.attemptNumber == 1)

        state.recordAttempt()
        state.recordAttempt()
        #expect(!state.canRetry)  // 3 attempts used, budget exhausted
        #expect(state.attemptNumber == 3)
    }

    @Test("TurnRetryState reset between turns")
    func testTurnRetryStateReset() {
        var state = TurnRetryState(maxAttempts: 3)
        state.recordAttempt()
        state.recordAttempt()

        state.reset()
        #expect(state.canRetry)
        #expect(state.attemptNumber == 0)
    }

    // MARK: - MessageSanitization

    @Test("MessageSanitization strips control characters from text blocks")
    func testMessageSanitizationStripsControlChars() {
        let dirty = "hello\u{0000}world\u{0007}foo\u{001F}bar"
        let clean = MessageSanitization.sanitizeText(dirty)
        #expect(clean == "helloworldfoobar")
    }

    @Test("MessageSanitization preserves non-ASCII Unicode (= Chinese / Japanese text)")
    func testMessageSanitizationPreservesUnicode() {
        let unicode = "文枢 = SwiftUI self-built 桌面 app"
        let clean = MessageSanitization.sanitizeText(unicode)
        #expect(clean == unicode)  // unchanged
    }

    @Test("MessageSanitization handles empty string")
    func testMessageSanitizationEmpty() {
        #expect(MessageSanitization.sanitizeText("").isEmpty)
    }

    @Test("MessageSanitization sanitizes message list (= in-place)")
    func testMessageSanitizationMessageList() {
        let messages = [
            LLMMessage.user("hello\u{0000}world"),
            LLMMessage.assistant("answer\u{0007}")
        ]

        let sanitized = MessageSanitization.sanitize(messages)
        #expect(sanitized[0].plainText == "helloworld")
        #expect(sanitized[1].plainText == "answer")
    }

    // MARK: - MessageContent

    @Test("MessageContent canonicalizes block list (= drops empty + normalizes order)")
    func testMessageContentCanonicalize() {
        let blocks: [LLMBlock] = [
            .text(""),
            .text("hello"),
            .thinking(text: "reasoning", signature: nil),
            .text("")
        ]

        let canonical = MessageContent.canonicalize(blocks)
        // Empty text dropped; thinking kept in original order
        #expect(canonical.count == 2)
        if case .text(let s) = canonical[0] {
            #expect(s == "hello")
        } else {
            Issue.record("expected text first")
        }
        if case .thinking = canonical[1] {
            // expected
        } else {
            Issue.record("expected thinking second")
        }
    }

    @Test("MessageContent coalesces adjacent text blocks")
    func testMessageContentCoalesce() {
        let blocks: [LLMBlock] = [
            .text("hello "),
            .text("world")
        ]

        let coalesced = MessageContent.coalesceAdjacentText(blocks)
        #expect(coalesced.count == 1)
        if case .text(let s) = coalesced[0] {
            #expect(s == "hello world")
        } else {
            Issue.record("expected single text block")
        }
    }

    @Test("MessageContent preserves tool_use + thinking (= never coalesced)")
    func testMessageContentPreservesNonText() {
        let blocks: [LLMBlock] = [
            .thinking(text: "r1", signature: nil),
            .thinking(text: "r2", signature: nil),
            .text("answer")
        ]

        let coalesced = MessageContent.coalesceAdjacentText(blocks)
        #expect(coalesced.count == 3)  // thinking blocks NOT coalesced
    }
}