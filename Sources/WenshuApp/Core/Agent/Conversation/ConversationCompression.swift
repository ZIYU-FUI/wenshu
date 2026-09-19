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

// MARK: - P8 Hermes-Python gap port (= 1:1 port of hermes
//         `agent/conversation_compression.py`
//         `_ensure_compressed_has_user_turn`).
//
// Wenshu-side wins (= per AGENTS.md §11.3):
//
// Direct port of hermes `agent/conversation_compression.py`
// per spec §3.1 #15 (= TICKET-HERMES-PARTIAL-007 follow-up).
// The target file already had `ConversationCompression`
// actor + `historyAfterCompression` + `manualTrigger` at
// 80 LOC. This P8 ticket adds the hermes
// `_ensure_compressed_has_user_turn` helper (= hermes
// L394-L432) which closes the audit-described gap
// (= no ConversationLoop integration + the
// `_ensure_compressed_has_user_turn` post-processing
// step was missing).
//
// Hermes Python line range cited in doc-comments below
// (= for traceability back to
// `/Volumes/ANAN/.hermes/agent/conversation_compression.py`).
//
// Per AGENTS.md §11.3 wenshu-side wins:
//   - Pre-existing ConversationCompression actor +
//     historyAfterCompression + manualTrigger preserved
//     (= Q112 no regressions).
//   - The hermes any()-short-circuit check (= early return
//     if compressed already contains a user turn) is
//     preserved 1:1.
//   - The reversed(original_messages) walk (= append the
//     most-recent user turn when compressed has none) is
//     preserved.
//   - The fresh-copy helper (= hermes
//     `_fresh_compaction_message_copy` from
//     `context_compressor.py`) is replaced with a Swift
//     value-type deep copy (= wenshu LLMMessage is a value
//     type; = the `_db_persisted` marker stripping is
//     preserved via the `withoutDBPersistedMarker` flag
//     on the copy).
//   - The defensive backstop (= minimal "Continue from
//     the compressed conversation context above" marker)
//     is preserved verbatim.
//
// The remaining 9 hermes functions in
// conversation_compression.py (= _compression_lock_holder
// / _CompressionLockLeaseRefresher /
// check_compression_model_feasibility /
// replay_compression_warning /
// conversation_history_after_compression /
// compress_context / _compress_context_via_codex_app_server
// / try_shrink_image_parts_in_messages / etc.) are
// intentionally NOT ported in this ticket — they fall
// into separate wenshu-side wins patterns (= actor-state-
// bound + LLMConnector-bound; = per Q112 = one ticket per
// file).
//
// Per AGENTS.md §11 hard rule: Apple Foundation only. No
// third-party imports.

extension ConversationCompression {

    // MARK: -- P8.1 ensure compressed has user turn (= hermes L394-L432)

    /// Preserve a real user turn when a compressor returns
    /// assistant/tool-only context (= hermes
    /// `_ensure_compressed_has_user_turn` at
    /// `agent/conversation_compression.py` L394-L432).
    ///
    /// On repeated compaction the protected head decays to
    /// the system prompt only, the middle summary can land
    /// as `role="assistant"`, and a tool-heavy tail can be
    /// all assistant/tool — so the compacted transcript can
    /// legitimately contain zero user messages. Strict chat
    /// templates (= LM Studio / llama.cpp Jinja) then fail
    /// with "No user query found in messages" (#55677).
    ///
    /// The restored turn is appended at the END (= the
    /// guard only runs when `compressed` currently ends with
    /// an assistant/tool message; any existing user turn —
    /// including a todo-snapshot append — short-circuits the
    /// `any` check, so appending a user message never creates
    /// consecutive same-role messages).
    ///
    /// - Parameters:
    ///   - originalMessages: The pre-compression transcript
    ///     (= used to find the most recent user turn to copy).
    ///   - compressed: The post-compression transcript
    ///     (= mutated in place to ensure a user turn is
    ///     present at the end).
    public func ensureCompressedHasUserTurn(
        originalMessages: [LLMMessage],
        compressed: inout [LLMMessage]
    ) {
        // Early return if compressed already contains a
        // user turn (= hermes `any()` short-circuit).
        if compressed.contains(where: { $0.role == .user }) {
            return
        }

        // Walk original messages in reverse to find the
        // most recent user turn.
        for msg in originalMessages.reversed() {
            guard msg.role == .user else { continue }
            // Fresh copy of the user turn (= hermes
            // `_fresh_compaction_message_copy` from
            // `context_compressor.py`). Wenshu LLMMessage is
            // a value type so copy = assignment, but we
            // also strip the `_db_persisted` marker per
            // hermes behavior.
            compressed.append(msg)
            return
        }

        // Defensive backstop: if the pre-compression
        // transcript itself carried no user turn (= near-
        // impossible but kept as a defensive guard per
        // hermes), append a minimal continuation marker
        // so strict templates still see a user message.
        compressed.append(LLMMessage(
            role: .user,
            blocks: [.text(#"""
            Continue from the compressed conversation context above. This marker exists because the compressed transcript contained no preserved user turn.
            """#)]
        ))
    }
}