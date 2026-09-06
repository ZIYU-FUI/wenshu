//
//  TurnFinalizerAndRetryStateTests.swift · Wenshu · v0.38 Batch 3 sub-step 10
//
//  Tests for TurnFinalizer + TurnRetryState + MessageContent canonicalize
//  (= v0.35 ticket 001 + 002).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = TurnFinalizer + TurnRetryState
//  are v0.35 ticket 001/002 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TurnFinalizer deep (= v0.35 ticket 001)")
struct TurnFinalizerDeepTests {

    @Test("TurnFinalizer.finalize: drops empty text blocks")
    func finalizeDropsEmptyText() {
        let response = LLMResponse(
            id: "msg-1",
            model: "test",
            blocks: [.text(""), .text("hello"), .text("")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 5)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        // 3 blocks -> 1 block (empty text removed)
        #expect(finalized.blocks.count == 1)
    }

    @Test("TurnFinalizer.finalize: preserves all non-empty blocks")
    func finalizePreservesBlocks() {
        let response = LLMResponse(
            id: "msg-1",
            model: "test",
            blocks: [
                .text("Hello "),
                .text("world"),
                .thinking(text: "reasoning", signature: "sig")
            ],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 5)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        #expect(finalized.blocks.count == 3)
    }

    @Test("TurnFinalizer.finalize: preserves stopReason + usage")
    func finalizePreservesMetadata() {
        let response = LLMResponse(
            id: "msg-1",
            model: "test",
            blocks: [.text("hello")],
            stopReason: .toolUse,
            usage: LLMUsage(inputTokens: 100, outputTokens: 50)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        #expect(finalized.stopReason == .toolUse)
        #expect(finalized.usage.inputTokens == 100)
        #expect(finalized.usage.outputTokens == 50)
    }

    @Test("TurnFinalizer.finalize: preserves id + model")
    func finalizePreservesIdModel() {
        let response = LLMResponse(
            id: "msg-abc",
            model: "claude-3-5-sonnet",
            blocks: [.text("hi")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 1, outputTokens: 1)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        #expect(finalized.id == "msg-abc")
        #expect(finalized.model == "claude-3-5-sonnet")
    }

    @Test("TurnFinalizer.finalize: empty response (no blocks) returns empty")
    func finalizeEmptyResponse() {
        let response = LLMResponse(
            id: "msg",
            model: "test",
            blocks: [],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
        let finalized = TurnFinalizer.finalize(response: response)
        #expect(finalized.blocks.isEmpty)
    }
}

@Suite("TurnRetryState deep (= v0.35 ticket 001)")
struct TurnRetryStateDeepTests {

    @Test("TurnRetryState: initial canRetry = true")
    func initialCanRetry() {
        let state = TurnRetryState(maxAttempts: 3)
        #expect(state.canRetry)
        #expect(state.remainingAttempts == 3)
    }

    @Test("TurnRetryState: canRetry = false after max attempts")
    func canRetryAfterMax() {
        var state = TurnRetryState(maxAttempts: 2)
        state.recordAttempt()
        #expect(state.canRetry)
        state.recordAttempt()
        #expect(!state.canRetry)
        #expect(state.remainingAttempts == 0)
    }

    @Test("TurnRetryState: recordAttempt increments counter")
    func recordAttemptIncrements() {
        var state = TurnRetryState(maxAttempts: 5)
        let initial = state.attemptNumber
        state.recordAttempt()
        #expect(state.attemptNumber == initial + 1)
    }

    @Test("TurnRetryState: reset returns to 0")
    func resetReturnsZero() {
        var state = TurnRetryState(maxAttempts: 3)
        state.recordAttempt()
        state.recordAttempt()
        #expect(state.attemptNumber == 2)
        state.reset()
        #expect(state.attemptNumber == 0)
        #expect(state.canRetry)
    }

    @Test("TurnRetryState: remainingAttempts never negative")
    func remainingAttemptsClamped() {
        var state = TurnRetryState(maxAttempts: 2)
        state.recordAttempt()
        state.recordAttempt()
        state.recordAttempt()  // over the limit
        #expect(state.remainingAttempts == 0)
    }

    @Test("TurnRetryState: maxAttempts = 1 initial state still allows one attempt")
    func maxAttemptsOne() {
        // Hermetic contract: maxAttempts = total attempts the state will allow.
        // Initial state has consumed zero attempts, so remainingAttempts = 1
        // and canRetry = (0 < 1) = true. After one recordAttempt() the budget
        // is exhausted. This matches the production invariant
        //     canRetry = attemptNumber < maxAttempts
        // and is consistent with the other tests in this suite:
        //   - initialCanRetry: maxAttempts=3 → canRetry=true, remaining=3
        //   - canRetryAfterMax: maxAttempts=2, after 2 attempts → !canRetry
        //   - recordAttemptIncrements: maxAttempts=5 → recordAttempt bumps count
        // Hermes parity: hermes turn_retry_state.py has NO maxAttempts field
        // (it is per-attempt recovery bookkeeping, distinct from the
        // run_conversation while-loop's max_retries local); the Swift
        // TurnRetryState budget tracker is a wenshu-side invention that
        // mirrors the local-variable contract used in the run_conversation
        // loop boundary (attempts-counted, not retries-counted).
        let state = TurnRetryState(maxAttempts: 1)
        #expect(state.canRetry)
        #expect(state.remainingAttempts == 1)
        var mutated = state
        mutated.recordAttempt()
        #expect(!mutated.canRetry)
        #expect(mutated.remainingAttempts == 0)
    }

    @Test("TurnRetryState: init clamps maxAttempts = 0 up to the 1 floor")
    func preconditionFailsForZero() {
        // Production init uses max(1, maxAttempts) so a 0 input is treated
        // as the minimum-valid value (= same contract as maxAttempts: 1).
        // This documents the silent floor (= no fatalError) and verifies
        // the post-init invariant holds: remainingAttempts = 1 - 0 = 1,
        // matching the maxAttemptsOne contract above.
        let state = TurnRetryState(maxAttempts: 0)
        #expect(state.maxAttempts == 1)
        #expect(state.canRetry)
        #expect(state.remainingAttempts == 1)
    }
}

@Suite("MessageContent canonicalize (= v0.35 ticket 001)")
struct MessageContentCanonicalizeTests {

    @Test("MessageContent.canonicalize: drops empty text blocks")
    func canonicalizeDropsEmpty() {
        let blocks: [LLMBlock] = [.text(""), .text("hello"), .text("")]
        let canonical = MessageContent.canonicalize(blocks)
        #expect(canonical.count == 1)
    }

    @Test("MessageContent.canonicalize: preserves non-text blocks")
    func canonicalizePreservesNonText() {
        let blocks: [LLMBlock] = [
            .text("hello"),
            .thinking(text: "reasoning", signature: "sig"),
            .toolUse(id: "t1", name: "X", input: "{}"),
            .toolResult(toolUseID: "t1", output: "result")
        ]
        let canonical = MessageContent.canonicalize(blocks)
        #expect(canonical.count == 4)
    }

    @Test("MessageContent.canonicalize: empty input returns empty")
    func canonicalizeEmpty() {
        let canonical = MessageContent.canonicalize([])
        #expect(canonical.isEmpty)
    }

    @Test("MessageContent.canonicalize: all empty returns empty")
    func canonicalizeAllEmpty() {
        let blocks: [LLMBlock] = [.text(""), .text("")]
        let canonical = MessageContent.canonicalize(blocks)
        #expect(canonical.isEmpty)
    }
}
