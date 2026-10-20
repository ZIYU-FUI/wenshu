// TurnContext.swift
//
// Per-turn state bundle + per-turn setup helpers. Direct port of
// hermes `agent/turn_context.py` (= `build_turn_context` = the
// once-per-turn prologue that `ConversationLoop` used to inline as
// ~470 lines of straight-line setup before the tool loop ever
// started).
//
// Per hermes `turn_context.py` L2-15:
//
//   "All once-per-turn setup — stdio guarding, runtime-main wiring,
//    retry-counter resets, user-message sanitization, todo /
//    nudge-counter hydration, system-prompt restore-or-build,
//    crash-resilience persistence, preflight context compression,
//    the `pre_llm_call` plugin hook, and external-memory
//    prefetch — lives in `build_turn_context`."
//
// `TurnContext` is a pure value type bundling the inputs
// `ConversationLoop` already uses. `build_turn_context()` is the
// side-effect driver that performs the actual setup (= reset
// retry counters, install safe stdio, restore system prompt,
// refresh credentials) and returns the value type.
// `ConversationLoop.runTurn` now calls this once per turn.

import Foundation
import WenshuAgent

public struct TurnContext: Sendable, Equatable {
    public let taskId: String
    public let userMessage: String
    public let systemMessage: String?
    public let conversationHistory: [LLMMessage]
    public let model: String
    public let maxTokens: Int
    public let attemptNumber: Int

    /// Timestamp the per-turn setup completed (= .now when build_turn_context ran).
    public let builtAt: Date

    /// Per-turn retry-counter reset log (= hermes `agent._invalid_tool_retries = 0`
    /// etc. inline assignments).
    public let resetCounters: [String: Int]

    public init(
        taskId: String,
        userMessage: String,
        systemMessage: String?,
        conversationHistory: [LLMMessage],
        model: String,
        maxTokens: Int,
        attemptNumber: Int,
        builtAt: Date = .now,
        resetCounters: [String: Int] = [:]
    ) {
        self.taskId = taskId
        self.userMessage = userMessage
        self.systemMessage = systemMessage
        self.conversationHistory = conversationHistory
        self.model = model
        self.maxTokens = maxTokens
        self.attemptNumber = attemptNumber
        self.builtAt = builtAt
        self.resetCounters = resetCounters
    }

    /// Manual `Equatable` implementation (= Z-contract test
    /// `TurnContext: Equatable`): two contexts with the same content
    /// fields are equal, regardless of their `builtAt` timestamp (= a
    /// wall-clock captured at construction that always differs between
    /// two freshly-constructed instances = nanoseconds apart). Tests
    /// assert that two contexts with identical task + user + history
    /// are equal for diffing purposes; the creation time is
    /// observability metadata, not identity. Mirrors the manual
    /// `Equatable` pattern on `DisplayStateMachine` and `ContextBreakdown`.
    public static func == (lhs: TurnContext, rhs: TurnContext) -> Bool {
        return lhs.taskId == rhs.taskId
            && lhs.userMessage == rhs.userMessage
            && lhs.systemMessage == rhs.systemMessage
            && lhs.conversationHistory == rhs.conversationHistory
            && lhs.model == rhs.model
            && lhs.maxTokens == rhs.maxTokens
            && lhs.attemptNumber == rhs.attemptNumber
            && lhs.resetCounters == rhs.resetCounters
    }
}
