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
final class WSSubAgentRun {
    @Attribute(.unique) var id: String
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
