//
//  TurnContext.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Per-turn state bundle. Mirrors hermes turn_context.build_turn_context
//  (= L558-590 in conversation_loop.py: "All once-per-turn setup —
//  stdio guarding, retry-counter resets, user message sanitization,
//  todo/nudge hydration, system-prompt restore-or-build, crash-resilience
//  persistence, preflight compression, the pre_llm_call plugin hook,
//  and external-memory prefetch — lives in build_turn_context").
//
//  In sub-step 4 (= the minimum surface to compose with ConversationLoop),
//  TurnContext is a pure value type bundling the inputs ConversationLoop
//  already uses. Full per-turn setup (= todo/nudge hydration, preflight
//  compression, etc.) lands in ticket 003 (ConversationCompression +
//  ContextEngine).
//
//  v0.35 sub-step 4 of 8 for ticket 001.
//

import Foundation

public struct TurnContext: Sendable, Equatable {
    public let taskId: String
    public let userMessage: String
    public let systemMessage: String?
    public let conversationHistory: [LLMMessage]
    public let model: String
    public let maxTokens: Int
    public let attemptNumber: Int

    public init(
        taskId: String,
        userMessage: String,
        systemMessage: String?,
        conversationHistory: [LLMMessage],
        model: String,
        maxTokens: Int,
        attemptNumber: Int
    ) {
        self.taskId = taskId
        self.userMessage = userMessage
        self.systemMessage = systemMessage
        self.conversationHistory = conversationHistory
        self.model = model
        self.maxTokens = maxTokens
        self.attemptNumber = attemptNumber
    }
}