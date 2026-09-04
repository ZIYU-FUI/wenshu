//
//  AsyncDelegation.swift · Wenshu · v0.23 ticket 013.010 (hermes gap 9)
//                          + HERMES-PARTIAL-018 wire-up (2026-09-04)
//
// Boss 2026-08-23 decision: 'A complete overhaul, reference principle 3'.
// Source: Gythub.com/NosResearch/hermes-agent/blob/main/tools/async delegation.py
// Reference (=canonical Python source-of-truth):
// /Volumes/ANAN/.hermes/tools/delegate tool.py(3,459 LOC)
//
// You know, I'm not sure if you're gonna be able to help me.
// I'm sorry, but I'm sorry.
// When can keep working.
//
// Background Delegation Handle and Async Delegation
// No UI input in v0.23(UI integration discussed to v0.24+).
//
// Hermes-PARTIAL-018 (2026-09-04, boss OOB 'B' = port 18 partial modules):
// The emerging cross reviewer/update/ getting/ running list/
// I'm sorry, but I'm sorry, but I'm sorry.
// From the 18th partal inventory
// ...scratch/2026-09-04-hermes-agent-capabilities-inventory.md §A.3):
// 1. Deletate(...) public event — the canonical 3-arg call shape
// (=hermes delegate tool.delegate task (goal, context, tasks, ...))
// 2. Mission date - sub-agent can't call disallowed tools
// (=hermes Delegate BLONKED TOOLS→ Wenshu SubAgentPermissions)
// Progress reporting - callback fired on state transfers
// (=hermes build child process callback)
// 4. Sub-regional tracker information
// == sync, corrected by elderman == @elder man
// Result routing — callback when sub-agents
// (=hermes complement-Que push)
//
// This picket ADDS these 5 pieces without returning any emerging public
// Per Wenshu-side Wins.
// AsyncDelegationRegistry is the source of truth; delegate(...) is a
// I'm sorry, but I'm sorry, but I'm sorry.
//
// The AsyncThrowingStream API
// I'm sorry, sir.
// I'm going to take a look at this.
// The `delegate(... ) 'entry below emits
// You know, both the legacy background handsome AND a stream element so both
// I'm sorry, sir.
//

import Foundation

/// State of a background delegation.
public enum BackgroundDelegationState: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case timeout
}

/// Handle for a background sub-agent delegation.
/// Mirrors hermes delegation record.
public struct BackgroundDelegationHandle: Sendable, Equatable {
    public let id: String
    public let agentName: String
    public let userMessage: String
    public var state: BackgroundDelegationState
    public let startedAt: Date
    public var completedAt: Date?
    public var result: String?

    public init(
        id: String = UUID().uuidString,
        agentName: String,
        userMessage: String,
        state: BackgroundDelegationState = .pending,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        result: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.userMessage = userMessage
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
    }
}

/// Result of one delegated sub-agent call (= hermes `delegate_task` JSON
/// return shape, simplified to a typed struct).
///
/// The `summary` field is the per-sub-agent's final text reply (= what
/// hermes surfaces as `summary` in the JSON envelope). The `metadata`
/// carries the keys the parent agent cares about: timing, lifecycle
/// status, sub-agent name.
public struct AsyncDelegationResult: Sendable, Equatable {
    public let handle: BackgroundDelegationHandle
    public let summary: String
    public let metadata: [String: String]

    public init(
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
public struct AsyncDelegationProgress: Sendable, Equatable {
    public let handleID: String
    public let agentName: String
    public let state: BackgroundDelegationState
    public let detail: String?

    public init(
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
public enum AsyncDelegationError: Error, LocalizedError, Sendable {
    case permissionDenied(tool: String, agent: String, reason: String)
    case unknownSubAgent(name: String)
    case contextInvalid(key: String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let tool, let agent, let reason):
            return "AsyncDelegation: sub-agent '\(agent)' may not call '\(tool)' — \(reason)"
        case .unknownSubAgent(let name):
            return "AsyncDelegation: unknown sub-agent '\(name)'"
        case .contextInvalid(let key):
            return "AsyncDelegation: invalid context key '\(key)'"
        }
    }
}

/// AsyncDelegationRegistry: tracks background delegations.
/// Mirrors hermes _records (delegation_id → record dict) + completion queue.
public actor AsyncDelegationRegistry {
    private var records: [String: BackgroundDelegationHandle] = [:]
    private let maxRetained: Int = 50            // hermes _MAX_RETAINED_COMPLETED
    private let durableRetentionSeconds: TimeInterval = 7 * 24 * 60 * 60  // hermes 7 days
    private var completionQueue: [String] = []  // FIFO of completed IDs

    /// Pending progress yields (= hermes completion-queue equivalent).
    /// Subscribers awaiting the stream block on `await next()` until a
    /// progress event arrives.
    private var pendingProgress: [AsyncDelegationProgress] = []
    private var progressWaiters: [CheckedContinuation<AsyncDelegationProgress, Never>] = []

    /// Register a new background delegation.
    public func register(handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// Update an existing handle (e.g. state transition).
    public func update(_ handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// Get a handle by id.
    public func get(id: String) -> BackgroundDelegationHandle? {
        return records[id]
    }

    /// List all running delegations (state == .running).
    public func runningDelegations() -> [BackgroundDelegationHandle] {
        return records.values.filter { $0.state == .running || $0.state == .pending }
    }

    /// List recent completed delegations (FIFO, max maxRetained).
    public func recentCompleted() -> [BackgroundDelegationHandle] {
        return completionQueue
            .compactMap { records[$0] }
            .filter { $0.state == .completed || $0.state == .failed }
    }

    /// Mark a delegation as completed (called when sub-agent finishes).
    public func markCompleted(id: String, result: String) {
        guard var handle = records[id] else { return }
        handle.state = .completed
        handle.completedAt = Date()
        handle.result = result
        records[id] = handle
        completionQueue.append(id)
        emit(AsyncDelegationProgress(
            handleID: id,
            agentName: handle.agentName,
            state: .completed,
            detail: nil
        ))
        // LRU evict
        if completionQueue.count > maxRetained {
            let evicted = completionQueue.removeFirst()
            records.removeValue(forKey: evicted)
        }
    }

    /// Mark a delegation as failed.
    public func markFailed(id: String, error: String) {
        guard var handle = records[id] else { return }
        handle.state = .failed
        handle.completedAt = Date()
        handle.result = "(failed: \(error))"
        records[id] = handle
        completionQueue.append(id)
        emit(AsyncDelegationProgress(
            handleID: id,
            agentName: handle.agentName,
            state: .failed,
            detail: error
        ))
    }

    /// Cleanup old records beyond retention period.
    public func cleanup() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-durableRetentionSeconds)
        records = records.filter { _, handle in
            let referenceDate = handle.completedAt ?? handle.startedAt
            return referenceDate > cutoff
        }
        completionQueue = completionQueue.filter { id in
            records[id] != nil
        }
    }

    // MARK: - Progress stream (HERMES-PARTIAL-018 wire-up)

    /// Await the next progress event (= hermes completion-queue pop).
    /// Multiple subscribers are NOT supported; one waiter at a time
    /// (= matches hermes' single-consumer pattern for the per-child
    /// progress callback).
    public func next() async -> AsyncDelegationProgress {
        if !pendingProgress.isEmpty {
            return pendingProgress.removeFirst()
        }
        return await withCheckedContinuation { cont in
            progressWaiters.append(cont)
        }
    }

    /// Snapshot of currently pending progress events (= for tests).
    public var pendingProgressSnapshot: [AsyncDelegationProgress] {
        pendingProgress
    }

    /// Public emit hook (= used by `delegate(...)` to surface the
    /// pre-execution `.pending` transition; markCompleted / markFailed
    /// still emit their own events via the private `emit`). Routes
    /// through the same waiter-or-queue logic as the terminal emits
    /// so live subscribers see the `.pending` event without delay.
    public func emitProgress(_ progress: AsyncDelegationProgress) {
        emit(progress)
    }

    private func emit(_ progress: AsyncDelegationProgress) {
        if let waiter = progressWaiters.first {
            progressWaiters.removeFirst()
            waiter.resume(returning: progress)
        } else {
            pendingProgress.append(progress)
        }
    }
}

// MARK: - Delegate entry (HERMES-PARTIAL-018 wire-up)

/// Public delegate entry (= hermes `delegate_task(goal, context, tasks, ...)`).
///
/// Performs:
///   1. Permission gate — sub-agent can't call disallowed tools. The
///      `context` dict's keys are validated against
///      `SubAgentPermissions.writeOnlyBlocked` (= hermes
///      DELEGATE_BLOCKED_TOOLS parity). Any disallowed key throws
///      `AsyncDelegationError.permissionDenied` BEFORE any sub-agent
///      spawns (= atomic gate; the parent never sees a partially-
///      registered delegation).
///   2. Sub-agent identity resolution — the `subagentProfile` string is
///      looked up against `SubAgentIdentity.Name`. Unknown name throws
///      `AsyncDelegationError.unknownSubAgent`.
///   3. Lifecycle registration — delegates to `AsyncDelegationRegistry`
///      to register the handle, then emits a `.pending` progress event
///      (= subscribers see the spawn). The actual execution is the
///      caller's responsibility (= `register` does NOT spawn the agent;
///      the parent's `delegate(...)` invokes the sub-agent's LLM call
///      path and calls `markCompleted` / `markFailed` on the registry).
///   4. Result routing — the returned `AsyncDelegationResult` carries
///      the registered handle + the eventual summary + a metadata dict
///      for the parent to consume. The stream path (`registry.next()`)
///      remains the canonical subscription mechanism.
///
/// - Parameters:
///   - subagentProfile: The SubAgentIdentity.Name raw value
///     (= "researcher" / "writer" / etc.). Unknown names throw.
///   - task: The task prompt (= user message the sub-agent will answer).
///   - context: Optional metadata dict the parent wants the sub-agent to
///     see. Keys matching `SubAgentPermissions.writeOnlyBlocked` are
///     rejected (= the gate).
/// - Returns: AsyncDelegationResult wrapping the registered handle plus
///   an empty summary (= the parent fills the summary after invoking
///   the sub-agent and reports back via `markCompleted`).
public func delegate(
    subagentProfile: String,
    task: String,
    context: [String: String] = [:],
    registry: AsyncDelegationRegistry
) async throws -> AsyncDelegationResult {
    // 1. Sub-agent identity resolution (= hermes `_normalize_role` + name check).
    guard SubAgentIdentity.Name(rawValue: subagentProfile) != nil else {
        throw AsyncDelegationError.unknownSubAgent(name: subagentProfile)
    }

    // 2. Permission gate (= hermes DELEGATE_BLOCKED_TOOLS enforcement).
    //    Iterate every context key + check the permission layer. The
    //    "tool" name we check is the context key (= hermes convention:
    //    each context key is the tool the sub-agent would call to
    //    retrieve that piece of context, e.g. "memory", "delegate_task").
    for (tool, _) in context {
        if let reason = SubAgentPermissions.checkToolOnly(tool) {
            throw AsyncDelegationError.permissionDenied(
                tool: tool,
                agent: subagentProfile,
                reason: reason
            )
        }
    }

    // 3. Lifecycle registration.
    var handle = BackgroundDelegationHandle(
        agentName: subagentProfile,
        userMessage: task,
        state: .pending
    )
    await registry.register(handle: handle)

    // Emit .pending progress event so any subscriber sees the spawn.
    // pending is a pre-execution state (not a terminal transition) so
    // we route it through the registry's public emit hook rather than
    // piggy-backing on markCompleted/markFailed.
    await registry.emitProgress(
        AsyncDelegationProgress(
            handleID: handle.id,
            agentName: handle.agentName,
            state: .pending,
            detail: nil
        )
    )

    // 4. Result routing — return the registered handle plus an empty
    //    summary; the caller is expected to invoke the sub-agent and
    //    call `markCompleted`/`markFailed` on the registry, at which
    //    point the .pending → .running → .completed/.failed transitions
    //    are visible on the stream.
    return AsyncDelegationResult(
        handle: handle,
        summary: "",
        metadata: [
            "agent": subagentProfile,
            "registered_at": ISO8601DateFormatter().string(from: handle.startedAt)
        ]
    )
}