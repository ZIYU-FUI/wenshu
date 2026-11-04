//
//  SubAgentLedger.swift · Wenshu
//
//  The ledger of agent work.
//
//  Every explicit agent run leaves a row here: = a session tagged with
//  the agent that did the work, = a run row under it with the task, the
//  outcome and the tokens. The archive pane reads these rows; = the
//  librarian's own runs are rows too, = which is why the librarian and
//  the archive share one ledger instead of two.
//
//  The models were already there (= `WSSession.source`,
//  `WSSession.agentName`, `WSSession.parentSessionID`,
//  `WSSubAgentRun`), and so was the writer that fills them
//  (= `ConversationOps.recordSubAgentRun`); = but no run ever called
//  it, = so the ledger was always empty and the archive had nothing
//  to show. This is the piece that makes the rows exist.
//
//  Two decisions worth stating:
//
//  - A run gets its OWN session row (= not a row on the chat's
//    session). The chat and the run are different things; = the
//    archive reads the tagged rows, = so a chat and a run never land
//    in the same list.
//  - The run's session carries `parentSessionID` (= the chat that
//    asked for it), = so the archive can walk from a run back to the
//    conversation that started it.
//

import Foundation
import WenshuData

/// Writes and reads the ledger of agent work.
///
/// The writer is deliberately separate from the runner: = the runner
/// knows how to run an agent, = the ledger knows how to record that it
/// happened. = One writer for every role (= the librarian included)
/// is what makes "which runs happened" a question with one answer.
@MainActor
struct SubAgentLedger {

    /// The repository the ledger writes through.
    let repository: WSChatRepository

    init(repository: WSChatRepository) {
        self.repository = repository
    }

    // MARK: - Writing

    /// Open a run's ledger row.
    ///
    /// The row is written when the run STARTS, = not when it ends:
    /// = a run that crashes leaves a row that says it started and
    /// never finished, = which is the fact the user needs. A ledger
    /// that only learns about finished runs cannot answer "what is
    /// the agent doing right now".
    ///
    /// - Parameters:
    ///   - runID: the run's id (= the delegation handle's id; = it is
    ///     stable for the run's life).
    ///   - agentName: the agent's slug (= the role that ran).
    ///   - task: what the run was asked to do.
    ///   - parentSessionID: the chat session that asked for it
    ///     (= nil when no chat asked, = a run the user started from
    ///     the library surface).
    ///   - bookID: the book the run reads or writes.
    /// - Returns: the session id of the run's row.
    @discardableResult
    func openRun(
        runID: String,
        agentName: String,
        task: String,
        parentSessionID: String?,
        bookID: String?
    ) throws -> String {
        let sessionID = "run-\(runID)"
        // A run that re-opens its own row (= a retry with the same
        // handle id) reuses the row rather than adding a second one
        // for the same run.
        let session = try repository.createSession(
            sessionID: sessionID,
            title: task,
            bookID: bookID,
            source: WSSessionSource.subagent,
            parentSessionID: parentSessionID,
            agentName: agentName
        )
        session.title = task
        session.updatedAt = Date()
        try repository.save(session)
        return sessionID
    }

    /// Close a run's ledger row.
    ///
    /// - Parameters:
    ///   - runID: the run's id.
    ///   - status: the outcome (= the app's own vocabulary, = not a
    ///     free string, = so a second vocabulary cannot grow up
    ///     beside this one).
    ///   - output: what the run produced.
    ///   - error: what went wrong (= nil on success).
    ///   - inputTokens / outputTokens: the token usage.
    func closeRun(
        runID: String,
        status: SubAgentRunStatus,
        output: String?,
        error: String?,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        bookID: String? = nil
    ) throws {
        let sessionID = "run-\(runID)"
        guard let session = try repository.getSession(sessionID: sessionID, bookID: bookID) else {
            // The run never opened a row (= the ledger was not wired
            // for it). Nothing to close; = the caller still has its
            // own record of the outcome.
            return
        }
        let run = WSSubAgentRun(
            id: runID,
            sessionID: sessionID,
            taskDescription: session.title ?? "",
            status: status.rawValue
        )
        run.completedAt = Date()
        run.outputText = output
        run.errorMessage = error
        run.inputTokens = inputTokens
        run.outputTokens = outputTokens
        // The inverse relation: = without it the session's
        // `subAgentRuns` is empty, = and the run is a row nobody can
        // reach from the session that owns it.
        run.session = session
        session.updatedAt = Date()
        try repository.insertAndSave(run)
    }

    // MARK: - Reading

    /// The runs the ledger holds (= newest first).
    ///
    /// - Parameters:
    ///   - agentName: the agent to filter by (= nil matches every
    ///     agent).
    ///   - includeArchived: whether the archived rows are included.
    func listRuns(
        agentName: String? = nil,
        includeArchived: Bool = false
    ) throws -> [WSSession] {
        try repository.listRuns(
            source: WSSessionSource.subagent,
            agentName: agentName,
            includeArchived: includeArchived
        )
    }
}
