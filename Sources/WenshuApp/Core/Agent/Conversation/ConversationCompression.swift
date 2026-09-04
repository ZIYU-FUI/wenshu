//
//  ConversationCompression.swift · Wenshu · v0.35 ticket 003 sub-step 2
//
//  Caller-facing wrapper around ContextCompressor. Maps to hermes
//  conversation_compression.conversation_history_after_compression
//  (= L371 in conversation_compression.py, = the public entry that
//  ConversationLoop calls after every turn to update the persisted
//  history).
//
//  Provides:
//    - historyAfterCompression(messages:) -> [LLMMessage]?
//      (= Optional return = hermes pattern: nil when compression aborts;
//      caller detects no-op via nil result and stops retry loop)
//    - manualTrigger(messages:) for explicit user-initiated
//      compression (= ChatView manual button in sub-step 5)
//
//  v0.35 ticket 003 sub-step 2 of N.
//

import Foundation

public actor ConversationCompression {

    private let compressor: ContextCompressor

    public init(compressor: ContextCompressor = ContextCompressor()) {
        self.compressor = compressor
    }

    /// Compute compressed history after one conversation turn (= hermes
    /// conversation_history_after_compression L371 return shape).
    ///
    /// - Parameters:
    ///   - messages: Current message history (chronological).
    ///   - systemMessage: Current system prompt.
    /// - Returns: Compressed history (= or original messages unchanged
    ///   if no compression needed). Caller can detect "compression
    ///   happened" via `result.0.count < messages.count`.
    public func historyAfterCompression(
        messages: [LLMMessage],
        systemMessage: String
    ) async -> (messages: [LLMMessage], systemMessage: String) {
        await compressor.compressContext(messages: messages, systemMessage: systemMessage)
    }

    /// Manual compression trigger (= user clicks "Compress and continue"
    /// button in ChatView). Returns the new compressed history.
    public func manualTrigger(
        messages: [LLMMessage],
        systemMessage: String
    ) async -> (messages: [LLMMessage], systemMessage: String) {
        // Manual trigger forces compression regardless of budget (= hermes
        // `force=True` parameter on compress_context()). For wenshu-side
        // deterministic policy, we lower the budget temporarily to ensure
        // compression happens.
        let aggressiveCompressor = ContextCompressor(
            policy: ContextCompressor.Policy(
                keepRecentTurns: 4,
                maxTokens: 1_000  // artificially low to force compression
            )
        )
        return await aggressiveCompressor.compressContext(
            messages: messages,
            systemMessage: systemMessage
        )
    }
}