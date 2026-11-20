// AsyncDelegation.swift
//
// Source (= hermes Python): `tools/async delegation.py`.
// Reference (= canonical Python source-of-truth):
// `/Volumes/ANAN/.hermes/tools/delegate tool.py` (3,459 LOC).

import Foundation
import WenshuAgent
import WenshuData

/// AsyncDelegationRegistry: tracks background delegations.
/// Mirrors hermes _records (delegation_id → record dict) + completion queue.
actor AsyncDelegationRegistry {
    private var records: [String: BackgroundDelegationHandle] = [:]
    private let maxRetained: Int = 50 // hermes _MAX_RETAINED_COMPLETED
    private let durableRetentionSeconds: TimeInterval = 7 * 24 * 60 * 60 // hermes 7 days
    private var completionQueue: [String] = [] // FIFO of completed IDs

    /// Pending progress yields (= hermes completion-queue equivalent).
    /// Subscribers awaiting the stream block on `await next()` until a
    /// progress event arrives.
    private var pendingProgress: [AsyncDelegationProgress] = []
    private var progressWaiters: [CheckedContinuation<AsyncDelegationProgress, Never>] = []

    // MARK: - Change signal

    /// One continuation per live consumer of "the records changed".
    ///
    /// A consumer re-reads the registry itself, so the signal carries no
    /// payload and cannot go stale: it says only that the snapshot the
    /// consumer holds is no longer current.
    private var changeSubscribers: [UUID: AsyncStream<Void>.Continuation] = [:]

    /// A signal per record change, plus one for the state at subscribe
    /// time, so a consumer that starts after a run began reads the live
    /// records instead of waiting for the next change.
    ///
    /// Only the newest signal is kept: while a consumer is busy, a burst
    /// of output appends collapses into the one signal it still has to
    /// act on, so streaming costs a few reads per second and a page that
    /// sits idle costs none.
    func changes() -> AsyncStream<Void> {
        let subscriberID = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: Void.self, bufferingPolicy: .bufferingNewest(1)
        )
        changeSubscribers[subscriberID] = continuation
        continuation.yield(())
        continuation.onTermination = { _ in
            Task { await self.forgetChanges(subscriberID) }
        }
        return stream
    }

    /// Drop one consumer, called when its stream terminates, so a
    /// cancelled view task leaves nothing behind.
    private func forgetChanges(_ subscriberID: UUID) {
        changeSubscribers[subscriberID] = nil
    }

    /// Announce a record change to every live consumer.
    private func signalChanges() {
        for continuation in changeSubscribers.values {
            continuation.yield(())
        }
    }

    /// The only way a record is stored, so a change can never be written
    /// without being announced.
    private func store(_ handle: BackgroundDelegationHandle) {
        records[handle.id] = handle
        signalChanges()
    }

    /// Register a new background delegation.
    func register(handle: BackgroundDelegationHandle) {
        store(handle)
    }

    /// attach the `AgentLifecycleTracker` spawn UUID to
    /// an existing handle. Called from `delegate(...)` immediately after
    /// `tracker.registerSpawn(...)` so the terminal-status path
    /// (`markCompleted` / `markFailed`) can route the tracker record back
    /// (= no orphan tracker records).
    func attachTrackerSpawnID(handleID: String, spawnID: UUID) {
        guard var handle = records[handleID] else { return }
        handle.trackerSpawnID = spawnID
        store(handle)
    }

    /// Point a delegation at the kanban card that shows its progress.
    ///
    /// Called after the card is made, = because the card's id only
    /// exists once the card does. The runner reads it when the run ends
    /// and moves the card to where the run got to.
    func attachKanbanTaskID(handleID: String, kanbanTaskID: String) {
        guard var handle = records[handleID] else { return }
        handle.kanbanTaskID = kanbanTaskID
        store(handle)
    }

    /// How many characters of a running sub-agent's output the
    /// registry keeps. Older text falls off the front, so the tail
    /// always shows the newest words and the record stays bounded.
    static let maxOutputTailCharacters = 16384

    /// Append streamed text to a running delegation's output tail.
    ///
    /// Only the last `maxOutputTailCharacters` survive. An unknown
    /// handle id is a no-op (= the sub-agent finished, or the record
    /// was evicted, before its last block arrived).
    func appendOutput(handleID: String, text: String) {
        guard var handle = records[handleID] else { return }
        handle.outputTail += text
        if handle.outputTail.count > Self.maxOutputTailCharacters {
            handle.outputTail = String(handle.outputTail.suffix(Self.maxOutputTailCharacters))
        }
        store(handle)
    }

    // Replace a record wholesale.
    //
    // = This used to be the production way to move a handle to
    // "running", = and it was how the kanban card's id was lost: = a
    // caller took a snapshot when the run started, = and wrote that
    // snapshot back, = and the write erased every field the record
    // had gained in the meantime (= the card id, = which is attached
    // after the delegation returns).
    //
    // = It is gone, = because the runner now asks for the state
    // change it wants (= `markRunning`) = and the registry does it on
    // the record it holds now. = Removing the wholesale write is what
    // makes the loss impossible, = rather than merely tested-for.
    //
    // The test-only twin below exists so the old shape can be shown
    // in a test, = so nobody reinvents it.
    #if DEBUG
        func writeBackForTest(_ handle: BackgroundDelegationHandle) {
            store(handle)
        }
    #endif

    /// Mark a delegation as running.
    ///
    /// The state change happens on the record that is stored NOW, = not
    /// on a snapshot the caller took earlier. = The two differ
    /// because the record gains fields while the run is in flight
    /// (= the kanban card's id is attached after the delegation
    /// returns, = and the drain loop can pick the handle up in
    /// between). = A caller that wrote back its own snapshot would
    /// erase those fields, = and the card would never be moved.
    ///
    /// So the registry does the transition, = on the live record, =
    /// and only the state is touched.
    func markRunning(id: String) {
        guard var handle = records[id] else { return }
        handle.state = .running
        store(handle)
    }

    /// Record the tool the sub-agent is calling right now.
    ///
    /// A blank name clears the field (= the sub-agent stopped calling
    /// tools). An unknown handle id is a no-op (= the sub-agent finished,
    /// or the record was evicted, before its last block arrived).
    func recordCurrentTool(handleID: String, tool: String?) {
        guard var handle = records[handleID] else { return }
        let trimmed = tool?.trimmingCharacters(in: .whitespacesAndNewlines)
        handle.currentTool = (trimmed?.isEmpty == false) ? trimmed : nil
        store(handle)
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

    /// List the handles that belong to one scope, newest first.
    ///
    /// The registry is one instance for the whole app, so a caller that
    /// shows "this chat's sub-agents" must ask for exactly one scope.
    /// A handle matches only when BOTH halves match (= the session AND
    /// the book), so a delegation in another book of the same session is
    /// never returned, and a handle with no scope belongs to no scope.
    func handles(scope: AgentScope) -> [BackgroundDelegationHandle] {
        return records.values
            .filter { $0.scope == scope }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Mark a delegation as completed (called when sub-agent finishes).
    func markCompleted(id: String, result: String) {
        guard var handle = records[id] else { return }
        handle.state = .completed
        handle.completedAt = Date()
        handle.result = result
        store(handle)
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
            signalChanges()
        }
    }

    /// Mark a delegation as failed.
    func markFailed(id: String, error: String) {
        guard var handle = records[id] else { return }
        handle.state = .failed
        handle.completedAt = Date()
        handle.result = "(failed: \(error))"
        store(handle)
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
        signalChanges()
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
///   - scope: The chat session and book that asked for the delegation.
///     Nil = the caller does not know the scope (= the handle is created
///     without one). The scope is stamped onto the handle here, because
///     it is the one moment the caller still knows it.
/// - Returns: AsyncDelegationResult wrapping the registered handle plus
///   an empty summary (= the parent fills the summary after invoking
///   the sub-agent and reports back via `markCompleted`).
func delegate(
    subagentProfile: String,
    task: String,
    context: [String: String] = [:],
    registry: AsyncDelegationRegistry,
    scope: AgentScope? = nil
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
        state: .pending,
        scope: scope
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
            "registered_at": handle.startedAt.formatted(.iso8601),
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
    static let shared: AsyncDelegationRegistry = .init()
}
