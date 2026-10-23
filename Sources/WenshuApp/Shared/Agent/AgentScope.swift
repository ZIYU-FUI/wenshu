//
//  AgentScope.swift · Wenshu · the chat scope a delegation belongs to
//
//  WHY the scope is one value: the delegation registry is ONE instance
//  for the whole app, so a delegation that does not say which chat asked
//  for it belongs to every chat at once. The scope is written AT
//  CREATION, because a delegation that never carried it cannot be
//  recovered later.
//
//  WHY the book travels beside the session: the two session-id shapes
//  carry different information. A per-book chat's id is
//  `book:<uuid>:default` (= the book is inside it), but a brand new
//  chat's id is `s_<uuid>` (= the book is NOT). Scoping by the session
//  id alone would therefore lose the book boundary for a new chat.
//
//  WHY it lives here: the scope is read across features (= the agent
//  store and the chat store), so it is one value type in the shared
//  home rather than a loose parameter repeated per feature.
//

import WenshuData

/// The chat session and the book a delegation was created in.
struct AgentScope: Hashable, Sendable {

    /// The chat session that asked for the delegation.
    var sessionID: SessionID

    /// The book that session was reading. Nil = the session names no book.
    var bookID: BookID?

    init(sessionID: SessionID, bookID: BookID? = nil) {
        self.sessionID = sessionID
        self.bookID = bookID
    }
}
