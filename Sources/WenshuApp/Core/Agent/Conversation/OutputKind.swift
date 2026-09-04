//
//  OutputKind.swift · Wenshu · v0.21 ticket 49 (LLM output classification)
//

import Foundation

/// Classifies an LLM call by output length class.
/// Used by WenshuVerifier.send to decide whether to attach stop_sequences
/// (short outputs only — long outputs would be terminated mid-draft on first
/// forbidden-token match, which is catastrophic for novel writing).
public enum OutputKind: Sendable {
    /// User chat reply. 100-2000 tokens.
    case chat
    /// Chapter / novel body. 500-10000 tokens (long-form).
    case draft
    /// Commit message / code comment / classification. <500 tokens.
    /// stop_sequences attached — generation terminates on pollution token.
    case shortText
}