//
//  Persistence/WSSession.swift
//
//   : WSSession.
//  Updated in phase 1 commit 14 to add @Relationship to WSSubAgentRun.

import Foundation
import SwiftData

/// The kinds of work a session can record.
///
/// Hermes keeps every conversation in ONE `sessions` table and tags
/// each row with where it came from (= `kanban` / `local` / `cli`),
/// so a delegated agent's run and a board card's work are rows of
/// the same table and are told apart by reading the tag. Wenshu
/// keeps that shape: one table, one tag.
///
/// A new kind of work is a new constant here (= the archive reads the
/// rows that carry a tag; = the kinds with no producer yet stay out
/// until their producer ships).
public enum WSSessionSource {
    /// A unit of agent work (= a delegated agent's own session).
    ///
    /// The value is the one Hermes RESERVES for the same kind of work, so
    /// a Wenshu row and a Hermes row mean the same thing: Hermes names
    /// `'subagent'` as its delegated-child source
    /// (`hermes_cli/session_listing.py:13` = `SUBAGENT_SOURCE`), and its
    /// reserved / worker delegate path stamps a child's row with it
    /// (`agent/runtime_session_child.py:32`).
    ///
    /// It is the reserved path's value, not every delegate path's: the
    /// in-process path inherits the parent's surface label instead
    /// (`agent/session_source.py:34-42` prefers the inherited
    /// `HERMES_SESSION_SOURCE` over the platform).
    ///
    /// The agent that did the work is named beside it
    /// (= `WSSession.agentName`), which is the second dimension the
    /// archive searches by.
    public static let subagent = "subagent"
}

@Model
public final class WSSession {
    /// The session id, unique per book (= the composite key
    /// sessionID + bookID).
    ///
    /// No single-column unique constraint: one session id may exist
    /// under several books (= the chat-by-book design), so the
    /// constraint would drop the row of the book it collided with.
    /// The composite key is enforced by the repository
    /// (= WSChatRepository.createSession).
    public var sessionID: String
    public var title: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?
    // chat-by-book row-level split: every chat session now belongs to
    // exactly one book OR is a global un-attached session (= used
    // for onboarding-before-book-selection chats and future "create
    // a book via chat" workflows).
    //
    // String FK by convention (= matches WSChatMessage.sessionID).
    // NOT @Relationship: we don't cascade-delete chat sessions when a
    // book is removed (= the user might want to preserve history;
    // = chat belongs to the warehouse, not the book row). The
    // WSBookRepository.deleteBook path leaves chat rows intact
    // (= orphans are intentional; = the user can re-attach).
    //
    // Optional: nil = global, non-nil = scoped to that book. The same
    // bookID can have multiple sessions.
    public var bookID: String?

    /// What kind of work this session records (= Hermes' `source`).
    ///
    /// Nil = an ordinary chat session (= the conversation the user is
    /// having). Non-nil = a unit of agent work (= a delegated agent's
    /// own session). The archive reads the rows that carry a tag, so
    /// a chat and a run never land in the same list.
    ///
    /// The column is a plain String (= the vocabulary in
    /// `WSSessionSource`), because SwiftData persists a String and not
    /// a Swift enum.
    public var source: String?

    /// The session that asked for this work (= Hermes'
    /// `parent_session_id`).
    ///
    /// Nil = the work was not requested by a chat session (= a
    /// delegation that carried no scope). The value is the parent's
    /// session id (= the id the chat itself uses), so the archive can
    /// walk from a run back to the conversation that started it.
    public var parentSessionID: String?

    /// The agent that did the work (= the archive's "which agent"
    /// dimension).
    ///
    /// Nil = the work has no named agent. The value is the sub-agent's
    /// slug (= `researcher`, `writer`, = the sub-agent identity's raw
    /// value), so a run is searchable by the agent that produced it.
    public var agentName: String?

    @Relationship(deleteRule: .cascade, inverse: \WSChatMessage.session)
    public var messages: [WSChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \WSSummary.session)
    public var summary: WSSummary?

    @Relationship(deleteRule: .cascade, inverse: \WSSubAgentRun.session)
    public var subAgentRuns: [WSSubAgentRun] = []

    public init(
        sessionID: String,
        title: String? = nil,
        bookID: String? = nil,
        source: String? = nil,
        parentSessionID: String? = nil,
        agentName: String? = nil
    ) {
        self.sessionID = sessionID
        self.title = title
        self.bookID = bookID
        self.source = source
        self.parentSessionID = parentSessionID
        self.agentName = agentName
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func archive() {
        self.archivedAt = Date()
        self.updatedAt = Date()
    }
}
