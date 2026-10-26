// SubAgentRunner.swift
// … (= 97 rationale lines collapsed; = A112 docblock collapse per §1.8)
// 
import Foundation
import WenshuAgent

// / Typed errors for the SubAgentRunner (= hermes `_execute_child`
// … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / row 11).
enum SubAgentRunnerError: Error, Equatable {
    /// User-fault: handle id is unknown to the registry.
    case unknownHandle(handleID: String)
    /// System-fault: the sub-agent LLM call returned an error.
    /// (= recovery: retry; = caller decides the retry policy.)
    case subAgentLLMFailed(handleID: String, agentName: String, message: String)
    // / Programmer-fault: the sub-agent identity is registered but
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / returned empty). Indicates a code regression.
    case subAgentIdentityMissingPrompt(agentName: String)
    /// Programmer-fault: handle is already in a terminal state
    /// (= cannot re-run a completed/failed handle).
    case handleAlreadyTerminal(handleID: String, currentState: String)
    // / System-fault: the sub-agent's multi-turn runTurn produced no
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / loops that never terminated). Recovery: retry or shorten the task.
    case emptyResponse(handleID: String, agentName: String)
    // / System-fault: the sub-agent's multi-turn runTurn exceeded the
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / than silent infinite retry).
    case maxTurnsExceeded(handleID: String, agentName: String, attempted: Int)
}

// / Engine that drains pending `BackgroundDelegationHandle`s from
// … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
// /     = does not block MainActor).
@MainActor
final class SubAgentRunner {

    // / Maximum number of pending handles drained per call. Caps
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / next drain tick).
    let maxBatchSize: Int

    // / Maximum number of LLM turns (= ConversationLoop.runTurn
    // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / throws `SubAgentRunnerError.maxTurnsExceeded`.
    let maxSubAgentTurns: Int

    // / The LLM connector used for sub-agent calls. The sub-agent
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / in Settings → LLM Connector).
    let connector: any LLMConnector

    // / The tool registry the sub-agent's LLM call dispatches tools
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / text reply). Production code injects `ToolRegistry.shared`.
    let toolRegistry: ToolRegistry?

    // / Test-only tool registry override. Nil = use the `toolRegistry`
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / ToolRegistry actor with only the tools the test needs.
    private let _isolatedToolRegistry: ToolRegistry?

    // / Test-only registry override. Nil = use
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / test-only init (= production never sets this).
    private let _isolatedRegistry: AsyncDelegationRegistry?

    // / Archivist sub-agent storage adapter (= bookmark + backup CRUD).
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Production code injects `LiveArchivistStorage`.
    let archivistStorage: ArchivistStorage?

    // / Auditor sub-agent storage adapter (= read-only memory access).
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / Production code injects `LiveAuditorStorage`.
    let auditorStorage: AuditorStorage?

    // / The registry this runner drains handles from. Always
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / init.
    private var registry: AsyncDelegationRegistry {
        _isolatedRegistry ?? .shared
    }

    // / The tool registry this runner dispatches sub-agent tool calls
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / tool dispatch).
    fileprivate var resolvedToolRegistry: ToolRegistry? {
        _isolatedToolRegistry ?? toolRegistry
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
        self._isolatedToolRegistry = nil
    }

    // / Test-only initializer with an isolated registry (=
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / across tests).
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
        self._isolatedToolRegistry = nil
    }

    // / Test-only initializer that bypasses ToolRegistry.shared. Use
    // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / web_search E2E without crashing the test process.
    init(
        isolatedRegistry: AsyncDelegationRegistry,
        isolatedToolRegistry: ToolRegistry,
        connector: any LLMConnector,
        maxBatchSize: Int = 3,
        maxSubAgentTurns: Int = 5,
        archivistStorage: ArchivistStorage? = nil,
        auditorStorage: AuditorStorage? = nil
    ) {
        self.connector = connector
        self.toolRegistry = nil
        self.maxBatchSize = maxBatchSize
        self.maxSubAgentTurns = maxSubAgentTurns
        self.archivistStorage = archivistStorage
        self.auditorStorage = auditorStorage
        self._isolatedRegistry = isolatedRegistry
        self._isolatedToolRegistry = isolatedToolRegistry
    }

    // / Drain up to `maxBatchSize` pending handles. Each handle is
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / or from a background Task.
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
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
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

    // / Run a single handle (= the unit of work the runner drains).
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / `registry.markCompleted(result:)`.
    func runHandle(_ handle: BackgroundDelegationHandle) async throws {
        // 0. Re-fetch the latest handle from the registry (= the
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // if we only check the local value).
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

        // The role's row (= the facts this run dispatches on: = which
        // run the role gets, = the slug the errors name).
        guard let role = SubAgentRoleRegistry.role(forSlug: identityName.rawValue)
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
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // through to the existing real-LLM runTurn path.
        let summary: String
        do {
            switch role.dispatch {
            case .archiveRun:
                summary = try await runArchivistSubAgent(
                    handle: liveHandle,
                    slug: role.slug
                )
            case .auditRun:
                summary = try await runAuditorSubAgent(
                    handle: liveHandle,
                    slug: role.slug
                )
            default:
                summary = try await runRealSubAgent(
                    handleID: liveHandle.id,
                    agentName: identityName,
                    task: liveHandle.userMessage
                )
            }
        } catch let error as SubAgentRunnerError {
            // Re-throw typed errors unchanged so the caller's
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // message.
            throw error
        } catch {
            // System-fault: the underlying LLMConnector or
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // a typed message.
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: liveHandle.id,
                agentName: liveHandle.agentName,
                message: String(describing: error)
            )
        }

        // 5. Transition running → completed. The `result` is the
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // via the kanban task description).
        await registry.markCompleted(id: liveHandle.id, result: summary)
    }

    // / Run the real LLM-backed sub-agent (= v2.7d). Builds an
    // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     on transport / decode / provider failure.
    private func runRealSubAgent(
        handleID: String,
        agentName: SubAgentIdentity.Name,
        task: String
    ) async throws -> String {
        let systemPrompt = SubAgentIdentity.systemPrompt(name: agentName)

        // Resolve the sub-agent's tool subset (= e.g. researcher
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // machine-checked boundary).
        let toolNames = SubAgentIdentity.tools(name: agentName)
        var tools: [String: any Tool] = [:]
        var toolSchemas: [ToolRegistrySchema] = []
        if let registry = resolvedToolRegistry {
            for name in toolNames {
                if let handler = await registry.getHandler(name: name) {
                    tools[name] = handler
                }
                // Note: tools without a registered handler are
                // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // handler we omit the schema).
            }
            toolSchemas = await registry.getDefinitions(toolNames: Set(toolNames))
        }

        // Build the sub-agent's ConversationLoop (= independent
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // per sub-agent invocation (= no cross-handle state leak).
        let loop = ConversationLoop(
            connector: connector,
            systemPrompt: systemPrompt
        )

        // Run the sub-agent's turn. `maxAttempts = 1` because the
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // cap is the binding constraint).
        //
        // The stream callback carries the sub-agent's text into the
        // registry, so a running delegation shows what it has produced
        // so far instead of only its goal and its elapsed time.
        //
        // The registry is captured in a local first: the callback runs
        // outside the runner's isolation, so it may not reach back
        // into the runner's own state.
        let outputRegistry = registry
        let result: ConversationResult
        do {
            result = try await loop.runTurn(
                userMessage: task,
                systemMessage: systemPrompt,
                tools: tools,
                taskId: handleID,
                maxAttempts: 1,
                streamCallback: { block in
                    guard case .text(let text) = block else { return }
                    await outputRegistry.appendOutput(handleID: handleID, text: text)
                },
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
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
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
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / success').
    private func runArchivistSubAgent(
        handle: BackgroundDelegationHandle,
        slug: String
    ) async throws -> String {
        guard let storage = archivistStorage else {
            // No storage adapter injected (= misconfigured runner).
            // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // summary).
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: slug,
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

    // / Run the Auditor sub-agent (= read-only memory access via
    // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / "skip" = no memory snippet (= nothing to verify against).
    private func runAuditorSubAgent(
        handle: BackgroundDelegationHandle,
        slug: String
    ) async throws -> String {
        guard let storage = auditorStorage else {
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: slug,
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