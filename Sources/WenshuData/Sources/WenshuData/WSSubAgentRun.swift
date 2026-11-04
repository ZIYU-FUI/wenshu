//
// Persistence/WSSubAgentRun.swift · Wenshu
//
// SwiftData @Model: per-session sub-agent run (= 1↔N to WSSession;
// = e.g. the kanban tool spawns a worker agent per task).
// SwiftData migration  (= see CHANGELOG.md section).
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

    /// The status is required, = and not defaulted.
    ///
    /// = The default used to be "queued", = which is not one of the
    /// column's words (= the app's `SubAgentRunStatus` says running /
    /// done / failed), = so a caller that forgot the argument wrote a
    /// fourth word into a column that has three. = Making it required
    /// means every caller names a status, = and names it from the
    /// vocabulary.
    public init(id: String, sessionID: String, taskDescription: String, status: String) {
        self.id = id
        self.sessionID = sessionID
        self.taskDescription = taskDescription
        self.status = status
        self.startedAt = Date()
        self.inputTokens = 0
        self.outputTokens = 0
    }

    /// The vocabulary of this column.
    ///
    /// One column, one vocabulary. The model's own `complete` and
    /// `fail` used to write "ok" and "errored", while the ledger that
    /// writes the same column wrote "done" and "failed", and a
    /// reader (= the archive pane) had to know both. The app's own
    /// `SubAgentRunStatus` says "done" and "failed", so these are
    /// the words, and the same words the ledger writes.
    public static let statusDone = "done"
    public static let statusFailed = "failed"

    public func complete(output: String, outputTokens: Int) {
        self.status = Self.statusDone
        self.outputText = output
        self.outputTokens = outputTokens
        self.completedAt = Date()
    }

    public func fail(error: String) {
        self.status = Self.statusFailed
        self.errorMessage = error
        self.completedAt = Date()
    }
}
