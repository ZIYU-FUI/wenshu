//
//  Persistence/Repositories/WSChatRepository.swift
//
//  Migration commit 23 of 42: WSChatRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper around the SwiftData @Model chat session layer
//  (= WSSession + WSChatMessage + WSSummary + WSSubAgentRun). The
//  pre-migration ChatSessionStore actor is deleted; this repository
//  exposes the same public API surface against SwiftData instead.
//
//  Domain types (= preserved 1:1 from the deleted ChatSessionStore):
//    - StoredChatMessage: id, source, content, timestamp, tokens
//    - SubAgentRun: id, agentName, title, status, startedAt, completedAt, resultSummary
//    - SubAgentRunStatus: enum string
//
//  Implementation: SwiftData @Model WS* → Domain types.
//
//  Scope (= core CRUD; = advanced transactional semantics deferred):
//    - Session: createSession, getSession, listSessions
//    - Messages: loadMessages, append, clear, count
//    - Summary: loadSummary, saveSummary
//    - SubAgentRuns: loadSubAgentRuns, recordSubAgentRun
//
// chat-by-book row-level split ((see OOB.md #2026-09-24) OOB):
//  All session-scoped methods now accept an Optional `bookID` filter.
//    - bookID == nil  = "global un-attached" (= legacy behavior;
//      = matches the previous default; = callers that haven't been
//      updated still see all sessions).
//    - bookID == Some(id) = filter to sessions belonging to that book.
//  Callers MUST pass the current book's id (= WenshuLibrary.shared.selectedBookId)
//  so the chat panel correctly switches data when the user picks a different book.
//  The default `nil` is preserved ONLY for backward compatibility; production call
//  sites in ChatSessionViewModel are updated to pass the live bookID.

import Foundation
import SwiftData

@MainActor
public final class WSChatRepository {
    /// The store this repository reads and writes.
    ///
    /// A named container (= a test, an isolated run) is used as it is.
    /// Without one the repository reads and writes the app's live store
    /// (= the warehouse once it is activated), resolved per operation:
    /// the live store changes when the warehouse is activated, so a
    /// repository built before that moment must not keep the store it
    /// saw at construction time.
    public let store: WSStore
    private var context: ModelContext { store.context }

    public init(container: ModelContainer? = nil) {
        self.store = WSStore(container: container)
    }

    // MARK: - Sessions

    /// The session row for (= sessionID + bookID).
    ///
    /// That pair is the session's identity: one sessionID may exist
    /// under several books (= the chat-by-book design), and one book
    /// holds one row per sessionID. SwiftData has no composite unique
    /// constraint, so the key is enforced here (= fetch-then-insert): a
    /// row that already carries the key is returned as it is, and no
    /// second row is written.
    @discardableResult
    public func createSession(sessionID: String, title: String? = nil, bookID: String? = nil) throws -> WSSession {
        if let existing = try getSession(sessionID: sessionID, bookID: bookID) {
            return existing
        }
        let session = WSSession(sessionID: sessionID, title: title, bookID: bookID)
        context.insert(session)
        try context.save()
        return session
    }

    public func getSession(sessionID: String, bookID: String? = nil) throws -> WSSession? {
        let descriptor = FetchDescriptor<WSSession>(
            predicate: Self.sessionPredicate(sessionID: sessionID, bookID: bookID)
        )
        return try context.fetch(descriptor).first
    }

    public func listSessions(includeArchived: Bool = false, bookID: String? = nil) throws -> [WSSession] {
        let descriptor: FetchDescriptor<WSSession>
        if includeArchived {
            descriptor = FetchDescriptor<WSSession>(
                predicate: Self.bookIDPredicate(bookID: bookID),
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSSession>(
                predicate: Self.combinedPredicate(
                    archivedNotSet: true,
                    bookID: bookID
                ),
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    // MARK: - Messages

    public func loadMessages(sessionId: String, bookID: String? = nil) throws -> [WSChatMessage] {
        // The previous sortBy: [SortDescriptor(\.position)] was the
        // buggy path. Position is a count-then-insert int (= see
        // append()) and races when the user sends a quick 2nd message
        // before the AI's 1st reply finishes streaming. We now sort
        // by createdAt (= the caller's timestamp, stored on the row)
        // and keep position as a tiebreaker (= the same column the
        // existing fetchDescriptor was reading).
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID),
            sortBy: [
                SortDescriptor(\.createdAt, order: .forward),
                SortDescriptor(\.position, order: .forward)
            ]
        )
        let raw = try context.fetch(descriptor)
        // In-memory bookID filter (= the SwiftData #Predicate macro
        // does not reliably translate Optional<String> == nil to SQL
        // IS NULL; = we filter post-fetch). The chat message set per
        // sessionId is bounded (= O(thousands) per book); = an O(n)
        // in-memory filter is acceptable.
        if let bookID {
            let bookIDRaw = bookID
            return raw.filter { $0.bookID == bookIDRaw }
        } else {
            return raw.filter { $0.bookID == nil }
        }
    }

    public func append(
        id: String,
        source: String,
        content: String,
        tokens: Int?,
        thinking: String?,
        timestamp: Date,
        sessionId: String,
        bookID: String? = nil
    ) throws {
        // Ensure the target session exists under the requested book scope.
        // If no session exists yet (= first message of a new chat per book),
        // create it automatically (= the chat pipeline should not have to
        // manage session lifecycle separately from message appends; = the
        // caller has the bookID + sessionID, so we know the canonical key).
        //
        // previously this guard threw
        // sessionNotFoundForBookScope (= silent fail because try? in
        // ChatSessionViewModel.send); = messages stayed in memory but
        // never reached SwiftData; = chat history was empty on book switch
        // (= loadMessages returned nothing because no session row existed
        // = no messages to fetch).
        let session: WSSession
        if let existing = try getSession(sessionID: sessionId, bookID: bookID) {
            session = existing
        } else {
            session = try createSession(sessionID: sessionId, bookID: bookID)
        }
        _ = session  // unused after this line; the predicate below reads the sessionId directly
        // The row's position = the number of rows the session already
        // holds when the message is appended (= count, zero-based).
        //
        // The count + 1 pattern raced when the user sends a 2nd message
        // while the agent's 1st reply is still streaming: both appends
        // read the same count and wrote the same position, so a read
        // path that ordered by position could not break the tie. The
        // read path therefore orders by createdAt (= the caller's
        // timestamp, stored on the row) and keeps position as the
        // tiebreaker for two rows that carry the same timestamp.
        //
        // The count follows the same predicate the read path uses: for
        // a book-scoped session it counts that book's rows; for the
        // global bucket the SQL predicate cannot express IS NULL, so it
        // counts every row of that session across books. Position is a
        // tiebreaker only, so the wider count does not change the
        // order.
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID)
        )
        let count = try context.fetchCount(descriptor)
        // Denormalize bookID onto the message row (= the message.bookID
        // mirrors session.bookID; = the parent session is the source of truth).
        // Reads (= loadMessages) can then filter by message.bookID without
        // traversing the optional $0.session relationship keyPath (= which
        // has historic fragility in SwiftData #Predicate macros).
        //
        // Pre-fix bug: `BookID(rawValue: "")` produced a non-nil BookID
        // (= the empty-string sentinel), so a session-less append
        // (= bookID: nil) wrote `bookID = ""` to the message row.
        // loadMessages(_, bookID: nil) then queried `$0.bookID == nil`
        // (= the post-§11.30 §11.30 contract) and missed the message.
        // Chat history was silently dropped on the global un-attached
        // bucket.
        //
        // Fix: only fall through to session.bookID if it is non-nil;
        // otherwise leave the message row's bookID = nil (= global bucket).
        let effectiveBookID: String?
        if let bookID {
            effectiveBookID = bookID
        } else if let sessionBookIDRaw = session.bookID, !sessionBookIDRaw.isEmpty {
            effectiveBookID = sessionBookIDRaw
        } else {
            effectiveBookID = nil
        }
        let model = WSChatMessage(
            id: id,
            sessionID: sessionId,
            role: source,
            content: content,
            position: count,
            status: "ok",
            // -cleanup E2 (see OOB.md #2026-09-21) OOB 'AI ':
            // persist the reasoning text alongside the reply (= multiple
            // .reasoning parts joined by '\n\n' at the streaming boundary;
            // = the View layer decomposes it back into separate reasoning
            // parts at restore time).
            thinking: thinking,
            bookID: effectiveBookID,
            // The caller's clock, not the write clock: the caller
            // observed the message at that instant (= the app's own
            // transcript order), and a later write must not claim the
            // message happened later than it did.
            createdAt: timestamp
        )
        model.tokenCount = tokens ?? -1
        context.insert(model)
        try context.save()
    }

    public func clear(sessionId: String, bookID: String? = nil) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID)
        )
        let raw = try context.fetch(descriptor)
        // In-memory bookID filter (= same SwiftData #Predicate limitation
        // as loadMessages; = see chatMessagePredicate for the rationale).
        let filtered: [WSChatMessage]
        if let bookID {
            let bookIDRaw = bookID
            filtered = raw.filter { $0.bookID == bookIDRaw }
        } else {
            filtered = raw.filter { $0.bookID == nil }
        }
        for model in filtered {
            context.delete(model)
        }
        try context.save()
    }

    /// deleteOldMessages(sessionId:beforeTimestamp:) -> Void
    ///
    /// (= v0.72 SwiftData migration; replaces the deleted ChatSessionStore actor)
    /// `deleteOldMessages(sessionId:beforeTimestamp:)` method (= used by
    /// the summarization pipeline to drop pre-cutoff messages after a
    /// successful `saveSummary`). Non-transactional: SwiftData ModelContext
    /// batches all writes in a single `save()` (= the deleted actor's
    /// custom `transact` wrapper is no longer needed because SwiftData
    /// uses an internal Core Data transaction per save).
    public func deleteOldMessages(sessionId: String, beforeTimestamp: Date, bookID: String? = nil) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.combinedChatPredicate(
                sessionId: sessionId,
                bookID: bookID,
                createdBefore: beforeTimestamp
            )
        )
        let raw = try context.fetch(descriptor)
        // In-memory bookID filter (= see chatMessagePredicate).
        let filtered: [WSChatMessage]
        if let bookID {
            let bookIDRaw = bookID
            filtered = raw.filter { $0.bookID == bookIDRaw }
        } else {
            filtered = raw.filter { $0.bookID == nil }
        }
        for model in filtered {
            context.delete(model)
        }
        try context.save()
    }

    /// summaryCutoffTimestamp(sessionId:keepLastN:) -> Date?
    ///
    /// (= v0.72 SwiftData migration; replaces the deleted ChatSessionStore actor)
    /// helper. Returns the timestamp below which messages should be
    /// summarised (= the (count - keepLastN)-th message's timestamp).
    /// Returns nil if no summarization is needed (= count <= keepLastN).
    public func summaryCutoffTimestamp(sessionId: String, keepLastN: Int, bookID: String? = nil) throws -> Date? {
        // In-memory filter on bookID (= same SwiftData #Predicate
        // limitation as loadMessages; = see chatMessagePredicate).
        let allDescriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let raw = try context.fetch(allDescriptor)
        let filtered: [WSChatMessage]
        if let bookID {
            let bookIDRaw = bookID
            filtered = raw.filter { $0.bookID == bookIDRaw }
        } else {
            filtered = raw.filter { $0.bookID == nil }
        }
        guard filtered.count > keepLastN else { return nil }
        let offset = filtered.count - keepLastN
        return filtered[offset].createdAt
    }

    /// messagesBeforeCutoff(sessionId:cutoff:) -> [StoredChatMessage]
    ///
    /// (= v0.72 SwiftData migration; replaces the deleted ChatSessionStore actor)
    /// helper. Returns the pre-cutoff messages (= those to be summarised)
    /// in ASC timestamp order (= matches the deleted actor's spec).
    public func messagesBeforeCutoff(sessionId: String, cutoff: Date, bookID: String? = nil) throws -> [WSChatMessage] {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.combinedChatPredicate(
                sessionId: sessionId,
                bookID: bookID,
                createdBefore: cutoff
            ),
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    // summarizeIfNeeded relocated to ConversationOps. The LLM call
    // (= WenshuVerifier) and the post-summarize storage ops are business
    // logic; = they belong in app-side, not in the data layer.

    public func count(sessionId: String, bookID: String? = nil) throws -> Int {
        // Same SwiftData #Predicate limitation as loadMessages (= the
        // macro does not reliably translate Optional<String> == nil
        // to SQL IS NULL). Fetch all and filter in-memory.
        let allDescriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId }
        )
        let all = try context.fetch(allDescriptor)
        if let bookID {
            let bookIDRaw = bookID
            return all.filter { $0.bookID == bookIDRaw }.count
        }
        return all.filter { $0.bookID == nil }.count
    }

    // MARK: - Summary

    public func loadSummary(sessionId: String, bookID: String? = nil) throws -> String? {
        let descriptor = FetchDescriptor<WSSummary>(
            predicate: Self.summaryPredicate(sessionId: sessionId, bookID: bookID)
        )
        return try context.fetch(descriptor).first?.summary
    }

    public func saveSummary(_ summary: String, sessionId: String, lastMessageId: String, bookID: String? = nil) throws {
        let descriptor = FetchDescriptor<WSSummary>(
            predicate: Self.summaryPredicate(sessionId: sessionId, bookID: bookID)
        )
        if let existing = try context.fetch(descriptor).first {
            existing.summary = summary
            existing.endMessageID = lastMessageId
            existing.updatedAt = Date()
        } else {
            let model = WSSummary(
                id: UUID().uuidString,
                sessionID: sessionId,
                summary: summary,
                startMessageID: "init",
                endMessageID: lastMessageId,
                coveredTokenCount: 0,
                summaryTokenCount: 0,
                modelUsed: ""
            )
            context.insert(model)
        }
        try context.save()
    }

    // MARK: - SubAgentRuns
    // loadSubAgentRuns + recordSubAgentRun relocated to ConversationOps.
    // See Core/Agent/Conversation/ConversationOps.swift. The legacy methods
    // (= loadSubAgentRuns was dead code; = recordSubAgentRun was business
    // logic) are now implemented in app-side, not in the data layer.

    /// Save current context (= for callers that mutate model state outside the repo).
    public func saveContextTrick() throws {
        try context.save()
    }

    /// Insert a @Model + save (= small business-side helper for callers
    /// that already have a model constructed with raw fields). Replaces
    /// the legacy `recordSubAgentRun(_:)` business-logic method that
    /// lived here.
    public func insertAndSave(_ model: WSSubAgentRun) throws {
        context.insert(model)
        try context.save()
    }

    // MARK: - Predicates (chat-by-book row-level split)
    //
    // SwiftData #Predicate macros capture local variables by reference at
    // macro-expansion time, which means the predicate body cannot reference
    // a let-bound Optional computed elsewhere. Centralizing the predicate
    // builders here keeps the Optional handling (= nil = global) in one
    // place and avoids a copy-paste explosion across every FetchDescriptor.

    /// Predicate matching one session by ID + optional book scope.
    private static func sessionPredicate(sessionID: String, bookID: String?) -> Predicate<WSSession> {
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
    private static func bookIDPredicate(bookID: String?) -> Predicate<WSSession> {
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
    private static func combinedPredicate(archivedNotSet: Bool, bookID: String?) -> Predicate<WSSession> {
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
    private static func chatMessagePredicate(sessionId: String, bookID: String?) -> Predicate<WSChatMessage> {
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
    private static func combinedChatPredicate(
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
    private static func summaryPredicate(sessionId: String, bookID: String?) -> Predicate<WSSummary> {
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

// MARK: - Errors

/// Errors surfaced from chat persistence (= chat-by-book split).
/// Currently only the cross-scope guard (= append/load against a sessionID
/// that doesn't exist under the requested book scope). Adding more cases
/// here as the chat pipeline evolves; = keep the public API minimal.
public enum WSChatRepositoryError: Error, Equatable {
    case sessionNotFoundForBookScope(sessionID: String, bookID: String)
}

extension WSChatRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionNotFoundForBookScope(let sessionID, let bookID):
            return "Chat session \(sessionID) not found for book \(bookID)."
        }
    }
}
