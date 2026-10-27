//
//  Persistence/WSSession.swift
//
//   : WSSession.
//  Updated in phase 1 commit 14 to add @Relationship to WSSubAgentRun.

import Foundation
import SwiftData

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

    @Relationship(deleteRule: .cascade, inverse: \WSChatMessage.session)
    public var messages: [WSChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \WSSummary.session)
    public var summary: WSSummary?

    @Relationship(deleteRule: .cascade, inverse: \WSSubAgentRun.session)
    public var subAgentRuns: [WSSubAgentRun] = []

    public init(sessionID: String, title: String? = nil, bookID: String? = nil) {
        self.sessionID = sessionID
        self.title = title
        self.bookID = bookID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public func archive() {
        self.archivedAt = Date()
        self.updatedAt = Date()
    }
}
