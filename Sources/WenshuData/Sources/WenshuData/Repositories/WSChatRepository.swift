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
    public func createSession(
        sessionID: String,
        title: String? = nil,
        bookID: String? = nil,
        source: String? = nil,
        parentSessionID: String? = nil,
        agentName: String? = nil
    ) throws -> WSSession {
        if let existing = try getSession(sessionID: sessionID, bookID: bookID) {
            // A row that already carries the key is returned as it is,
            // but the ledger fields are filled in: = a run's row is
            // opened once and closed later, = and the second call
            // (= the close) must not lose the tag that says "this is a
            // run" and "this agent did it".
            if existing.source == nil, let source {
                existing.source = source
                existing.parentSessionID = parentSessionID
                existing.agentName = agentName
                existing.updatedAt = Date()
                try context.save()
            }
            return existing
        }
        let session = WSSession(
            sessionID: sessionID,
            title: title,
            bookID: bookID,
            source: source,
            parentSessionID: parentSessionID,
            agentName: agentName
        )
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

    /// List the sessions that record agent work (= the archive's read
    /// path).
    ///
    /// A chat session and a run are different things and must not land
    /// in the same list: = a chat carries no `source`, = a run carries
    /// one (= `WSSessionSource.subagent`). So this is the query the
    /// archive pane issues, and it is the only query that can answer
    /// "which runs happened, and which agent did each one".
    ///
    /// - Parameters:
    ///   - source: the source tag to match (= nil matches every
    ///     tagged row; = a chat row carries no tag and never appears
    ///     here).
    ///   - agentName: the agent that did the work (= nil matches every
    ///     agent).
    ///   - includeArchived: whether the archived rows are included.
    /// - Returns: the matching sessions, newest first.
    public func listRuns(
        source: String? = nil,
        agentName: String? = nil,
        includeArchived: Bool = false
    ) throws -> [WSSession] {
        let sourceLocal = source
        let agentNameLocal = agentName
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { session in
                // A row with no source is a chat, not a run.
                session.source != nil
                && (sourceLocal == nil || session.source == sourceLocal)
                && (agentNameLocal == nil || session.agentName == agentNameLocal)
                && (includeArchived || session.archivedAt == nil)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
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

    /// Save a session row (= the ledger's rows change after they are
    /// inserted: = a run's row is opened with the tag and closed with
    /// the outcome).
    public func save(_ session: WSSession) throws {
        context.insert(session)
        try context.save()
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
