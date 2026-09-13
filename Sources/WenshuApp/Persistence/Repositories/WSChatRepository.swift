//
//  Persistence/Repositories/WSChatRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 23 of 42: WSChatRepository.
//  Per AGENTS.md §11.4.
//
//  Thin wrapper for ChatSessionStore actor (= v0.18 ticket 04). Covers
//  WSSession + WSChatMessage + WSSummary + WSSubAgentRun.
//
//  Domain types (= preserved 1:1 from ChatSessionStore):
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
