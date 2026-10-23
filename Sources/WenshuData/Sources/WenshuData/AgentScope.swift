//
//  AgentScope.swift · WenshuData · the chat scope a delegation belongs to
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
//  WHY it lives here: the scope crosses the package boundary. The agent
//  runtime package builds it from the turn's session, and the app stamps
//  it onto the delegation handle, so it lives beside the typed ids it
//  is made of (= SessionID / BookID) in the shared data package.
//

/// The chat session and the book a delegation was created in.
public struct AgentScope: Hashable, Sendable {

    /// The chat session that asked for the delegation.
    public var sessionID: SessionID

    /// The book that session was reading. Nil = the session names no book.
    public var bookID: BookID?

    public init(sessionID: SessionID, bookID: BookID? = nil) {
        self.sessionID = sessionID
        self.bookID = bookID
    }
}
