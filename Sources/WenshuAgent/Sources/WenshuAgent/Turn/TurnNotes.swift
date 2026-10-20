// TurnNotes.swift
//
// The one-shot note channel (= hermes agent/turn_context.py::_pop_turn_note and
// its three callers).
//
// The problem it solves: something changed that the model must know about this
// turn, but writing it into the system prompt would change the cached prefix
// and invalidate the whole session's cache. Writing it into the message
// history would replay it on every later turn. The note rides the current
// user message instead, and draining clears it, so it is delivered exactly
// once and the system prompt stays byte-identical.
//
// Wenshu uses this for the chapter pointer (which changes as the user writes,
// so it cannot live in a session-scoped prompt), and for anything B2-B5 stages:
// the tool whitelist changing, a background review landing, the post-compression
// rebuild notice.
//
// Drain-on-read is the invariant, not a convenience. A note that survives its
// turn is a stale note, and a stale note is worse than no note: the model
// treats it as current.

import Foundation

/// Per-turn notes staged by the runtime and delivered once via the user
/// message.
///
/// Value type on purpose: the turn runtime owns one, stages into it, drains it,
/// and drops it. Nothing shares it, so no locking is needed and no note can be
/// observed by two turns.
public struct TurnNotes: Sendable, Equatable {
    private var pending: [String] = []

    public init() {}

    /// Queue a note for the next turn. Empty notes are dropped so a caller that
    /// stages an empty string does not leave a blank line on the message.
    public mutating func stage(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pending.append(trimmed)
    }

    /// Take everything queued, as one block, and clear the queue.
    ///
    /// Returns an empty string when nothing is queued, so the caller can append
    /// unconditionally.
    public mutating func drain() -> String {
        guard !pending.isEmpty else { return "" }
        let block = pending.joined(separator: "\n\n")
        pending.removeAll(keepingCapacity: false)
        return block
    }

    /// Whether a turn would receive anything. Lets a caller skip rebuilding a
    /// user message entirely.
    public var hasPending: Bool { !pending.isEmpty }

    /// How many notes are queued (= diagnostics, not control flow).
    public var count: Int { pending.count }
}

/// Builds the user-message text for one turn: the user's own words plus any
/// notes that must be delivered with them.
public enum TurnMessageComposer {
    /// Prefix a heading so the model reads the notes as context about the
    /// request rather than as part of what the user typed.
    static let notesHeading = "[Session state]"

    /// Join a user message and its notes.
    ///
    /// Notes go first: the model reads the state, then the request. Appending
    /// them after a long user message puts them near the cut-off position,
    /// where long-context models attend least.
    public static func compose(userMessage: String, notes: String) -> String {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else { return userMessage }
        let trimmedUser = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty else { return "\(notesHeading)\n\(trimmedNotes)" }
        return "\(notesHeading)\n\(trimmedNotes)\n\n---\n\n\(trimmedUser)"
    }
}