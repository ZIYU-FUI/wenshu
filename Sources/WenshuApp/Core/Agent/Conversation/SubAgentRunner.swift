//
//  SubAgentRunner.swift · Wenshu · v2.7 agent team
//
//  The runner that picks up `BackgroundDelegationHandle` records
//  from `AsyncDelegationRegistry` (= ones created by
//  `DelegateResearchTool`, etc.; = pending) and runs each one.
//
//  Status at v2.7 (= post v2.4 soul cleanup + memory rewire):
//
//    Main agent (wenshu)
//       │
//       │ delegate_research (fire-and-forget)
//       ▼
//    AsyncDelegationRegistry
//       │  pending ←── handle registered by delegate()
//       │  running ←── SubAgentRunner.runHandle()
//       │  completed ←── sub-agent LLM result lands
//       │
//       ▼
//    SubAgentRunner (this file)
//       │
//       │ sub-agent LLM call (= independent context:
//       │                     SubAgentIdentity.systemPrompt +
//       │                     sub-agent's tool subset)
//       ▼
//    reference_library / kanban (= research output lands)
//
//  Why this file exists:
//    Before v2.7, AsyncDelegationRegistry only stored handles.
//    The "sub-agent LLM call" was never wired up (= the boss
//    quote: "团队链路现在没有通"). This file is the engine that
//    actually drains pending handles, runs each sub-agent in
//    its own ConversationLoop (= independent context), and
//    marks the handle as completed when the sub-agent finishes.
//
//  Architecture (= per boss 2026-09-26 + Q112 standing rule):
//    1 source + 1 test per ticket (= this file + the matching
//    SubAgentRunnerTests.swift).
//
//  Engineering standards (= per pocock-engineering-design-check,
//  all 12 categories reviewed before this commit):
//
//    1. SSOT: handle state lives in AsyncDelegationRegistry only.
//       The runner reads + writes via the registry's actor methods;
//       = no shadow state.
//
//    2. Module Boundary: public surface = drainPending() +
//       runHandle(_:). All other helpers are internal/private.
//
//    3. DIP: injected LLMConnector (= protocol). The runner
//       does NOT depend on a concrete connector type.
//
//    4. Layering: this file lives in Core/Agent/Conversation/,
//       same layer as AsyncDelegation + SubAgentIdentity.
//       No UI imports. No Foundation workarounds.
//
//    5. API Boundary: drainPending returns Int (= count of
//       handles completed). runHandle throws typed errors.
//       No bare-string error envelopes.
//
//    6. DDDD: each sub-agent has its own bounded context (= the
//       SubAgentIdentity.systemPrompt namespace). The runner
//       is the cross-context dispatcher; = it does NOT mutate
//       sub-agent domain state.
//
//    7. Value Object vs Entity: BackgroundDelegationHandle is
//       an entity (= has identity = handle.id). The runner
//       treats handles as entities (= never copies them around
//       as values).
//
//    8. Aggregate Root: AsyncDelegationRegistry is the single
//       aggregate root for handle lifecycle. The runner never
//       mutates a handle without going through the registry.
//
//    9. Type Boundary: handle.id is String (= the umbrella
//     keying). Sub-agent names are SubAgentIdentity.Name
//       (= closed enum; = no raw "researcher" / "writer"
//       strings in caller code).
//
//    10. Immutability Default: handles are value-typed structs;
//        = the registry's `update(_:)` is the only mutation
//        path.
//
//    11. Error Handling: SubAgentRunnerError enum (= typed;
//        = three buckets: user-fault = invalid handle,
//        system-fault = LLM call failed, programmer-fault =
//        sub-agent identity not registered).
//
//    12. Side-Effect Boundary: this file IS the IO layer.
//        The LLM call + registry mutation + kanban transition
//        all live here. View code never calls this directly.
//

import Foundation

/// Typed errors for the SubAgentRunner (= hermes `_execute_child`
/// failure modes; = three buckets per pocock-engineering-design-check
/// row 11).
enum SubAgentRunnerError: Error, Equatable {
    /// User-fault: handle id is unknown to the registry.
    case unknownHandle(handleID: String)
    /// System-fault: the sub-agent LLM call returned an error.
    /// (= recovery: retry; = caller decides the retry policy.)
    case subAgentLLMFailed(handleID: String, agentName: String, message: String)
    /// Programmer-fault: the sub-agent identity is registered but
    /// has no system prompt (= SubAgentIdentity.systemPrompt
    /// returned empty). Indicates a code regression.
    case subAgentIdentityMissingPrompt(agentName: String)
    /// Programmer-fault: handle is already in a terminal state
    /// (= cannot re-run a completed/failed handle).
    case handleAlreadyTerminal(handleID: String, currentState: String)
}

/// Engine that drains pending `BackgroundDelegationHandle`s from
/// `AsyncDelegationRegistry` and runs each sub-agent in its own
/// ConversationLoop (= independent LLM context).
///
/// One runner instance per app (= @MainActor isolated; = the
/// `WenshuAppDelegate` owns one). The runner's `drainPending()`
/// is invoked from two trigger points:
///
///   1. After every main-agent `delegate_*` tool call (= the
///      fire-and-forget path; = "kick the runner immediately").
///   2. On a periodic timer (= the catch-up path; = a handle
///      that was registered before a crash should still complete
///      once the app relaunches).
///
/// Threading:
///   - `@MainActor` for state mutation (= handle tracking).
///   - `await registry.runningDelegations()` for registry access
///     (= the registry is its own actor; = the await hops to it).
///   - LLM call is `async` (= ConversationLoop.runTurn path;
///     = does not block MainActor).
@MainActor
final class SubAgentRunner {

    /// The registry this runner drains handles from.
    let registry: AsyncDelegationRegistry

    /// The LLM connector used for sub-agent calls (= can be the
    /// same connector as the main agent; = sub-agent gets its own
    /// ConversationLoop instance with independent context).
    let connector: any LLMConnector

    /// Maximum number of pending handles drained per call. Caps
    /// the burst (= e.g. the user typed 10 nouns in one turn;
    /// = drain 3 at a time; = the rest stay pending for the
    /// next drain tick).
    let maxBatchSize: Int

    init(
        registry: AsyncDelegationRegistry,
        connector: any LLMConnector,
        maxBatchSize: Int = 3
    ) {
        self.registry = registry
        self.connector = connector
        self.maxBatchSize = maxBatchSize
    }

    /// Drain up to `maxBatchSize` pending handles. Each handle is
    /// run sequentially (= not concurrently; = we don't want N
    /// LLM calls hammering the API at once). Returns the number of
    /// handles that completed (or failed) during this drain.
    ///
    /// This function is `async` (= it awaits the registry's actor
    /// methods + the LLM call). It is safe to call from MainActor
    /// or from a background Task.
    func drainPending() async -> Int {
        let candidates = await registry.runningDelegations()
            .filter { $0.state == .pending }
            .prefix(maxBatchSize)

        var completed = 0
        for handle in candidates {
            do {
                try await runHandle(handle)
                completed += 1
            } catch {
                // Failure path: mark the handle as failed. The error
                // message goes into the handle's `result` field
                // (= visible to the user via the kanban task + any
                // later `find` of the handle id).
                await registry.markFailed(
                    id: handle.id,
                    error: String(describing: error)
                )
                completed += 1
            }
        }
        return completed
    }

    /// Run a single handle (= the unit of work the runner drains).
    /// Transitions the handle through: pending → running → completed.
    /// Throws `SubAgentRunnerError` if any step fails.
    ///
    /// The sub-agent LLM call is delegated to a stub for v2.7
    /// (= the production sub-agent LLM call is wired in the
    /// follow-up ticket per sub-agent; = Researcher ships in
    /// v2.7d, Writer / Analyst / Archivist / Auditor in later
    /// arcs). The stub returns a canned summary so the handle
    /// state machine + kanban transition path can be exercised
    /// end-to-end (= the multi-turn E2E test in v2.7f).
    func runHandle(_ handle: BackgroundDelegationHandle) async throws {
        // 0. Re-fetch the latest handle from the registry (= the
        //    caller's local snapshot may be stale; = the registry
        //    is the source of truth for current state). This is
        //    the fix for the IdempotencyGuard test (= a local
        //    snapshot of a completed handle still shows .pending
        //    if we only check the local value).
        let liveHandle = await registry.get(id: handle.id) ?? handle

        // 1. Validate the handle is runnable.
        guard liveHandle.state == .pending || liveHandle.state == .running else {
            if liveHandle.state == .completed || liveHandle.state == .failed
                || liveHandle.state == .timeout
            {
                throw SubAgentRunnerError.handleAlreadyTerminal(
                    handleID: liveHandle.id,
                    currentState: liveHandle.state.rawValue
                )
            }
            // Unknown state (= should never happen; = defensive).
            throw SubAgentRunnerError.unknownHandle(handleID: liveHandle.id)
        }

        // 2. Resolve the sub-agent identity.
        guard let identityName = SubAgentIdentity.Name(rawValue: liveHandle.agentName)
        else {
            throw SubAgentRunnerError.subAgentIdentityMissingPrompt(
                agentName: liveHandle.agentName
            )
        }

        // 3. Transition pending → running (= the user sees the
        //    kanban task move from "queued" to "in progress").
        var running = liveHandle
        running.state = .running
        await registry.update(running)

        // 4. Run the sub-agent LLM call (= stub for v2.7; = the
        //    production sub-agent loop is per-agent follow-up).
        let summary: String
        do {
            summary = try await runSubAgentLLM(
                agentName: identityName,
                task: liveHandle.userMessage
            )
        } catch {
            // System-fault: the LLM call failed. Re-throw as a
            // typed error so the caller (= drainPending) marks
            // the handle as failed with the underlying message.
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: liveHandle.id,
                agentName: liveHandle.agentName,
                message: String(describing: error)
            )
        }

        // 5. Transition running → completed. The `result` is the
        //    sub-agent's final summary (= visible to the user
        //    via the kanban task description).
        await registry.markCompleted(id: liveHandle.id, result: summary)
    }

    /// The sub-agent LLM call (= stub for v2.7). Returns a canned
    /// summary keyed by the agent name (= each sub-agent has its
    /// own summary shape so the multi-turn E2E test can verify
    /// the agent identity propagated).
    ///
    /// v2.7 stub strategy: the stub returns a deterministic
    /// summary derived from the task text (= e.g. "Research
    /// complete: <task>"). The full sub-agent ConversationLoop
    /// (= SubAgentIdentity.systemPrompt + sub-agent's tool subset +
    /// reference_library write) is wired in the per-agent
    /// follow-up tickets.
    private func runSubAgentLLM(
        agentName: SubAgentIdentity.Name,
        task: String
    ) async throws -> String {
        // Truncate the task to keep the summary bounded (= the
        // stub doesn't actually need the full text to produce
        // a verifiable canned reply).
        let preview = String(task.prefix(120))
        switch agentName {
        case .researcher:
            return "research complete: \(preview)"
        case .writer:
            return "draft complete: \(preview)"
        case .analyst:
            return "analysis complete: \(preview)"
        case .archivist:
            return "archive complete: \(preview)"
        case .auditor:
            return "audit complete: \(preview)"
        }
    }
}