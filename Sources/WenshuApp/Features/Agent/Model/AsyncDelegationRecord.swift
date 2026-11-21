// AsyncDelegationRecord.swift
//
// The record types a background sub-agent delegation is made of: its
// state, the handle the registry stores, the result it returns, the
// progress it streams, and the errors its entry point throws.
//
// They live apart from `AsyncDelegation.swift` because the registry is
// the file that announces changes, and a reader of that file should see
// the actor and its signal, not five value types ahead of it.
//
// Shapes (= hermes `delegate_task` record + result + error envelope).

import Foundation
import WenshuAgent
import WenshuData

/// State of a background delegation.
enum BackgroundDelegationState: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case timeout
}

/// Handle for a background sub-agent delegation.
/// Mirrors hermes delegation record.
struct BackgroundDelegationHandle: Sendable, Equatable {
    let id: String
    let agentName: String
    let userMessage: String
    var state: BackgroundDelegationState
    let startedAt: Date
    var completedAt: Date?
    var result: String?
    /// parallel source-of-truth identifier into
    /// `AgentLifecycleTracker.shared` (= Option B in
    /// `AgentLifecycleTrackerDesign.md`). Set via
    /// `AsyncDelegationRegistry.attachTrackerSpawnID(handleID:spawnID:)`
    /// immediately after `registerSpawn(...)`. Nil = no tracker record
    /// (= a handle registered without the tracker, or a test that does not
    /// exercise the tracker path).
    var trackerSpawnID: UUID?

    /// The chat session and book that asked for this delegation.
    ///
    /// Nil = a delegation whose scope is unknown (= it did not come from
    /// a chat turn). The scope is written AT CREATION because the
    /// registry is one instance for the whole app, so a delegation that
    /// never carried its scope belongs to every session at once and can
    /// never be recovered later.
    var scope: AgentScope?

    /// The kanban card that shows this delegation's progress.
    ///
    /// Nil = no card was made for this delegation (= most delegations
    /// are not research nouns, = and a card for each of them would be
    /// noise). A card created here and never touched
    /// again, = so it sat in "pending" forever while the research it
    /// named finished or failed. = The runner reads this id when the
    /// run ends, = and moves the card to where the run actually got
    /// to.
    var kanbanTaskID: String?

    /// The text the sub-agent has produced so far.
    ///
    /// Empty until the runner streams its first `.text` block. Only the
    /// tail is kept (= the last `maxOutputTailCharacters`), so a long
    /// run cannot grow the record without bound. The finished answer
    /// still arrives through `markCompleted` (= `result`).
    var outputTail: String

    /// The tool the sub-agent is calling right now.
    ///
    /// Nil = the sub-agent is not calling a tool (= it is thinking, or
    /// its turn is over). The field carries the tool's NAME, which is
    /// what the card shows beside the agent's name (= Hermes' sub-agent
    /// row names the tool the agent is calling, = the question a glance
    /// at the crew has to answer).
    ///
    /// The name arrives from the sub-agent's stream, whose tool-use block
    /// carries it beside the tool call's id and its input. It is written
    /// through `recordCurrentTool` because the tool changes while the
    /// delegation runs (= the record's other mutable fields change the
    /// same way).
    var currentTool: String?

    init(
        id: String = UUID().uuidString,
        agentName: String,
        userMessage: String,
        state: BackgroundDelegationState = .pending,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        result: String? = nil,
        trackerSpawnID: UUID? = nil,
        scope: AgentScope? = nil,
        kanbanTaskID: String? = nil,
        outputTail: String = "",
        currentTool: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.userMessage = userMessage
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
        self.trackerSpawnID = trackerSpawnID
        self.scope = scope
        self.kanbanTaskID = kanbanTaskID
        self.outputTail = outputTail
        self.currentTool = currentTool
    }
}

/// Result of one delegated sub-agent call (= hermes `delegate_task` JSON
/// return shape, simplified to a typed struct).
///
/// The `summary` field is the per-sub-agent's final text reply (= what
/// hermes surfaces as `summary` in the JSON envelope). The `metadata`
/// carries the keys the parent agent cares about: timing, lifecycle
/// status, sub-agent name.
struct AsyncDelegationResult: Sendable, Equatable {
    let handle: BackgroundDelegationHandle
    let summary: String
    let metadata: [String: String]

    init(
        handle: BackgroundDelegationHandle,
        summary: String,
        metadata: [String: String] = [:]
    ) {
        self.handle = handle
        self.summary = summary
        self.metadata = metadata
    }
}

/// Progress event emitted while a sub-agent runs (= hermes
/// `_build_child_progress_callback` stream shape, simplified).
///
/// Lives on the AsyncDelegationRegistry's stream so callers awaiting the
/// stream see: spawn → running → done (or failed) → cleared. The `state`
/// transitions match BackgroundDelegationHandle.state so subscribers can
/// switch on a single enum.
struct AsyncDelegationProgress: Sendable, Equatable {
    let handleID: String
    let agentName: String
    let state: BackgroundDelegationState
    let detail: String?

    init(
        handleID: String,
        agentName: String,
        state: BackgroundDelegationState,
        detail: String? = nil
    ) {
        self.handleID = handleID
        self.agentName = agentName
        self.state = state
        self.detail = detail
    }
}

/// Errors thrown by `delegate(...)` (= hermes `delegate_task` error
/// envelope, simplified).
enum AsyncDelegationError: Error, LocalizedError, Sendable {
    case permissionDenied(tool: String, agent: String, reason: String)
    case unknownSubAgent(name: String)
    case contextInvalid(key: String)

    var errorDescription: String? {
        switch self {
        case let .permissionDenied(tool, agent, reason):
            return "AsyncDelegation: sub-agent '\(agent)' may not call '\(tool)' — \(reason)"
        case let .unknownSubAgent(name):
            return "AsyncDelegation: unknown sub-agent '\(name)'"
        case let .contextInvalid(key):
            return "AsyncDelegation: invalid context key '\(key)'"
        }
    }
}
