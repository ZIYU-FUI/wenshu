//
//  TurnFinalizerFinalizeTurnTests.swift · Wenshu · HERMES-PARTIAL-008 (2026-09-04)
//
//  Round-trip tests for the extended TurnFinalizer surface (= hermes
//  turn_finalizer.py = 507 LOC):
    //    1. testCoalesceAdjacentText       — adjacent .text blocks merge into 1
    //    2. testFinalizeTurnCompleted      — happy-path completed=true
    //    3. testFinalizeTurnBudgetExhausted — exitReason="max_iterations_reached(...)"
//    4. testInterruptedClosesToolSeq    — close_interrupted_tool_sequence
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TurnFinalizerFinalizeTurn (HERMES-PARTIAL-008)")
struct TurnFinalizerFinalizeTurnTests {

    // MARK: - Test 1: Adjacent text coalescing

    @Test("coalesceAdjacentText merges adjacent .text blocks into one")
    func testCoalesceAdjacentText() {
        let blocks: [LLMBlock] = [
            .text("hello"),
            .text(""),
            .text("world"),
            .thinking(text: "reasoning", signature: "sig"),
            .text("more")
        ]
        let coalesced = TurnFinalizer.coalesceAdjacentText(blocks)
        // 5 → 3 (text, thinking, text) with the first two text blocks merged.
        #expect(coalesced.count == 3)
        if case .text(let s) = coalesced[0] {
            #expect(s.contains("hello"))
            #expect(s.contains("world"))
        } else {
            Issue.record("expected .text at index 0")
        }
        if case .thinking = coalesced[1] { /* ok */ } else {
            Issue.record("expected .thinking at index 1")
        }
        if case .text(let s) = coalesced[2] {
            #expect(s == "more")
        } else {
            Issue.record("expected .text at index 2")
        }
    }

    // MARK: - Test 2: finalizeTurn happy-path

    @Test("finalizeTurn with a final response marks completed=true")
    func testFinalizeTurnCompleted() {
        let response = LLMResponse(
            id: "r1",
            model: "mock",
            blocks: [.text("hi")],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 10, outputTokens: 5)
        )
        var messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("hi")]),
            LLMMessage(role: .assistant, blocks: [.text("hi back")])
        ]
        let finalized = TurnFinalizer.finalizeTurn(
            finalResponse: response,
            apiCallCount: 1,
            maxIterations: 10,
            interrupted: false,
            failed: false,
            messages: &messages,
            conversationHistory: messages,
            userMessage: "hi",
            turnId: "t1",
            taskId: "task1"
        )
        #expect(finalized.completed == true)
        #expect(finalized.exitReason == "completed")
        #expect(finalized.cleanupErrors.isEmpty)
    }

    // MARK: - Test 3: Budget exhaustion

    @Test("finalizeTurn records max_iterations_reached exit reason when budget blown")
    func testFinalizeTurnBudgetExhausted() {
        final class BudgetRecorder: @unchecked Sendable {
            private let lock = NSLock()
            private var calledStorage = false
            func mark() { lock.withLock { calledStorage = true } }
            var snapshot: Bool { lock.withLock { calledStorage } }
        }
        let rec = BudgetRecorder()
        let hooks = TurnFinalizer.PostTurnHooks(
            recordBudgetExhaustion: { _, _ in rec.mark() }
        )
        var messages: [LLMMessage] = []
        let finalized = TurnFinalizer.finalizeTurn(
            finalResponse: nil,
            apiCallCount: 10,
            maxIterations: 10,
            interrupted: false,
            failed: false,
            messages: &messages,
            conversationHistory: messages,
            userMessage: "x",
            turnId: "t1",
            taskId: "task1",
            hooks: hooks
        )
        let called = rec.snapshot
        #expect(called == true)
        #expect(finalized.exitReason.hasPrefix("max_iterations_reached"))
        #expect(finalized.completed == false)
    }

    // MARK: - Test 4: Interrupted tool sequence closure

    @Test("interrupted turn with tool result tail appends a closing assistant message")
    func testInterruptedClosesToolSeq() {
        // Transcript ends with a tool result (no closing assistant).
        var messages: [LLMMessage] = [
            LLMMessage(role: .user, blocks: [.text("search for foo")]),
            LLMMessage(role: .assistant, blocks: [.toolUse(id: "t1", name: "search", input: "{}")]),
            LLMMessage(role: .tool, blocks: [.toolResult(toolUseID: "t1", output: "results")])
        ]
        _ = TurnFinalizer.finalizeTurn(
            finalResponse: nil,
            apiCallCount: 1,
            maxIterations: 10,
            interrupted: true,
            failed: false,
            messages: &messages,
            conversationHistory: messages,
            userMessage: "search for foo",
            turnId: "t1",
            taskId: "task1"
        )
        // A synthetic assistant message should have been appended.
        #expect(messages.count == 4)
        if case .assistant = messages.last?.role {
            // ok
        } else {
            Issue.record("expected .assistant tail after interrupted close")
        }
    }
}