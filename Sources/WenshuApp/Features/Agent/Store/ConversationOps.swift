//
//  ConversationOps.swift
//
//  Apple-canonical pattern (= data layer = pure SwiftData; = business
//  logic = app-side UseCase / Ops layer).
//
//  These 3 operations were previously on WSChatRepository (Persistence/):
//    - summarizeIfNeeded(...)        (= LLM call via WenshuVerifier +
//                                       saveSummary + deleteOldMessages)
//    - recordSubAgentRun(...)        (= construct SubAgentRun domain
//                                       + persist WSSubAgentRun @Model)
//    - loadSubAgentRuns(...)         (= dead code; = never called; =
//                                       removed entirely)
//
//  Now lives here (= app-side; = calls WSChatRepository for raw
//  SwiftData ops + WenshuVerifier for LLM; = no app-domain types in
//  data layer after this commit).
//
//  Per AGENTS.md §11.4 + §6.4 (Apple Backyard Birds target structure).

import Foundation
import WenshuAgent
import WenshuData

/// Business-logic ops for chat (= LLM call + chat persistence =
/// relocated from WSChatRepository). All ops are @MainActor + async to
/// match the WenshuVerifier chat path (= the LLM streaming pipeline
/// already runs on @MainActor).
@MainActor
enum ConversationOps {

    /// Summarize pre-cutoff messages (= when count exceeds threshold).
    /// Caller: ChatSessionViewModel (= via LiveChatRepository.summarizeIfNeeded).
    /// Returns true if summarization happened (= the pre-cutoff originals
    /// were deleted + summary saved); false if no work needed.
    static func summarizeIfNeeded(
        repository: WSChatRepository,
        sessionId: String,
        lastN: Int = 10,
        threshold: Int = 20,
        verifier: WenshuVerifier,
        bookID: String? = nil
    ) async throws -> Bool {
        let currentCount = try repository.count(sessionId: sessionId, bookID: bookID)
        guard currentCount > threshold else { return false }
        guard let cutoff = try repository.summaryCutoffTimestamp(
            sessionId: sessionId, keepLastN: lastN, bookID: bookID
        ) else {
            return false
        }
        let oldMessages = try repository.messagesBeforeCutoff(
            sessionId: sessionId, cutoff: cutoff, bookID: bookID
        )
        guard !oldMessages.isEmpty else { return false }

        // Assemble summary prompt (= 200-char Chinese summary of pre-cutoff
        // history; = the v0.21 ticket 05 spec contract).
        let transcript = oldMessages.prefix(20).map { msg -> String in
            "[\(msg.role)] \(msg.content.prefix(100))"
        }.joined(separator: "\n")
        let summaryPrompt = """
        请用 200 字内总结以下聊天记录的关键信息 (人名 / 偏好 / 上下文 / 决定), 用中文:

        \(transcript)
        """
        let response = try await verifier.chat(summaryPrompt)
        let summary = response.content.map(\.displayText).joined()

        if let firstOldId = oldMessages.first?.id {
            try repository.saveSummary(
                summary,
                sessionId: sessionId,
                lastMessageId: firstOldId,
                bookID: bookID
            )
        }
        try repository.deleteOldMessages(
            sessionId: sessionId, beforeTimestamp: cutoff, bookID: bookID
        )
        return true
    }

    /// Record a SubAgentRun (= business logic = construct SubAgentRun
    /// domain + persist WSSubAgentRun @Model).
    /// Caller: WenshuConductor (= sub-agent execution lifecycle).
    static func recordSubAgentRun(
        repository: WSChatRepository,
        run: SubAgentRun,
        sessionId: String,
        bookID: String? = nil
    ) throws {
        let model = WSSubAgentRun(
            id: run.id,
            sessionID: sessionId,
            taskDescription: run.title,
            status: run.status.rawValue
        )
        model.completedAt = run.completedAt
        model.outputText = run.resultSummary
        try repository.insertAndSave(model)
    }
}
