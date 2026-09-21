//
//  ChatDomain.swift · Wenshu · v0.72 SwiftData migration Phase 5 ticket 10a
//
//  Domain types for the chat feature (= preserved from the
//  now-deleted ChatSessionStore.swift actor).
//
//  History:
//    - v0.21 ticket 02: ChatSessionStore actor (= SQLite-backed;
//      = 4 tables = chat_messages + chat_summaries + chat_archives
//      + sub_agent_runs).
//    - Phase 5 ticket 10a: ChatSessionStore deleted; pure value types
//      preserved here (= no SQLite dependency). SwiftData persistence
//      lives in WSChatMessage @Model + WSChatRepository.swift.
//
//  Per AGENTS.md §11.4 SwiftData migration spec, raw sqlite3 stores
//  are being phased out (= SwiftData @Model replaces them).
//

import Foundation

/// One persisted chat message (= spec equivalent of a row in the
/// old `chat_messages` SQLite table before deletion).
///
/// Domain type preserved 1:1 from the deleted ChatSessionStore
/// (= id + source + content + timestamp + optional tokens). The
/// WSChatMessage SwiftData @Model (= Persistence/WSChatMessage.swift)
/// holds the canonical row; WSChatRepository converts between the
/// two at the repository boundary (= the View layer speaks
/// StoredChatMessage; = the persistence layer speaks WSChatMessage).
public struct StoredChatMessage: Equatable, Sendable {
    public let id: String
    public let source: String
    public let content: String
    public let timestamp: Date
    /// v0.21 ticket 34: real LLM API usage.total_tokens
    /// (= nil if not available; = legacy actor preserved this field).
    public let tokens: Int?
    // v1.65-cleanup E2 boss 2026-09-21 OOB 'AI 思考过程不显示': persisted
    // reasoning content for round-trip restore. nil = no thinking
    // (= user message, or pre-v1.65-cleanup assistant message); = non-nil
    // for assistant messages that streamed .reasoning parts during the
    // turn. Mirrors WSChatMessage.thinking on the SwiftData side.
    public let thinking: String?

    public init(
        id: String,
        source: String,
        content: String,
        timestamp: Date,
        tokens: Int? = nil,
        thinking: String? = nil
    ) {
        self.id = id
        self.source = source
        self.content = content
        self.timestamp = timestamp
        self.tokens = tokens
        self.thinking = thinking
    }
}

/// SubAgentRun: 1-line summary of one sub-agent run.
/// Domain type preserved 1:1 from the deleted ChatSessionStore.swift.
/// The WSSubAgentRun SwiftData @Model (= Persistence/WSSubAgentRun.swift)
/// holds the canonical row; WSChatRepository converts between the two
/// at the repository boundary.
public struct SubAgentRun: Equatable, Sendable {
    public let id: String
    public let agentName: String
    public let title: String
    public let status: SubAgentRunStatus
    public let startedAt: Date
    public let completedAt: Date?
    public let resultSummary: String?

    public init(
        id: String,
        agentName: String,
        title: String,
        status: SubAgentRunStatus,
        startedAt: Date,
        completedAt: Date? = nil,
        resultSummary: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.title = title
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.resultSummary = resultSummary
    }
}

/// SubAgentRunStatus: lifecycle state for one sub-agent run.
public enum SubAgentRunStatus: String, Codable, Sendable, CaseIterable {
    case running
    case done
    case failed
}
