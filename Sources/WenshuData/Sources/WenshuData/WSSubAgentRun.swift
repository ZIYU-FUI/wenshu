//
// Persistence/WSSubAgentRun.swift · Wenshu
//
// SwiftData @Model: per-session sub-agent run (= 1↔N to WSSession;
// = e.g. the kanban tool spawns a worker agent per task).
// SwiftData migration  (= see CHANGELOG.md v0.72 section).
//

import Foundation
import SwiftData

@Model
public final class WSSubAgentRun {
    @Attribute(.unique) public var id: String
    /// FK to WSSession.sessionID (= string FK)
    public var sessionID: String
    public var taskDescription: String
    public var status: String
    public var startedAt: Date
    public var completedAt: Date?
    public var outputText: String?
    public var errorMessage: String?
    /// JSON-encoded array of tool calls (= matches hermes tool_call_log)
    public var toolCallsJSON: String?
    /// Token usage summary for this run
    public var inputTokens: Int
    public var outputTokens: Int

    /// Inverse relationship target (= declared on WSSession)
    public var session: WSSession?

    public init(id: String, sessionID: String, taskDescription: String, status: String = "queued") {
        self.id = id
        self.sessionID = sessionID
        self.taskDescription = taskDescription
        self.status = status
        self.startedAt = Date()
        self.inputTokens = 0
        self.outputTokens = 0
    }

    public func complete(output: String, outputTokens: Int) {
        self.status = "ok"
        self.outputText = output
        self.outputTokens = outputTokens
        self.completedAt = Date()
    }

    public func fail(error: String) {
        self.status = "errored"
        self.errorMessage = error
        self.completedAt = Date()
    }
}
