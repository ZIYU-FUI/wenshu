//
//  Persistence/WSSession.swift · Wenshu · v0.72 SwiftData migration 
//
//   : WSSession.
//  Updated in phase 1 commit 14 to add @Relationship to WSSubAgentRun.

import Foundation
import SwiftData

@Model
final class WSSession {
    @Attribute(.unique) var sessionID: String
    var title: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
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
    // Optional + no @Attribute(.unique): the same bookID can have
    // multiple sessions. nil = global, non-nil = scoped to that book.
    var bookID: String?

    @Relationship(deleteRule: .cascade, inverse: \WSChatMessage.session)
    var messages: [WSChatMessage] = []

    @Relationship(deleteRule: .cascade, inverse: \WSSummary.session)
    var summary: WSSummary?

    @Relationship(deleteRule: .cascade, inverse: \WSSubAgentRun.session)
    var subAgentRuns: [WSSubAgentRun] = []

    init(sessionID: String, title: String? = nil, bookID: String? = nil) {
        self.sessionID = sessionID
        self.title = title
        self.bookID = bookID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func archive() {
        self.archivedAt = Date()
        self.updatedAt = Date()
    }
}
