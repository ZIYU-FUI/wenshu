//
//  Persistence/WSSubAgentRun.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 14 of 21 @Model classes: WSSubAgentRun.
//  Mirrors `sub_agent_runs` table from ChatSessionStore.swift.
//
//  1↔N to WSSession (= a chat session can spawn 0+ sub-agent runs;
//  = e.g. the kanban tool spawns a worker agent per task).
//
//  Status values (= hermes sub_agent_status enum):
//    - "queued"
//    - "running"
//    - "ok"
//    - "errored"
//    - "cancelled"

import Foundation
import SwiftData

@Model
public final class WSSubAgentRun {
    @Attribute(.unique) public var id: String
    /// FK to WSSession.sessionID (= string FK)
    var sessionID: String
    var taskDescription: String
    var status: String
    var startedAt: Date
    var completedAt: Date?
    var outputText: String?
    var errorMessage: String?
    /// JSON-encoded array of tool calls (= matches hermes tool_call_log)
    var toolCallsJSON: String?
    /// Token usage summary for this run
    var inputTokens: Int
    var outputTokens: Int

    /// Inverse relationship target (= declared on WSSession)
    var session: WSSession?

    init(id: String, sessionID: String, taskDescription: String, status: String = "queued") {
        self.id = id
        self.sessionID = sessionID
        self.taskDescription = taskDescription
        self.status = status
        self.startedAt = Date()
        self.inputTokens = 0
        self.outputTokens = 0
    }

    func complete(output: String, outputTokens: Int) {
        self.status = "ok"
        self.outputText = output
        self.outputTokens = outputTokens
        self.completedAt = Date()
    }

    func fail(error: String) {
        self.status = "errored"
        self.errorMessage = error
        self.completedAt = Date()
    }
}
