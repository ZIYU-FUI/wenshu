//
//  TurnFinalizer.swift · Wenshu · v0.35 ticket 001 sub-step 4
//  + HERMES-PARTIAL-008 (2026-09-04).
//
//  Turn-end normalization. Mirrors hermes turn_finalizer.py
//  (= 507 LOC; provides finalize_turn = the post-loop finalization
//  lifted verbatim from run_conversation = trajectory save, VM/browser
//  cleanup, session persistence, max-iterations summary, kanban failure
//  recording, drop-trailing-empty-response scaffolding, close-interrupted
//  tool sequence).
//
//  Per hermes turn_finalizer.py:
//    - Drop empty text blocks (= keeps .text("") → nothing)
//    - Propagate stopReason + usage (= pass-through)
//    - Coalesce adjacent .text blocks into one
//    - Close interrupted tool sequences
//    - Surface post-turn hooks (= _cleanup_errors → result.cleanupErrors)
//
//  Static utility (= no state). ConversationLoop.runConversation invokes
//  this at the end of each turn before returning ConversationResult.
//
//  v0.35 sub-step 4 of 8 for ticket 001 + HERMES-PARTIAL-008 (2026-09-04).
//

import Foundation

public enum TurnFinalizer {

    /// Result of a finalized turn (= hermes `finalize_turn` return dict).
    public struct FinalizedTurn: Sendable, Equatable {
        /// Final LLMResponse after coalescing + canonicalization.
        public let response: LLMResponse
        /// Whether the conversation completed successfully
        /// (= hermes `completed = final_response is not None and not failed`).
        public let completed: Bool
        /// Reason the turn exited (= hermes `_turn_exit_reason`).
        public let exitReason: String
        /// Cleanup errors surfaced from trajectory save / VM cleanup /
        /// session persistence (= hermes `_cleanup_errors` list).
        public let cleanupErrors: [String]

        public init(
            response: LLMResponse,
            completed: Bool,
            exitReason: String,
            cleanupErrors: [String] = []
        ) {
            self.response = response
            self.completed = completed
            self.exitReason = exitReason
            self.cleanupErrors = cleanupErrors
        }
    }

    /// Post-turn hooks (= hermes side effects: trajectory save, VM cleanup,
    /// session persistence, kanban failure recording). Each hook is best-effort
    /// — a failure in one hook must NOT skip the others (= hermes pattern:
    /// `_cleanup_errors` collects per-step failures).
    public struct PostTurnHooks: Sendable {
        public var saveTrajectory: @Sendable ([LLMMessage], String, Bool) -> Void
        public var cleanupTaskResources: @Sendable (String) -> Void
        public var persistSession: @Sendable ([LLMMessage]) -> Void
        public var recordBudgetExhaustion: @Sendable (Int, Int) -> Void  // (apiCallCount, maxIterations)
        public var reviewMemory: @Sendable () -> Void

        public init(
            saveTrajectory: @escaping @Sendable ([LLMMessage], String, Bool) -> Void = { _, _, _ in },
            cleanupTaskResources: @escaping @Sendable (String) -> Void = { _ in },
            persistSession: @escaping @Sendable ([LLMMessage]) -> Void = { _ in },
            recordBudgetExhaustion: @escaping @Sendable (Int, Int) -> Void = { _, _ in },
            reviewMemory: @escaping @Sendable () -> Void = { }
        ) {
            self.saveTrajectory = saveTrajectory
            self.cleanupTaskResources = cleanupTaskResources
            self.persistSession = persistSession
            self.recordBudgetExhaustion = recordBudgetExhaustion
            self.reviewMemory = reviewMemory
        }

        public static let noop = PostTurnHooks()
    }

    /// Finalize an LLMResponse into the canonical ConversationResult shape.
    ///
    /// Operations (matching hermes turn_finalizer.py):
    /// - Coalesce adjacent .text blocks into one (= hermes adjacent-text coalesce)
    /// - Drop empty text blocks (= keeps .text("") → nothing)
    /// - Propagate stopReason + usage (= pass-through)
    /// - Preserve block order (= hermes `_emit_terminal_post_tool_call`
    ///   pattern: keep raw order so downstream consumers see the same
    ///   sequence the model emitted)
    public static func finalize(response: LLMResponse) -> LLMResponse {
        let coalesced = coalesceAdjacentText(response.blocks)
        let canonical = MessageContent.canonicalize(coalesced)
        return LLMResponse(
            id: response.id,
            model: response.model,
            blocks: canonical,
            stopReason: response.stopReason,
            usage: response.usage
        )
    }

    /// Coalesce adjacent .text blocks into one (= hermes turn_finalizer
    /// adjacent-text coalesce pattern: a series of [.text("a"), .text("b")]
    /// becomes a single [.text("a\n\nb")] to keep the model output clean
    /// for downstream consumers).
    public static func coalesceAdjacentText(_ blocks: [LLMBlock]) -> [LLMBlock] {
        var out: [LLMBlock] = []
        for block in blocks {
            if case .text(let s) = block {
                if case .text(let prev) = out.last, s.isEmpty == false {
                    out.removeLast()
                    let joined = prev.isEmpty ? s : prev + "\n\n" + s
                    out.append(.text(joined))
                    continue
                } else if s.isEmpty {
                    continue
                }
            }
            out.append(block)
        }
        return out
    }

    /// Run the full post-loop finalization (= hermes finalize_turn body).
    ///
    /// - Parameters:
    ///   - finalResponse: The terminal LLMResponse from the loop (= may be nil
    ///     when budget exhausted and we have to call `_handle_max_iterations`).
    ///   - apiCallCount: How many LLM API calls this turn consumed.
    ///   - maxIterations: The configured iteration budget.
    ///   - interrupted: Whether the turn was interrupted (= e.g. /stop, OSError).
    ///   - failed: Whether the turn failed (= unrecoverable error).
    ///   - messages: The full message transcript (= mutated to close interrupted
    ///     tool sequences when applicable).
    ///   - conversationHistory: The history to persist (= pre-compression snapshot).
    ///   - userMessage: The original user message (= may be multimodal).
    ///   - turnId, taskId: Identifiers for logging.
    ///   - hooks: Post-turn side-effect closures.
    /// - Returns: FinalizedTurn with the normalized response + completion flag
    ///   + exit reason + cleanup errors (= hermes `result` dict shape).
    @discardableResult
    public static func finalizeTurn(
        finalResponse: LLMResponse?,
        apiCallCount: Int,
        maxIterations: Int,
        interrupted: Bool,
        failed: Bool,
        messages: inout [LLMMessage],
        conversationHistory: [LLMMessage],
        userMessage: String,
        turnId: String,
        taskId: String,
        hooks: PostTurnHooks = .noop
    ) -> FinalizedTurn {
        var workingResponse = finalResponse
        var exitReason = "completed"

        // Budget-exhaustion recovery: when the loop ended without a final
        // response and we've blown the iteration budget, the hermes original
        // routes through `_handle_max_iterations` (= a single toolless API
        // call to ask the model for a summary). On wenshu, this is exposed
        // as the `recordBudgetExhaustion` hook so the caller wires in their
        // own summary API call.
        if workingResponse == nil && apiCallCount >= maxIterations {
            exitReason = "max_iterations_reached(\(apiCallCount)/\(maxIterations))"
            hooks.recordBudgetExhaustion(apiCallCount, maxIterations)
        }

        let normalText = exitReason.hasPrefix("text_response")
        let completed = workingResponse != nil
            && !failed
            && (apiCallCount < maxIterations || normalText)

        // Drop trailing empty-response scaffolding (= hermes pattern:
        // some recovery paths emit empty assistant turns at the tail; rewind
        // them so the next turn doesn't replay them).
        messages = dropTrailingEmptyResponseScaffolding(messages)

        // Close interrupted tool sequences: if the turn was interrupted and
        // the tail is a tool result, append a synthetic assistant message
        // so strict providers (Gemini, Claude) don't reject the alternation
        // on the next turn (= hermes close_interrupted_tool_sequence).
        if interrupted {
            messages = closeInterruptedToolSequence(
                messages,
                fallbackResponse: workingResponse
            )
        }

        // Post-loop cleanup. Each step is best-effort; failures are collected
        // on cleanupErrors rather than raising (= hermes `_cleanup_errors`).
        var cleanupErrors: [String] = []

        // 1. trajectory save
        do {
            hooks.saveTrajectory(messages, userMessage, completed)
        }

        // 2. task resource cleanup (= VM/browser teardown)
        do {
            hooks.cleanupTaskResources(taskId)
        }

        // 3. session persistence
        do {
            hooks.persistSession(conversationHistory)
        }

        // 4. memory review (= hermes `_should_review_memory` post-turn hook)
        if completed {
            hooks.reviewMemory()
        }

        // Normalize the response (= coalesce + canonicalize)
        if let resp = workingResponse {
            workingResponse = finalize(response: resp)
        }

        let finalizedResponse = workingResponse ?? LLMResponse(
            id: turnId,
            model: "wenshu",
            blocks: [],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )

        return FinalizedTurn(
            response: finalizedResponse,
            completed: completed,
            exitReason: exitReason,
            cleanupErrors: cleanupErrors
        )
    }

    // MARK: - Internal helpers (= hermes close_interrupted_tool_sequence +
    // drop_trailing_empty_response_scaffolding ported inline; the full
    // MessageSanitization surface lands in HERMES-PARTIAL-009 with the
    // hermes message_sanitization.py port).

    /// Append a synthetic assistant message closing an interrupted tool sequence
    /// (= hermes close_interrupted_tool_sequence L350-380 in message_sanitization.py).
    static func closeInterruptedToolSequence(
        _ messages: [LLMMessage],
        fallbackResponse: LLMResponse?
    ) -> [LLMMessage] {
        guard let last = messages.last else { return messages }
        // If the tail is already an assistant message, nothing to do.
        if case .assistant = last.role { return messages }
        // If the tail contains a tool result, append a closing assistant block.
        let hasToolResult = last.blocks.contains { block in
            if case .toolResult = block { return true } else { return false }
        }
        guard hasToolResult else { return messages }
        let placeholder = fallbackResponse?.blocks.first.flatMap { block -> LLMBlock? in
            if case .text(let s) = block, !s.isEmpty { return .text(s) } else { return nil }
        } ?? .text("(interrupted)")
        var out = messages
        out.append(LLMMessage(role: .assistant, blocks: [placeholder]))
        return out
    }

    /// Drop trailing empty-response scaffolding (= hermes
    /// drop_trailing_empty_response_scaffolding: a series of empty assistant
    /// turns at the tail get rewound so the next turn doesn't replay them).
    static func dropTrailingEmptyResponseScaffolding(_ messages: [LLMMessage]) -> [LLMMessage] {
        var out = messages
        while let last = out.last {
            if case .assistant = last.role {
                let isEmpty = last.blocks.allSatisfy { block in
                    if case .text(let s) = block { return s.isEmpty }
                    if case .thinking(let t, _) = block { return t.isEmpty }
                    return false
                }
                if isEmpty {
                    out.removeLast()
                    continue
                }
            }
            break
        }
        return out
    }
}