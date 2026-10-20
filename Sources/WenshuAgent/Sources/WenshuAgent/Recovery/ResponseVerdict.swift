// ResponseVerdict.swift
//
// What to do with one model reply (= hermes turn_empty_response /
// turn_truncation / turn_overflow / turn_stop_gates, each of which returns a
// verdict rather than raising).
//
// A verdict, not an exception, because half of these outcomes are not
// failures. A truncated reply is finished work that needs a continuation; a
// stop gate is finished work that needs one more look. Raising would force the
// caller to distinguish "this attempt died" from "keep going", and every
// caller would get that distinction subtly wrong.
//
// The ladder in RecoveryLadder walks these in a fixed order and takes the
// first non-accept verdict, so the order encodes precedence rather than
// whichever check happened to be written first.

import Foundation

/// Why a reply was rejected, for logs and for the message the user sees.
public enum RetryReason: String, Sendable, Equatable, CaseIterable {
    /// The model returned nothing usable.
    case emptyReply
    /// The provider refused on content policy (= not the model's fault).
    case contentFiltered
    /// The provider refused for an account or quota reason.
    case quotaExhausted
    /// The prompt exceeded the context window.
    case contextOverflow
    /// A transient transport failure.
    case transientError
    /// The reply was cut off at the output cap.
    case truncated
    /// The reply ended mid-sentence with no tool call.
    case incompleteSentence
    /// A non-recoverable provider error.
    case permanentError
}

/// What the ladder decided to do with a reply.
public enum ResponseVerdict: Sendable, Equatable {
    /// Good reply: hand it to the user.
    case accept
    /// This attempt is void. Retry within the same turn.
    case retry(reason: RetryReason)
    /// The reply is real but unfinished. Ask the model to continue, in this
    /// same turn, keeping the text already produced.
    case continueText(prompt: String)
    /// Shrink something (the history, or the output cap) and try once more.
    case degrade(reason: RetryReason)
    /// Stop and tell the user what happened. No further automatic attempts.
    case abort(reason: RetryReason, message: String)

    /// Whether this verdict ends the turn's automatic handling.
    public var isTerminal: Bool {
        switch self {
        case .accept, .continueText:
            return false
        case .retry, .degrade:
            return true
        case .abort:
            return true
        }
    }

    /// The reason, when the verdict carries one.
    public var reason: RetryReason? {
        switch self {
        case .accept, .continueText:
            return nil
        case .retry(let reason), .degrade(let reason):
            return reason
        case .abort(let reason, _):
            return reason
        }
    }

    /// User-facing text. Only abort produces one: everything else is handled
    /// transparently, because a reply that recovers itself should not make the
    /// user think anything went wrong.
    public var userMessage: String? {
        switch self {
        case .abort(_, let message):
            return message
        case .accept, .retry, .continueText, .degrade:
            return nil
        }
    }
}

/// The reply under inspection, reduced to the facts the guards need.
public struct ReplyFacts: Sendable, Equatable {
    /// Flattened text of the reply, whitespace-trimmed.
    public let text: String
    /// The provider's finish reason, verbatim (= "stop", "length", "tool_use",
    /// "content_filter", or whatever the provider calls it).
    public let finishReason: String
    /// Whether the reply asked for at least one tool call.
    public let hasToolCalls: Bool
    /// Whether the reply came back as an error rather than content.
    public let error: RetryReason?
    /// Fraction of the context window the prompt occupied, when known.
    public let promptFraction: Double?

    public init(
        text: String = "",
        finishReason: String = "stop",
        hasToolCalls: Bool = false,
        error: RetryReason? = nil,
        promptFraction: Double? = nil
    ) {
        self.text = text
        self.finishReason = finishReason
        self.hasToolCalls = hasToolCalls
        self.error = error
        self.promptFraction = promptFraction
    }
}