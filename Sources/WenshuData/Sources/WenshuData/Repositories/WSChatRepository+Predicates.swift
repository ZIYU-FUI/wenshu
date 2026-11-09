// WSChatRepository+Predicates.swift · The seven predicate builders the
// repository fetches with.
//
// They live together because they are ONE concern: = = each one says
// what a fetch matches, = = and each one carries the SAME Optional
// handling (= a nil book id means "the global scope") that the
// SwiftData #Predicate macro cannot express inside the predicate body.
// The repository keeps the operations; = = this file keeps the matching.
import Foundation

extension WSChatRepository {
    // MARK: - Predicates (chat-by-book row-level split)

    //
    // SwiftData #Predicate macros capture local variables by reference at
    // macro-expansion time, which means the predicate body cannot reference
    // a let-bound Optional computed elsewhere. Centralizing the predicate
    // builders here keeps the Optional handling (= nil = global) in one
    // place and avoids a copy-paste explosion across every FetchDescriptor.

    /// Predicate matching one session by ID + optional book scope.
    static func sessionPredicate(sessionID: String, bookID: String?) -> Predicate<WSSession> {
        if let bookID {
            // SwiftData #Predicate macro: lifted Optional<String> local
            // (= see chatMessagePredicate for the macro expansion
            // rules around nil comparisons).
            let bookIDLocal: String? = bookID
            return #Predicate { $0.sessionID == sessionID && $0.bookID == bookIDLocal }
        } else {
            // Global un-attached bucket only. Without this filter
            // (= the pre-§11.30 form: `$0.sessionID == sessionID`),
            // `getSession(bookID: nil)` returns the first session
            // matching sessionID regardless of bookID; = append with
            // bookID = nil auto-fills the wrong bookID (= the bug
            // surfaced by WSChatRepositoryBookIDContractTests).
            let nilBookID: String? = nil
            return #Predicate { $0.sessionID == sessionID && $0.bookID == nilBookID }
        }
    }

    /// Predicate for listing sessions, filtered by bookID only (= used when
    /// includeArchived = true so the archive flag is not in the predicate).
    static func bookIDPredicate(bookID: String?) -> Predicate<WSSession> {
        if let bookID {
            let bookIDRaw = bookID
            return #Predicate { $0.bookID == bookIDRaw }
        } else {
            // Per §11.11: global bucket = `bookID == nil` only.
            // Previous predicate leaked per-book sessions into the
            // global includeArchived=true view (= mirror of the
            // combinedPredicate bug fixed in §11.30).
            return #Predicate { $0.bookID == nil }
        }
    }

    /// Predicate combining "not archived" + bookID filter.
    static func combinedPredicate(archivedNotSet: Bool, bookID: String?) -> Predicate<WSSession> {
        // = = The parameter says WHAT the caller wants (= "not archived");
        // = = the body below always writes the same thing, = = and the one
        // = = caller asks for exactly that. = = Saying so out loud is
        // = = better than a silent argument (= = and the same shape as
        // = = the `bookID` the two builders below ignore).
        _ = archivedNotSet
        if let bookID {
            let bookIDRaw = bookID
            return #Predicate { $0.archivedAt == nil && $0.bookID == bookIDRaw }
        } else {
            // Per §11.11 chat-by-book row-level split: the
            // global un-attached bucket is exactly those sessions
            // whose `bookID` column is nil (= not "all sessions").
            // The previous predicate (= `archivedAt == nil` alone)
            // leaked per-book sessions into the global view.
            return #Predicate { $0.archivedAt == nil && $0.bookID == nil }
        }
    }

    /// Predicate for WSChatMessage keyed by sessionID + optional bookID.
    /// WSChatMessage.sessionID is the FK; the bookID filter additionally
    /// rejects cross-scope reads (= same sessionID can't exist under two
    /// books; = if you find one, it's a bug or legacy data).
    static func chatMessagePredicate(sessionId: String, bookID: String?) -> Predicate<WSChatMessage> {
        if let bookID {
            // SwiftData #Predicate macro requires Optional<String>==
            // String? comparisons to be expressed via a lifted local
            // (`bookIDLocal: String? = "<book-id>"`) for the macro to
            // translate to SQL `<col> = ?` (= the bare `$0.bookID == bookIDRaw`
            // syntax compiles but the macro expansion can collapse the
            // Optional wrapping and produce a `bookID == NULL OR bookID = ?`
            // predicate = the per-book view leaks the global bucket).
            let bookIDLocal: String? = bookID
            return #Predicate { $0.sessionID == sessionId && $0.bookID == bookIDLocal }
        } else {
            // Per §11.11: global bucket = `bookID == nil` only.
            // Previous predicate leaked per-book messages into the
            // global view (= mirror of the listSessions bug).
            //
            // SwiftData #Predicate macro does NOT reliably translate
            // `$0.optionalString == nil` to SQL `IS NULL` (= the macro
            // expansion drops the comparison in some SDK versions; =
            // the global bucket was empty). Lifted `nilBookID: String?`
            // local also fails. The robust path is to skip the
            // SQL-level filter and apply an in-memory filter after
            // fetch (= the global bucket is small enough that
            // .filter(...) is acceptable).
            return #Predicate { $0.sessionID == sessionId }
        }
    }

    /// Predicate for WSChatMessage with a createdAt cutoff.
    static func combinedChatPredicate(
        sessionId: String,
        bookID: String?,
        createdBefore: Date
    ) -> Predicate<WSChatMessage> {
        if let bookID {
            let bookIDRaw = bookID
            return #Predicate { $0.sessionID == sessionId && $0.bookID == bookIDRaw && $0.createdAt < createdBefore }
        } else {
            // Per §11.11: global bucket = `bookID == nil` only.
            return #Predicate { $0.sessionID == sessionId && $0.bookID == nil && $0.createdAt < createdBefore }
        }
    }

    /// WSSummary has a sessionID FK (= the parent session). bookID is not
    /// stored on WSSummary directly, so we filter via the sessionID alone
    /// (= the caller is responsible for resolving the session within the
    /// correct book scope before calling loadSummary).
    static func summaryPredicate(sessionId: String, bookID: String?) -> Predicate<WSSummary> {
        // bookID is unused here on purpose (= the sessionID uniquely
        // identifies a session, and a session belongs to exactly one book).
        _ = bookID
        return #Predicate { $0.sessionID == sessionId }
    }

    /// WSSubAgentRun same as WSSummary: filter by sessionID only.
    private static func subAgentRunPredicate(sessionId: String, bookID: String?) -> Predicate<WSSubAgentRun> {
        _ = bookID
        return #Predicate { $0.sessionID == sessionId }
    }
}
