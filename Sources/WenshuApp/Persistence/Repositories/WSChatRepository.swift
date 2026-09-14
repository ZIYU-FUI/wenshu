//
//  Persistence/Repositories/WSChatRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 23 of 42: WSChatRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper around the SwiftData @Model chat session layer
//  (= WSSession + WSChatMessage + WSSummary + WSSubAgentRun). The
//  pre-Phase 5 ChatSessionStore actor is deleted; this repository
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

import Foundation
import SwiftData

@MainActor
public final class WSChatRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    // MARK: - Sessions

    @discardableResult
    public func createSession(sessionID: String, title: String? = nil) throws -> WSSession {
        let session = WSSession(sessionID: sessionID, title: title)
        context.insert(session)
        try context.save()
        return session
    }

    public func getSession(sessionID: String) throws -> WSSession? {
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        return try context.fetch(descriptor).first
    }

    public func listSessions(includeArchived: Bool = false) throws -> [WSSession] {
        let descriptor: FetchDescriptor<WSSession>
        if includeArchived {
            descriptor = FetchDescriptor<WSSession>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<WSSession>(
                predicate: #Predicate { $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    // MARK: - Messages

    public func loadMessages(sessionId: String) throws -> [StoredChatMessage] {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId },
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor).map { model in
            StoredChatMessage(
                id: model.id,
                source: model.role,
                content: model.content,
                timestamp: model.createdAt,
                tokens: model.tokenCount >= 0 ? model.tokenCount : nil
            )
        }
    }

    public func append(_ message: StoredChatMessage, sessionId: String) throws {
        // Determine next position (= count + 1)
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId }
        )
        let count = try context.fetchCount(descriptor)
        let model = WSChatMessage(
            id: message.id,
            sessionID: sessionId,
            role: message.source,
            content: message.content,
            position: count,
            status: "ok"
        )
        model.tokenCount = message.tokens ?? -1
        context.insert(model)
        try context.save()
    }

    public func clear(sessionId: String) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId }
        )
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
        try context.save()
    }

    /// deleteOldMessages(sessionId:beforeTimestamp:) -> Void
    ///
    /// Phase 5 ticket 10a: replaces the deleted ChatSessionStore actor's
    /// `deleteOldMessages(sessionId:beforeTimestamp:)` method (= used by
    /// the summarization pipeline to drop pre-cutoff messages after a
    /// successful `saveSummary`). Non-transactional: SwiftData ModelContext
    /// batches all writes in a single `save()` (= the deleted actor's
    /// custom `transact` wrapper is no longer needed because SwiftData
    /// uses an internal Core Data transaction per save).
    public func deleteOldMessages(sessionId: String, beforeTimestamp: Date) throws {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId && $0.createdAt < beforeTimestamp }
        )
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
        try context.save()
    }

    /// summaryCutoffTimestamp(sessionId:keepLastN:) -> Date?
    ///
    /// Phase 5 ticket 10a: replaces the deleted ChatSessionStore actor's
    /// helper. Returns the timestamp below which messages should be
    /// summarised (= the (count - keepLastN)-th message's timestamp).
    /// Returns nil if no summarization is needed (= count <= keepLastN).
    public func summaryCutoffTimestamp(sessionId: String, keepLastN: Int) throws -> Date? {
        let total = try count(sessionId: sessionId)
        guard total > keepLastN else { return nil }
        let offset = total - keepLastN
        var descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = 1
        guard let cutoffMsg = try context.fetch(descriptor).first else { return nil }
        return cutoffMsg.createdAt
    }

    /// messagesBeforeCutoff(sessionId:cutoff:) -> [StoredChatMessage]
    ///
    /// Phase 5 ticket 10a: replaces the deleted ChatSessionStore actor's
    /// helper. Returns the pre-cutoff messages (= those to be summarised)
    /// in ASC timestamp order (= matches the deleted actor's spec).
    public func messagesBeforeCutoff(sessionId: String, cutoff: Date) throws -> [StoredChatMessage] {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId && $0.createdAt < cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let models = try context.fetch(descriptor)
        return models.map { model in
            StoredChatMessage(
                id: model.id,
                source: model.role,
                content: model.content,
                timestamp: model.createdAt,
                tokens: model.tokenCount >= 0 ? model.tokenCount : nil
            )
        }
    }

    /// summarizeIfNeeded(sessionId:lastN:threshold:verifier:) -> Bool
    ///
    /// Phase 5 ticket 10a: port of the deleted ChatSessionStore actor's
    /// `summarizeIfNeeded` (= v0.21 ticket 05 spec). When the message
    /// count exceeds `threshold`, build a prompt from pre-cutoff messages,
    /// call `verifier.chat(...)`, then save the summary + delete the
    /// pre-cutoff originals (= non-transactional because SwiftData
    /// batches all writes in a single `save()` call).
    @MainActor
    public func summarizeIfNeeded(
        sessionId: String,
        lastN: Int = 10,
        threshold: Int = 20,
        verifier: WenshuVerifier
    ) async throws -> Bool {
        let currentCount = try count(sessionId: sessionId)
        guard currentCount > threshold else { return false }
        guard let cutoff = try summaryCutoffTimestamp(sessionId: sessionId, keepLastN: lastN) else {
            return false
        }
        let oldMessages = try messagesBeforeCutoff(sessionId: sessionId, cutoff: cutoff)
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
            try saveSummary(summary, sessionId: sessionId, lastMessageId: firstOldId)
        }
        try deleteOldMessages(sessionId: sessionId, beforeTimestamp: cutoff)
        return true
    }

    public func count(sessionId: String) throws -> Int {
        let descriptor = FetchDescriptor<WSChatMessage>(
            predicate: #Predicate { $0.sessionID == sessionId }
        )
        return try context.fetchCount(descriptor)
    }

    // MARK: - Summary

    public func loadSummary(sessionId: String) throws -> String? {
        let descriptor = FetchDescriptor<WSSummary>(
            predicate: #Predicate { $0.sessionID == sessionId }
        )
        return try context.fetch(descriptor).first?.summary
    }

    public func saveSummary(_ summary: String, sessionId: String, lastMessageId: String) throws {
        let descriptor = FetchDescriptor<WSSummary>(
            predicate: #Predicate { $0.sessionID == sessionId }
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

    public func loadSubAgentRuns(sessionId: String) throws -> [SubAgentRun] {
        let descriptor = FetchDescriptor<WSSubAgentRun>(
            predicate: #Predicate { $0.sessionID == sessionId },
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

    public func recordSubAgentRun(_ run: SubAgentRun, sessionId: String) throws {
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
    public func saveContextTrick() throws {
        try context.save()
    }
}
