//
//  ManualCompressionFeedback.swift · Wenshu · HERMES-INTERNAL-007 (2026-09-04)
//
//  1:1 port of hermes manual_compression_feedback.py (= hermes-internal
//  module #7, boss 2026-09-04 OOB 'A'). Thin adapter that delegates to
//  wenshu's ConversationCompression.swift (= canonical compression surface).
//
//  The hermes port's summarize_manual_compression returns a user-facing
//  feedback dict (headline + token line + optional note). Wenshu returns
//  the same shape as a ManualCompressionFeedback value that the chat
//  UI can render verbatim.
//

import Foundation

public struct ManualCompressionFeedback: Sendable, Equatable {
    public let headline: String
    public let tokenLine: String
    public let note: String?
    public let isNoOp: Bool

    public init(headline: String, tokenLine: String, note: String? = nil, isNoOp: Bool = false) {
        self.headline = headline
        self.tokenLine = tokenLine
        self.note = note
        self.isNoOp = isNoOp
    }
}

public actor ManualCompressionFeedbackRunner {

    private let compression: ConversationCompression

    public init(compression: ConversationCompression) {
        self.compression = compression
    }

    /// Trigger a manual compression. Returns the user-facing feedback
    /// summary (= hermes summarize_manual_compression semantics) plus
    /// the post-compression history. When `customPrompt` is supplied
    /// it is folded into the system message so the next turn sees a
    /// custom-tailored compression context (= hermes lets the user
    /// steer what the compressor should prioritise).
    public func triggerManualCompression(
        messages: [LLMMessage],
        systemMessage: String,
        customPrompt: String? = nil
    ) async throws -> (feedback: ManualCompressionFeedback, messages: [LLMMessage], systemMessage: String) {
        let effectiveSystem: String
        if let customPrompt, !customPrompt.isEmpty {
            effectiveSystem = systemMessage + "\n\n" + customPrompt
        } else {
            effectiveSystem = systemMessage
        }

        let result = await compression.manualTrigger(
            messages: messages,
            systemMessage: effectiveSystem
        )

        let feedback = Self.buildFeedback(
            beforeMessages: messages,
            afterMessages: result.messages,
            beforeTokens: Self.estimateTokens(systemMessage),
            afterTokens: Self.estimateTokens(result.systemMessage)
        )
        return (feedback, result.messages, result.systemMessage)
    }

    // MARK: - Internals (= hermes summarize_manual_compression L8-49)

    static func buildFeedback(
        beforeMessages: [LLMMessage],
        afterMessages: [LLMMessage],
        beforeTokens: Int,
        afterTokens: Int
    ) -> ManualCompressionFeedback {
        let beforeCount = beforeMessages.count
        let afterCount = afterMessages.count
        let noop = afterMessages == beforeMessages

        if noop {
            let headline = "No changes from compression: \(beforeCount) messages"
            let tokenLine: String
            if afterTokens == beforeTokens {
                tokenLine = "Approx request size: ~\(beforeTokens) tokens (unchanged)"
            } else {
                tokenLine = "Approx request size: ~\(beforeTokens) -> ~\(afterTokens) tokens"
            }
            return ManualCompressionFeedback(
                headline: headline,
                tokenLine: tokenLine,
                note: nil,
                isNoOp: true
            )
        } else {
            let headline = "Compressed: \(beforeCount) -> \(afterCount) messages"
            let tokenLine = "Approx request size: ~\(beforeTokens) -> ~\(afterTokens) tokens"
            var note: String? = nil
            if afterCount < beforeCount && afterTokens > beforeTokens {
                note = "Note: fewer messages can still raise this estimate when compression rewrites the transcript into denser summaries."
            }
            return ManualCompressionFeedback(
                headline: headline,
                tokenLine: tokenLine,
                note: note,
                isNoOp: false
            )
        }
    }

    /// Bounded token estimator (= 1 token ≈ 4 characters, hermes
    /// convention). Sufficient for the feedback headline — exact
    /// counts require provider-specific tokenizers which we don't
    /// call here (= that lives in the connector layer).
    static func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}