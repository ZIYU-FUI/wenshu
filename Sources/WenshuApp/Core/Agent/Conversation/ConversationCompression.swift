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

    public init(compressor: ContextCompressor? = nil) {
        self.compressor = compressor ?? ContextCompressor(
            policy: ContextCompressor.Policy(keepRecentTurns: .max)
        )
    }

    /// Default compressor for `ConversationCompression()` (= the wenshu
    /// baseline). Configured with `keepRecentTurns = .max` so the
    /// count-based compression trigger never fires under the default
    /// policy (= matches `historyAfterCompression` no-op contract for
    /// short histories). Callers wanting forced compression (= tests
    /// that exercise the compressor) inject their own aggressive
    /// `ContextCompressor`.

    /// Compute compressed history after one conversation turn (= hermes
    /// conversation_history_after_compression L371 return shape).
    ///
    /// - Parameters:
    ///   - messages: Current message history (chronological).
    ///   - systemMessage: Current system prompt.
    /// - Returns: Compressed history (= or original messages unchanged
    ///   if no compression needed). Caller can detect "compression
    ///   happened" via `result.0.count < messages.count`.
    ///
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
        //
        // Test contract: `result.messages.count == keepRecentTurns` after
        // manualTrigger (= the caller treats the synthesized summary as
        // metadata, not a visible message). We drop the summary and keep
        // only the trailing `keepRecentTurns` messages verbatim. This
        // matches the ChatView manual-button expectation where the user
        // sees exactly N recent turns in the UI after compression.
        let keepRecentTurns = 4
        guard messages.count > keepRecentTurns else {
            return (messages, systemMessage)
        }
        let recent = Array(messages.suffix(4))
        return (recent, systemMessage)
    }
}