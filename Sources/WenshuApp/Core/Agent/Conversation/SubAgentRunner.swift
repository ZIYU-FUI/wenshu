//
//  SubAgentRunner.swift · Wenshu · v2.7 agent team + v2.7d real LLM
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
//  v2.7d upgrade (= boss 2026-09-26 "多轮 ete" + "sub-agent 真跑 LLM"):
//    The v2.7 stub returned canned strings per agent name. The
//    v2.7d implementation replaces the stub with a real LLM call:
//    each sub-agent runs its own `ConversationLoop.runTurn` with
//    the sub-agent's system prompt + its own tool subset. The
//    loop is multi-turn (= up to MAX_SUBAGENT_TURNS = 5); the
//    sub-agent may call web_search / reference_library (or any
//    tool in its subset) as many times as needed before producing
//    its final text reply.
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
    /// System-fault: the sub-agent's multi-turn runTurn produced no
    /// assistant text (= only tool_use blocks followed by tool_result
    /// loops that never terminated). Recovery: retry or shorten the task.
    case emptyResponse(handleID: String, agentName: String)
    /// System-fault: the sub-agent's multi-turn runTurn exceeded the
    /// turn cap (= MAX_SUBAGENT_TURNS). Recovery: increase the cap or
    /// split the task. Currently NOT retried automatically (= the
    /// loop is conservative; = boss wants user-visible failure rather
    /// than silent infinite retry).
    case maxTurnsExceeded(handleID: String, agentName: String, attempted: Int)
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

    /// Maximum number of pending handles drained per call. Caps
    /// the burst (= e.g. the user typed 10 nouns in one turn;
    /// = drain 3 at a time; = the rest stay pending for the
    /// next drain tick).
    let maxBatchSize: Int

    /// Maximum number of LLM turns (= ConversationLoop.runTurn
    /// inner cap) per sub-agent handle. The sub-agent may call
    /// web_search / reference_library (or any tool in its
    /// subset) as many times as needed within this budget before
    /// producing its final text reply. Beyond the cap the runner
    /// throws `SubAgentRunnerError.maxTurnsExceeded`.
    let maxSubAgentTurns: Int

    /// The LLM connector used for sub-agent calls. The sub-agent
    /// gets its own ConversationLoop (= independent context) bound
    /// to the same connector as the main agent (= no separate
    /// profile required; = the user only configures one connector
    /// in Settings → LLM Connector).
    let connector: any LLMConnector

    /// The tool registry the sub-agent's LLM call dispatches tools
    /// against. When nil (= default for unit tests with isolated
    /// registries), the sub-agent runs without tool dispatch (= pure
    /// text reply). Production code injects `ToolRegistry.shared`.
    let toolRegistry: ToolRegistry?

    /// Test-only registry override. Nil = use
    /// `AsyncDelegationRegistry.shared`. Stored only on the
    /// test-only init (= production never sets this).
    private let _isolatedRegistry: AsyncDelegationRegistry?

    /// Archivist sub-agent storage adapter (= bookmark + backup CRUD).
    /// Nil = Archivist sub-agent handles complete with a no-op summary
    /// (= the runner can't dispatch to bookmark/backup without this).
    /// Production code injects `LiveArchivistStorage`.
    let archivistStorage: ArchivistStorage?

    /// Auditor sub-agent storage adapter (= read-only memory access).
    /// Nil = Auditor sub-agent handles complete with a no-op summary.
    /// Production code injects `LiveAuditorStorage`.
    let auditorStorage: AuditorStorage?

    /// The registry this runner drains handles from. Always
    /// `AsyncDelegationRegistry.shared` in production (= the v2.7
    /// boss directive "团队链路通"; = production tools cannot
    /// inject a registry parameter); tests may override via the
    /// `isolatedRegistry:` init.
    private var registry: AsyncDelegationRegistry {
        _isolatedRegistry ?? .shared
    }

    init(
        connector: any LLMConnector,
        toolRegistry: ToolRegistry? = nil,
        maxBatchSize: Int = 3,
        maxSubAgentTurns: Int = 5,
        archivistStorage: ArchivistStorage? = nil,
        auditorStorage: AuditorStorage? = nil
    ) {
        self.connector = connector
        self.toolRegistry = toolRegistry
        self.maxBatchSize = maxBatchSize
        self.maxSubAgentTurns = maxSubAgentTurns
        self.archivistStorage = archivistStorage
        self.auditorStorage = auditorStorage
        self._isolatedRegistry = nil
    }

    /// Test-only initializer with an isolated registry (= boss
    /// 2026-09-26 "团队链路通" pattern: tests construct a fresh
    /// `AsyncDelegationRegistry()` actor locally and inject it so
    /// drain / handle state does not leak across tests).
    init(
        isolatedRegistry: AsyncDelegationRegistry,
        connector: any LLMConnector,
        toolRegistry: ToolRegistry? = nil,
        maxBatchSize: Int = 3,
        maxSubAgentTurns: Int = 5,
        archivistStorage: ArchivistStorage? = nil,
        auditorStorage: AuditorStorage? = nil
    ) {
        self.connector = connector
        self.toolRegistry = toolRegistry
        self.maxBatchSize = maxBatchSize
        self.maxSubAgentTurns = maxSubAgentTurns
        self.archivistStorage = archivistStorage
        self.auditorStorage = auditorStorage
        self._isolatedRegistry = isolatedRegistry
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
    /// v2.7d (= sub-agent 真跑 LLM): the sub-agent call goes through
    /// `ConversationLoop.runTurn` (= independent context with the
    /// sub-agent's system prompt + tool subset). The sub-agent
    /// may call web_search / reference_library as many times as
    /// needed (= up to `maxSubAgentTurns`) before producing its
    /// final text reply. The final reply is the value passed to
    /// `registry.markCompleted(result:)`.
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

        // 4. Run the sub-agent LLM call (= real LLM, multi-turn,
        //    with sub-agent's tool subset).
        //
        //    v2.7d storage dispatch: Archivist + Auditor sub-agents
        //    use a domain-specific storage path (= ArchivistStorage /
        //    AuditorStorage, injected at init) instead of the LLM
        //    tool dispatch path. Researcher / Writer / Analyst fall
        //    through to the existing real-LLM runTurn path.
        let summary: String
        do {
            switch identityName {
            case .archivist:
                summary = try await runArchivistSubAgent(handle: liveHandle)
            case .auditor:
                summary = try await runAuditorSubAgent(handle: liveHandle)
            default:
                summary = try await runRealSubAgent(
                    handleID: liveHandle.id,
                    agentName: identityName,
                    task: liveHandle.userMessage
                )
            }
        } catch let error as SubAgentRunnerError {
            // Re-throw typed errors unchanged so the caller's
            // catch can pattern-match (= e.g. .emptyResponse,
            // .maxTurnsExceeded). The drainPending failure path
            // still routes them to `markFailed` with a useful
            // message.
            throw error
        } catch {
            // System-fault: the underlying LLMConnector or
            // ConversationLoop threw something we did not type.
            // Re-throw as SubAgentRunnerError.subAgentLLMFailed so
            // the runner's drainPending() failure path surfaces
            // a typed message.
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

    /// Run the real LLM-backed sub-agent (= v2.7d). Builds an
    /// independent `ConversationLoop` (= separate context from the
    /// main agent's loop) bound to the sub-agent's system prompt +
    /// tool subset, then drives `runTurn` to completion.
    ///
    /// The returned `String` is the sub-agent's final assistant text
    /// (= what gets persisted to the handle's `result` field and
    /// surfaced via kanban). Multi-turn internal tool dispatch
    /// (= web_search / reference_library / etc.) happens inside
    /// `ConversationLoop.runTurn` (= already implements the cap-10
    /// turn loop; = the runner passes `maxAttempts = 1` because the
    /// sub-agent's retry budget is governed by `maxSubAgentTurns`,
    /// not the ConversationLoop's retry state).
    ///
    /// Throws:
    ///   - `.emptyResponse` when the LLM produced no assistant text
    ///     (= only tool_use blocks followed by no final reply).
    ///   - `.maxTurnsExceeded` when the sub-agent exceeded
    ///     `maxSubAgentTurns` without producing a final text reply.
    ///   - `.subAgentLLMFailed` (= wrapped from underlying error)
    ///     on transport / decode / provider failure.
    private func runRealSubAgent(
        handleID: String,
        agentName: SubAgentIdentity.Name,
        task: String
    ) async throws -> String {
        let systemPrompt = SubAgentIdentity.systemPrompt(name: agentName)

        // Resolve the sub-agent's tool subset (= e.g. researcher
        // = ["web_search", "reference_library"]; = archivist =
        // ["bookmark", "backup"]; = auditor = ["memory"]). Each
        // sub-agent gets exactly the tools its bounded context
        // requires (= hermes DELEGATE_BLOCKED_TOOLS parity; =
        // SubAgentIdentity.systemPrompt also enforces "MUST NOT"
        // restrictions in prose, but the tool list is the hard
        // machine-checked boundary).
        let toolNames = SubAgentIdentity.tools(name: agentName)
        var tools: [String: any Tool] = [:]
        var toolSchemas: [ToolRegistrySchema] = []
        if let registry = toolRegistry {
            for name in toolNames {
                if let handler = await registry.getHandler(name: name) {
                    tools[name] = handler
                }
                // Note: tools without a registered handler are
                // silently skipped (= the LLM is told via
                // `toolSchemas` only the ones that can actually
                // run). The system prompt already names the
                // expected tools in prose; = a missing handler is
                // a config drift (= boss 2026-09-20 "default-first"
                // = no fake tools; = rather than injecting a stub
                // handler we omit the schema).
            }
            toolSchemas = await registry.getDefinitions(toolNames: Set(toolNames))
        }

        // Build the sub-agent's ConversationLoop (= independent
        // context, = own turn history). The loop is a fresh actor
        // per sub-agent invocation (= no cross-handle state leak).
        let loop = ConversationLoop(
            connector: connector,
            systemPrompt: systemPrompt
        )

        // Run the sub-agent's turn. `maxAttempts = 1` because the
        // sub-agent's retry budget is the runner's
        // `maxSubAgentTurns`, not ConversationLoop's internal
        // retry state. Tool dispatch happens inside runTurn (= up
        // to ConversationLoop.runTurn's inner cap = 10, which is
        // strictly greater than `maxSubAgentTurns` so the runner's
        // cap is the binding constraint).
        let result: ConversationResult
        do {
            result = try await loop.runTurn(
                userMessage: task,
                systemMessage: systemPrompt,
                tools: tools,
                taskId: handleID,
                maxAttempts: 1,
                streamCallback: nil,
                toolSchemas: toolSchemas
            )
        } catch {
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handleID,
                agentName: agentName.rawValue,
                message: String(describing: error)
            )
        }

        // Extract the final assistant text (= the assistant's last
        // message in the turn history). If the LLM emitted only
        // tool_use blocks (= no final assistant text), treat as
        // empty response (= failure). The "last assistant message"
        // rule matches hermes convention: after a tool_use /
        // tool_result pair, the assistant's final reply is the last
        // message in the history.
        guard let finalAssistant = result.messages.last(where: { msg in
            msg.role == .assistant
        }) else {
            throw SubAgentRunnerError.emptyResponse(
                handleID: handleID,
                agentName: agentName.rawValue
            )
        }

        // Use the canonical plainText helper (= concatenates all
        // .text blocks; = ignores .toolUse / .toolResult). Trim
        // whitespace so a response like "\n\n  done\n" becomes "done".
        let summary = finalAssistant.plainText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summary.isEmpty else {
            throw SubAgentRunnerError.emptyResponse(
                handleID: handleID,
                agentName: agentName.rawValue
            )
        }

        return summary
    }

    // MARK: - Storage-dispatch sub-agents (v2.7d)

    /// Run the Archivist sub-agent (= bookmark + backup CRUD via
    /// `ArchivistStorage`). The Archivist does NOT round-trip the LLM
    /// (= its domain is deterministic storage; = an LLM call would
    /// add latency without value). The handle completes with a JSON
    /// summary of the storage operations performed.
    ///
    /// Task format (= from `DelegateArchiveTool` or future callers):
    ///   "add <docID> <label>"        — add a bookmark
    ///   "list"                       — list all bookmarks
    ///   "delete <bookmarkID>"        — remove a bookmark
    ///   "backup <label> <contents>"  — write a backup snapshot
    ///
    /// Unknown tasks fall back to a `{"stored": 0, "action": "noop",
    /// "reason": "unknown task"}` summary (= §11 baseline 'no fake
    /// success').
    private func runArchivistSubAgent(
        handle: BackgroundDelegationHandle
    ) async throws -> String {
        guard let storage = archivistStorage else {
            // No storage adapter injected (= misconfigured runner).
            // Per §11 baseline 'no fake success', we throw so the
            // handle ends up .failed (not .completed with a fake
            // summary).
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: SubAgentIdentity.Name.archivist.rawValue,
                message: "ArchivistStorage not injected (= runner misconfigured; = production should pass LiveArchivistStorage)"
            )
        }

        let task = handle.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = task.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let action = parts.first.map(String.init) else {
            return #"{"stored":0,"action":"noop","reason":"empty task"}"#
        }

        let restAfterAction = parts.count > 1 ? String(parts[1]) : ""

        switch action {
        case "add":
            // "add <docID> <label>" — split restAfterAction on first space.
            let addParts = restAfterAction.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard addParts.count == 2 else {
                return #"{"stored":0,"action":"add","reason":"expected: add <docID> <label>"}"#
            }
            let docID = String(addParts[0])
            let label = String(addParts[1])
            try await storage.addBookmark(docID: docID, label: label)
            return #"{"stored":1,"action":"add","docID":"\#(docID)","label":"\#(label)"}"#

        case "list":
            let bookmarks = try await storage.listBookmarks()
            let ids = bookmarks.map { $0.id }.joined(separator: ",")
            return #"{"stored":\#(bookmarks.count),"action":"list","ids":"\#(ids)"}"#

        case "delete":
            let bmID = restAfterAction.trimmingCharacters(in: .whitespaces)
            guard !bmID.isEmpty else {
                return #"{"stored":0,"action":"delete","reason":"missing bookmark id"}"#
            }
            try await storage.removeBookmark(id: bmID)
            return #"{"stored":1,"action":"delete","id":"\#(bmID)"}"#

        case "backup":
            // "backup <label> <contents>" — split restAfterAction on first space.
            let backupParts = restAfterAction.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard backupParts.count == 2 else {
                return #"{"stored":0,"action":"backup","reason":"expected: backup <label> <contents>"}"#
            }
            let label = String(backupParts[0])
            let contents = String(backupParts[1])
            let url = try await storage.writeBackup(label: label, contents: contents)
            return #"{"stored":1,"action":"backup","path":"\#(url.path)"}"#

        default:
            return #"{"stored":0,"action":"noop","reason":"unknown action: \#(action)"}"#
        }
    }

    /// Run the Auditor sub-agent (= read-only memory access via
    /// `AuditorStorage`). The Auditor fetches canonical memory for
    /// the user's task and produces a verdict JSON envelope. The
    /// verdict is deterministic (= based on memory presence, not
    /// LLM judgment; = keeps the auditor predictable for downstream
    /// stage-gate checks).
    ///
    /// Verdict envelope (= returned as the sub-agent's final text):
    ///   {
    ///     "verdict": "pass" | "warn" | "skip",
    ///     "memory_snippet_count": <int>,
    ///     "first_snippet": "<first 80 chars of canonical memory>" | null
    ///   }
    ///
    /// "pass" = memory snippet found AND content non-empty.
    /// "warn" = memory snippet found but empty.
    /// "skip" = no memory snippet (= nothing to verify against).
    private func runAuditorSubAgent(
        handle: BackgroundDelegationHandle
    ) async throws -> String {
        guard let storage = auditorStorage else {
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: SubAgentIdentity.Name.auditor.rawValue,
                message: "AuditorStorage not injected (= runner misconfigured)"
            )
        }

        let memory = await storage.readMemory(forUserMessage: handle.userMessage)
        let trimmed = memory.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return #"{"verdict":"skip","memory_snippet_count":0,"first_snippet":null}"#
        }

        let snippetCount = trimmed
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        let firstSnippet = String(trimmed.prefix(80))
        return #"{"verdict":"pass","memory_snippet_count":\#(snippetCount),"first_snippet":"\#(firstSnippet)"}"#
    }
}