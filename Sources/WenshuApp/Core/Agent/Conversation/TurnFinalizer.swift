//
//  TurnFinalizer.swift · Wenshu · v0.35 ticket 001 sub-step 4
//
//  Turn-end normalization. Mirrors hermes turn_finalizer.py
//  (= "~600 LOC" — finalizes LLMResponse into ConversationResult shape:
//  drop empty text blocks, propagate stopReason + usage, coalesce adjacent
//  blocks where appropriate).
//
//  Static utility (= no state). ConversationLoop.runConversation invokes
//  this at the end of each turn before returning ConversationResult.
//
//  v0.35 sub-step 4 of 8 for ticket 001.
//

import Foundation

public enum TurnFinalizer {
    /// Finalize an LLMResponse into the canonical ConversationResult shape.
    ///
    /// Operations:
    /// - Drop empty text blocks (= keeps .text("") → nothing)
    /// - Propagate stopReason + usage (= pass-through)
    /// - Preserve block order (= hermes `_emit_terminal_post_tool_call`
    ///   pattern: keep raw order so downstream consumers see the same
    ///   sequence the model emitted)
    public static func finalize(response: LLMResponse) -> LLMResponse {
        let canonical = MessageContent.canonicalize(response.blocks)
        return LLMResponse(
            id: response.id,
            model: response.model,
            blocks: canonical,
            stopReason: response.stopReason,
            usage: response.usage
        )
    }
}