//  WSChatRepository+BookSessions.swift
//
//  The book ⇄ session movement: renaming a book's conversation, and
//  deleting it.
//
//  It lives in its own file (= the repository's own convention; = the
//  predicates already live in `WSChatRepository+Predicates.swift`) for
//  two reasons: the repository's own file stays at the size it was, and
//  the two operations read as ONE story (= a book's conversation follows
//  its book) rather than as two unrelated repository methods.
//
//  ⇒ THE CHILD ROWS ARE DELETED EXPLICITLY, = NOT BY THE CASCADE RULE.
//  The `WSSession` relationships declare `deleteRule: .cascade`, but the
//  child rows never set their inverse (`WSChatMessage.session` is nil on
//  every row that `append` writes, = because `append` writes the
//  denormalized `sessionID` string and never the relationship). A
//  cascade that has no inverse to walk never fires, so the rows would
//  survive their own session. MEASURED: the delete-then-read-back test
//  failed against the cascade-only implementation.

import Foundation
import SwiftData

public extension WSChatRepository {
    /// The context these methods work through.
    ///
    /// It is `store.context` and not the repository's own private
    /// `context`: a `private` member is reachable from an extension only
    /// when the extension is in the SAME FILE, = and this file is a
    /// different one on purpose (= the repository's own file stays at
    /// the size it was). `store.context` IS the same context (= the
    /// repository's own `context` is this one, = read through the store).
    private var context: ModelContext {
        store.context
    }

    /// Delete a book's sessions, and everything that hangs off them.
    ///
    /// A book's conversation belongs to the book: when the book goes, the
    /// conversation goes with it.
    ///
    /// Every session under the book is deleted, not just one: the book
    /// is the scope, and a scope with no book behind it has nothing to
    /// say.
    ///
    /// The child rows are named here, and not left to the cascade (= see
    /// the file's own header for why):
    ///
    /// - the messages (= they carry the book's id, = so the book's
    ///   messages are exactly the rows under that id);
    /// - the summaries and the sub-agent runs (= they carry NO book id,
    ///   = only the session id, = so they are matched by the session ids
    ///   this delete took, = and only when no surviving session still
    ///   carries that id).
    ///
    /// - Parameter bookID: the book's id (= its UUID string).
    /// - Returns: how many session rows were deleted.
    @discardableResult
    func deleteSessions(bookID: String) throws -> Int {
        let bookIDLocal = bookID
        let sessionDescriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { $0.bookID == bookIDLocal }
        )
        let sessions = try store.context.fetch(sessionDescriptor)
        guard !sessions.isEmpty else { return 0 }

        // 1. The messages (= every message row carries the book's id).
        let messageDescriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.bookID == bookIDLocal }
        )
        for message in try store.context.fetch(messageDescriptor) {
            store.context.delete(message)
        }

        // 2. The session rows themselves.
        for session in sessions {
            store.context.delete(session)
        }
        try store.context.save()

        // 3. The summaries and the sub-agent runs (= they carry no book
        //    id, = so they are matched by the session ids this delete
        //    took). A session id that another book still uses is left
        //    alone (= the other book's conversation is not this book's
        //    to delete).
        let deletedSessionIDs = Set(sessions.map(\.sessionID))
        let survivingSessionIDs = try Set(
            store.context.fetch(FetchDescriptor<WSSession>()).map(\.sessionID)
        )
        let orphanedSessionIDs = deletedSessionIDs.subtracting(survivingSessionIDs)
        guard !orphanedSessionIDs.isEmpty else { return sessions.count }

        for summary in try store.context.fetch(FetchDescriptor<WSSummary>()) {
            if orphanedSessionIDs.contains(summary.sessionID) {
                store.context.delete(summary)
            }
        }
        for run in try store.context.fetch(FetchDescriptor<WSSubAgentRun>()) {
            if orphanedSessionIDs.contains(run.sessionID) {
                store.context.delete(run)
            }
        }
        try store.context.save()
        return sessions.count
    }

    /// Rename a book's session, keeping the session itself.
    ///
    /// Renaming a book renames its conversation: the session keeps its
    /// identity (= its id, = its rows, = its history), and only its title
    /// changes. The identity is what the messages point at, so replacing
    /// the session would throw the conversation away.
    ///
    /// - Parameters:
    ///   - bookID: the book's id (= its UUID string).
    ///   - title: the new title (= the book's new name).
    /// - Returns: how many session rows were renamed.
    @discardableResult
    func renameSessions(bookID: String, title: String) throws -> Int {
        let bookIDLocal = bookID
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { $0.bookID == bookIDLocal }
        )
        let sessions = try store.context.fetch(descriptor)
        var renamed = 0
        for session in sessions {
            if session.title == title {
                continue
            }
            session.title = title
            session.updatedAt = Date()
            renamed += 1
        }
        if renamed > 0 {
            try store.context.save()
        }
        return renamed
    }
}
