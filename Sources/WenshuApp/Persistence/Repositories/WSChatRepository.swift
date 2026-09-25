//
//  Persistence/Repositories/WSChatRepository.swift · Wenshu · v0.72 SwiftData migration 
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
// chat-by-book row-level split (boss 2026-09-24 OOB):
//  All session-scoped methods now accept an Optional `bookID` filter.
//    - bookID == nil  = "global un-attached" (= legacy behavior;
//      = matches the pre-v1.79 default; = callers that haven't been
//      updated still see all sessions).
//    - bookID == Some(id) = filter to sessions belonging to that book.
//  Callers MUST pass the current book's id (= WenshuLibrary.shared.selectedBookId)
//  so the chat panel correctly switches data when the user picks a different book.
//  The default `nil` is preserved ONLY for backward compatibility; production call
//  sites in ChatSessionViewModel are updated to pass the live bookID.

import Foundation
import SwiftData

@MainActor
final class WSChatRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    // MARK: - Sessions

    @discardableResult
    func createSession(sessionID: String, title: String? = nil, bookID: BookID? = nil) throws -> WSSession {
        let session = WSSession(sessionID: sessionID, title: title, bookID: bookID?.rawValue)
        context.insert(session)
        try context.save()
        return session
    }

    func getSession(sessionID: String, bookID: BookID? = nil) throws -> WSSession? {
        let descriptor = FetchDescriptor<WSSession>(
            predicate: Self.sessionPredicate(sessionID: sessionID, bookID: bookID)
        )
        return try context.fetch(descriptor).first
    }

    func listSessions(includeArchived: Bool = false, bookID: BookID? = nil) throws -> [WSSession] {
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

    func loadMessages(sessionId: String, bookID: BookID? = nil) throws -> [StoredChatMessage] {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID),
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor).map { model in
            StoredChatMessage(
                id: model.id,
                source: model.role,
                content: model.content,
                timestamp: model.createdAt,
                tokens: model.tokenCount >= 0 ? model.tokenCount : nil,
                // -cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示':
                // restore the persisted reasoning content from the new
                // SwiftData column (= previously lost on reload because
                // the streaming parts[] was never persisted to disk).
                thinking: model.thinking
            )
        }
    }

    func append(_ message: StoredChatMessage, sessionId: String, bookID: BookID? = nil) throws {
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
        // Determine next position (= count + 1) within the same scope
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID)
        )
        let count = try context.fetchCount(descriptor)
        // Denormalize bookID onto the message row (= the message.bookID
        // mirrors session.bookID; = the parent session is the source of truth).
        // Reads (= loadMessages) can then filter by message.bookID without
        // traversing the optional $0.session relationship keyPath (= which
        // has historic fragility in SwiftData #Predicate macros).
        let effectiveBookID: BookID? = bookID ?? BookID(rawValue: session.bookID ?? "")
        let model = WSChatMessage(
            id: message.id,
            sessionID: sessionId,
            role: message.source,
            content: message.content,
            position: count,
            status: "ok",
            // -cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示':
            // persist the reasoning text alongside the reply (= multiple
            // .reasoning parts joined by '\n\n' at the streaming boundary;
            // = the View layer decomposes it back into separate reasoning
            // parts at restore time).
            thinking: message.thinking,
            bookID: effectiveBookID?.rawValue
        )
        model.tokenCount = message.tokens ?? -1
        context.insert(model)
        try context.save()
    }

    func clear(sessionId: String, bookID: BookID? = nil) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID)
        )
        let models = try context.fetch(descriptor)
        for model in models {
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
    func deleteOldMessages(sessionId: String, beforeTimestamp: Date, bookID: BookID? = nil) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.combinedChatPredicate(
                sessionId: sessionId,
                bookID: bookID,
                createdBefore: beforeTimestamp
            )
        )
        let models = try context.fetch(descriptor)
        for model in models {
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
    func summaryCutoffTimestamp(sessionId: String, keepLastN: Int, bookID: BookID? = nil) throws -> Date? {
        let total = try count(sessionId: sessionId, bookID: bookID)
        guard total > keepLastN else { return nil }
        let offset = total - keepLastN
        var descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID),
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = 1
        guard let cutoffMsg = try context.fetch(descriptor).first else { return nil }
        return cutoffMsg.createdAt
    }

    /// messagesBeforeCutoff(sessionId:cutoff:) -> [StoredChatMessage]
    ///
    /// (= v0.72 SwiftData migration; replaces the deleted ChatSessionStore actor)
    /// helper. Returns the pre-cutoff messages (= those to be summarised)
    /// in ASC timestamp order (= matches the deleted actor's spec).
    func messagesBeforeCutoff(sessionId: String, cutoff: Date, bookID: BookID? = nil) throws -> [StoredChatMessage] {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.combinedChatPredicate(
                sessionId: sessionId,
                bookID: bookID,
                createdBefore: cutoff
            ),
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let models = try context.fetch(descriptor)
        return models.map { model in
            StoredChatMessage(
                id: model.id,
                source: model.role,
                content: model.content,
                timestamp: model.createdAt,
                tokens: model.tokenCount >= 0 ? model.tokenCount : nil,
                // -cleanup E2: include thinking in summarize pipeline
                thinking: model.thinking
            )
        }
    }

    /// summarizeIfNeeded(sessionId:lastN:threshold:verifier:) -> Bool
    ///
    /// : port of the deleted ChatSessionStore actor's
    /// `summarizeIfNeeded` (= v0.21 ticket 05 spec). When the message
    /// count exceeds `threshold`, build a prompt from pre-cutoff messages,
    /// call `verifier.chat(...)`, then save the summary + delete the
    /// pre-cutoff originals (= non-transactional because SwiftData
    /// batches all writes in a single `save()` call).
    @MainActor
    func summarizeIfNeeded(
        sessionId: String,
        lastN: Int = 10,
        threshold: Int = 20,
        verifier: WenshuVerifier,
        bookID: BookID? = nil
    ) async throws -> Bool {
        let currentCount = try count(sessionId: sessionId, bookID: bookID)
        guard currentCount > threshold else { return false }
        guard let cutoff = try summaryCutoffTimestamp(sessionId: sessionId, keepLastN: lastN, bookID: bookID) else {
            return false
        }
        let oldMessages = try messagesBeforeCutoff(sessionId: sessionId, cutoff: cutoff, bookID: bookID)
        guard !oldMessages.isEmpty else { return false }

        // Assemble summary prompt
        let transcript = oldMessages.prefix(20).map { msg -> String in
            "[\(msg.source)] \(msg.content.prefix(100))"
        }.joined(separator: "\n")
        let summaryPrompt = """
        请用 200 字内总结以下聊天记录的关键信息 (人名 / 偏好 / 上下文 / 决定), 用中文:

        \(transcript)
        """
        let response = try await verifier.chat(summaryPrompt)
        let summary = response.content.map(\.displayText).joined()

        if let firstOldId = oldMessages.first?.id {
            try saveSummary(summary, sessionId: sessionId, lastMessageId: firstOldId, bookID: bookID)
        }
        try deleteOldMessages(sessionId: sessionId, beforeTimestamp: cutoff, bookID: bookID)
        return true
    }

    func count(sessionId: String, bookID: BookID? = nil) throws -> Int {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: Self.chatMessagePredicate(sessionId: sessionId, bookID: bookID)
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Summary

    func loadSummary(sessionId: String, bookID: BookID? = nil) throws -> String? {
        let descriptor = FetchDescriptor<WSSummary>(
            predicate: Self.summaryPredicate(sessionId: sessionId, bookID: bookID)
        )
        return try context.fetch(descriptor).first?.summary
    }

    func saveSummary(_ summary: String, sessionId: String, lastMessageId: String, bookID: BookID? = nil) throws {
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

    func loadSubAgentRuns(sessionId: String, bookID: BookID? = nil) throws -> [SubAgentRun] {
        let descriptor = FetchDescriptor<WSSubAgentRun>(
            predicate: Self.subAgentRunPredicate(sessionId: sessionId, bookID: bookID),
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return try context.fetch(descriptor).map { model in
            SubAgentRun(
                id: model.id,
                agentName: "",
                title: model.taskDescription,
                status: SubAgentRunStatus(rawValue: model.status) ?? .running,
                startedAt: model.startedAt,
                completedAt: model.completedAt,
                resultSummary: model.outputText
            )
        }
    }

    func recordSubAgentRun(_ run: SubAgentRun, sessionId: String, bookID: BookID? = nil) throws {
        let model = WSSubAgentRun(
            id: run.id,
            sessionID: sessionId,
            taskDescription: run.title,
            status: run.status.rawValue
        )
        model.completedAt = run.completedAt
        model.outputText = run.resultSummary
        context.insert(model)
        try context.save()
    }

    /// Save current context (= for callers that mutate model state outside the repo).
    func saveContextTrick() throws {
        try context.save()
    }

    // MARK: - Predicates (v1.79 chat-by-book row-level split)
    //
    // SwiftData #Predicate macros capture local variables by reference at
    // macro-expansion time, which means the predicate body cannot reference
    // a let-bound Optional computed elsewhere. Centralizing the predicate
    // builders here keeps the Optional handling (= nil = global) in one
    // place and avoids a copy-paste explosion across every FetchDescriptor.

    /// Predicate matching one session by ID + optional book scope.
    private static func sessionPredicate(sessionID: String, bookID: BookID?) -> Predicate<WSSession> {
        if let bookID {
            let bookIDRaw = bookID.rawValue
            return #Predicate { $0.sessionID == sessionID && $0.bookID == bookIDRaw }
        } else {
            return #Predicate { $0.sessionID == sessionID }
        }
    }

    /// Predicate for listing sessions, filtered by bookID only (= used when
    /// includeArchived = true so the archive flag is not in the predicate).
    private static func bookIDPredicate(bookID: BookID?) -> Predicate<WSSession> {
        if let bookID {
            let bookIDRaw = bookID.rawValue
            return #Predicate { $0.bookID == bookIDRaw }
        } else {
            // #Predicate { true } is rejected by the SwiftData macro (= the
            // predicate must reference $0); = use a trivially-true comparison
            // against a stored property that always exists.
            return #Predicate { $0.sessionID == $0.sessionID }
        }
    }

    /// Predicate combining "not archived" + bookID filter.
    private static func combinedPredicate(archivedNotSet: Bool, bookID: BookID?) -> Predicate<WSSession> {
        if let bookID {
            let bookIDRaw = bookID.rawValue
            return #Predicate { $0.archivedAt == nil && $0.bookID == bookIDRaw }
        } else {
            return #Predicate { $0.archivedAt == nil }
        }
    }

    /// Predicate for WSChatMessage keyed by sessionID + optional bookID.
    /// WSChatMessage.sessionID is the FK; the bookID filter additionally
    /// rejects cross-scope reads (= same sessionID can't exist under two
    /// books; = if you find one, it's a bug or legacy data).
    private static func chatMessagePredicate(sessionId: String, bookID: BookID?) -> Predicate<WSChatMessage> {
        if let bookID {
            let bookIDRaw = bookID.rawValue
            return #Predicate { $0.sessionID == sessionId && $0.bookID == bookIDRaw }
        } else {
            return #Predicate { $0.sessionID == sessionId }
        }
    }

    /// Predicate for WSChatMessage with a createdAt cutoff.
    private static func combinedChatPredicate(
        sessionId: String,
        bookID: BookID?,
        createdBefore: Date
    ) -> Predicate<WSChatMessage> {
        if let bookID {
            let bookIDRaw = bookID.rawValue
            return #Predicate { $0.sessionID == sessionId && $0.bookID == bookIDRaw && $0.createdAt < createdBefore }
        } else {
            return #Predicate { $0.sessionID == sessionId && $0.createdAt < createdBefore }
        }
    }

    /// WSSummary has a sessionID FK (= the parent session). bookID is not
    /// stored on WSSummary directly, so we filter via the sessionID alone
    /// (= the caller is responsible for resolving the session within the
    /// correct book scope before calling loadSummary).
    private static func summaryPredicate(sessionId: String, bookID: BookID?) -> Predicate<WSSummary> {
        // bookID is unused here on purpose (= the sessionID uniquely
        // identifies a session, and a session belongs to exactly one book).
        _ = bookID
        return #Predicate { $0.sessionID == sessionId }
    }

    /// WSSubAgentRun same as WSSummary: filter by sessionID only.
    private static func subAgentRunPredicate(sessionId: String, bookID: BookID?) -> Predicate<WSSubAgentRun> {
        _ = bookID
        return #Predicate { $0.sessionID == sessionId }
    }
}

// MARK: - Errors

/// Errors surfaced from chat persistence (= v1.79 chat-by-book split).
/// Currently only the cross-scope guard (= append/load against a sessionID
/// that doesn't exist under the requested book scope). Adding more cases
/// here as the chat pipeline evolves; = keep the public API minimal.
enum WSChatRepositoryError: Error, Equatable {
    case sessionNotFoundForBookScope(sessionID: String, bookID: String)
}

extension WSChatRepositoryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sessionNotFoundForBookScope(let sessionID, let bookID):
            return "Chat session \(sessionID) not found for book \(bookID)."
        }
    }
}
