// AsyncDelegation.swift · WenshuApp · v0.23
//
// Source (= hermes Python): `tools/async delegation.py`.
// Reference (= canonical Python source-of-truth):
// `/Volumes/ANAN/.hermes/tools/delegate tool.py` (3,459 LOC).

import Foundation

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
    /// (= for handles created before v0.74 or in tests that don't
    /// exercise the tracker path).
    var trackerSpawnID: UUID?

    init(
        id: String = UUID().uuidString,
        agentName: String,
        userMessage: String,
        state: BackgroundDelegationState = .pending,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        result: String? = nil,
        trackerSpawnID: UUID? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.userMessage = userMessage
        self.state = state
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.result = result
        self.trackerSpawnID = trackerSpawnID
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
actor AsyncDelegationRegistry {
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
    func register(handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// attach the `AgentLifecycleTracker` spawn UUID to
    /// an existing handle. Called from `delegate(...)` immediately after
    /// `tracker.registerSpawn(...)` so the terminal-status path
    /// (`markCompleted` / `markFailed`) can route the tracker record back
    /// (= no orphan tracker records).
    func attachTrackerSpawnID(handleID: String, spawnID: UUID) {
        guard var handle = records[handleID] else { return }
        handle.trackerSpawnID = spawnID
        records[handleID] = handle
    }

    /// Update an existing handle (e.g. state transition).
    func update(_ handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
    }

    /// Get a handle by id.
    func get(id: String) -> BackgroundDelegationHandle? {
        return records[id]
    }

    /// List all running delegations (state == .running).
    func runningDelegations() -> [BackgroundDelegationHandle] {
        return records.values.filter { $0.state == .running || $0.state == .pending }
    }

    /// List recent completed delegations (FIFO, max maxRetained).
    func recentCompleted() -> [BackgroundDelegationHandle] {
        return completionQueue
            .compactMap { records[$0] }
            .filter { $0.state == .completed || $0.state == .failed }
    }

    /// Mark a delegation as completed (called when sub-agent finishes).
    func markCompleted(id: String, result: String) {
        guard var handle = records[id] else { return }
        handle.state = .completed
        handle.completedAt = Date()
        handle.result = result
        records[id] = handle
        completionQueue.append(id)
        // parallel call into AgentLifecycleTracker
        // (= Option B per AgentLifecycleTrackerDesign.md). The spawn ID
        // was captured at delegate(...) time and stored on the handle.
        if let spawnID = handle.trackerSpawnID {
            AgentLifecycleTracker.shared.markCompleted(id: spawnID, result: result)
        }
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
    func markFailed(id: String, error: String) {
        guard var handle = records[id] else { return }
        handle.state = .failed
        handle.completedAt = Date()
        handle.result = "(failed: \(error))"
        records[id] = handle
        completionQueue.append(id)
        // parallel call into AgentLifecycleTracker.
        if let spawnID = handle.trackerSpawnID {
            AgentLifecycleTracker.shared.markFailed(id: spawnID, error: error)
        }
        emit(AsyncDelegationProgress(
            handleID: id,
            agentName: handle.agentName,
            state: .failed,
            detail: error
        ))
    }

    /// Cleanup old records beyond retention period.
    func cleanup() {
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

    // MARK: - Progress stream (wenshu port wire-up)

    /// Await the next progress event (= hermes completion-queue pop).
    /// Multiple subscribers are NOT supported; one waiter at a time
    /// (= matches hermes' single-consumer pattern for the per-child
    /// progress callback).
    func next() async -> AsyncDelegationProgress {
        if !pendingProgress.isEmpty {
            return pendingProgress.removeFirst()
        }
        return await withCheckedContinuation { cont in
            progressWaiters.append(cont)
        }
    }

    /// Snapshot of currently pending progress events (= for tests).
    var pendingProgressSnapshot: [AsyncDelegationProgress] {
        pendingProgress
    }

    /// Public emit hook (= used by `delegate(...)` to surface the
    /// pre-execution `.pending` transition; markCompleted / markFailed
    /// still emit their own events via the private `emit`). Routes
    /// through the same waiter-or-queue logic as the terminal emits
    /// so live subscribers see the `.pending` event without delay.
    func emitProgress(_ progress: AsyncDelegationProgress) {
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

// MARK: - Delegate entry (wenshu port wire-up)

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
func delegate(
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
    let handle = BackgroundDelegationHandle(
        agentName: subagentProfile,
        userMessage: task,
        state: .pending
    )
    await registry.register(handle: handle)

    // parallel call into AgentLifecycleTracker (= Option B
    // per AgentLifecycleTrackerDesign.md). The tracker is a parallel source
    // of truth alongside AsyncDelegationRegistry; UI keeps reading from the
    // SwiftData-backed KanbanStore path (= zero UI change). This call site is
    // the single point where sub-agent events are produced (= both AsyncDelegation
    // + AgentLifecycleTracker read from the same call site, = no drift).
    //
    // The spawn ID is stored on the handle so markCompleted / markFailed
    // (= called later by the sub-agent runner) can route the terminal
    // status update to the same tracker record.
    let trackerSpawnID = AgentLifecycleTracker.shared.registerSpawn(
        profileSlug: subagentProfile,
        prompt: task
    )
    await registry.attachTrackerSpawnID(handleID: handle.id, spawnID: trackerSpawnID)

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

/// Shared `AsyncDelegationRegistry` (= the canonical singleton
/// for production code). The SubAgentRunner reads/writes here; =
/// DelegateResearchTool routes to here so the runner picks up
/// the handles.
///
/// Tests that need an isolated registry (= no cross-test pollution)
/// can construct a fresh `AsyncDelegationRegistry()` actor locally
/// and inject it via `delegate(..., registry: local)` directly;
/// = the delegate(...) free function takes a registry parameter
/// and does NOT touch the shared singleton. The shared singleton
/// is only used by the LLM-facing tool (`DelegateResearchTool`)
/// where the LLM cannot pass a registry (= it doesn't know about
/// actor injection).
///
/// Fix: previously `DelegateResearchTool` created a fresh registry
/// per call (= the runner never saw the handle; = the team link
/// was broken). Now the tool routes to `shared`, so the runner's
/// `drainPending()` can pick up pending handles.
extension AsyncDelegationRegistry {
    static let shared: AsyncDelegationRegistry = AsyncDelegationRegistry()
}
