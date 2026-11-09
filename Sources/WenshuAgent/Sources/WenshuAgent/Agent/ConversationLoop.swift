// The conversation loop actor (= the Swift port of hermes'
// `conversation_loop.run_conversation`). This is the agent's main loop engine.
// Each user turn: 1. builds the message list (= the history plus the new user
// message). 2. invokes `LLMConnector.send(messages:options:)` (= one round-trip
// to the active connector profile). 3. appends the assistant response to the
// message list. 4. returns the result (= the response plus the full message
// history and the task id for tracing).
import Foundation

/// The agent's main loop engine. One ConversationLoop per session (= per
/// profile per Settings → LLM Connector pane) and returns the result.
public actor ConversationLoop {
    let connector: any LLMConnector
    let systemPrompt: String?

    /// The runtime state (= mock-time / verbose / debug / credential chain). It
    /// keeps the ConversationLoop actor's isolation contract intact.
    private let runtime: RuntimeHelpers

    /// Builds a ConversationLoop bound to an active LLMConnector. It reports
    /// by-step feedback in the OpenBox panel during a turn.
    public init(
        connection: any LLMConnector,
        systemPrompt: String? = nil,
        runtime: RuntimeHelpers? = nil,
        shellHookChain: ShellHookChain = ShellHookChain(),
        conversationCompression: ConversationCompression = ConversationCompression(),
        historyCompressor: HistoryCompressor = HistoryCompressor(),
        progressTracker: AgentProgressTracker = .noop,
        memoryProvider: (any MemoryProvider)? = nil
    ) {
        // Back-compat: the parameter is named `connector` everywhere in the
        // existing surface; the new parameter is named `connection` (= wenshu
        // port marker). For now we accept `connection` via this init; the legacy
        // `connector:` init remains for callers that don't need the new surface.
        // Both inits land on the same stored property below.
        connector = connection
        self.systemPrompt = systemPrompt
        self.runtime = runtime ?? RuntimeHelpers()
        self.shellHookChain = shellHookChain
        self.conversationCompression = conversationCompression
        self.historyCompressor = historyCompressor
        self.progressTracker = progressTracker
        self.memoryProvider = memoryProvider
    }

    /// The legacy initializer (= preserved for backward compatibility with the
    /// callers that predate the hermes port) with the default hook chain and
    /// compression actor.
    public init(
        connector: any LLMConnector,
        systemPrompt: String? = nil,
        runtime: RuntimeHelpers? = nil
    ) {
        self.init(
            connection: connector,
            systemPrompt: systemPrompt,
            runtime: runtime,
            shellHookChain: ShellHookChain(),
            conversationCompression: ConversationCompression(),
            progressTracker: .noop
        )
    }

    /// The shell hook chain (= the hermes port). Default = empty, so there is no
    /// behaviour change for the callers that do not register hooks.
    let shellHookChain: ShellHookChain

    /// The conversation compression actor (= the hermes port). Default = the
    /// compression actor that drops the conversation history after the
    /// compression.
    private let conversationCompression: ConversationCompression
    /// Reduces the transcript before the provider call. Injected so the
    /// budget is a construction-time decision rather than a constant read
    /// here (= see OOB.md #2026-10-20 on agent settings).
    let historyCompressor: HistoryCompressor

    /// The agent progress tracker. Default = `.noop`, so the OpenBox panel shows
    /// nothing during a conversation turn.
    private let progressTracker: AgentProgressTracker

    /// The memory provider the turn writes into. The resolver decides which one
    /// is used, and nil = the user's own backend is resolved at the call site.
    let memoryProvider: (any MemoryProvider)?

    /// Resolves the current time via the runtime (= the hermes-port Z-contract),
    /// so a caller can call the loop's clock instead of touching `Date()`
    /// directly.
    public func now() async -> Date {
        await runtime.now()
    }

    /// The history and the taskId of the turn.
    public func runTurn(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage] = [],
        tools: [String: any Tool] = [:],
        taskId: String? = nil,
        maxAttempts: Int = 3,
        settings: AgentSettings = .init(),
        requiredDeliverables: [String] = [],
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        // The tool schemas advertised to the model. Empty (= the default) means
        // the conductor advertises no tool before invoking `runTurn`.
        toolSchemas: [ToolRegistrySchema] = [],
        // The turn's output budget (= a task that writes several
        // documents needs more than a conversation; = the provider
        // counts the reasoning against the same budget).
        maxTokens: Int = 4096,
        // The thinking budget (= the tokens the model may spend on its
        // reasoning; = nil = the provider's own default).
        thinkingBudget: Int? = nil
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString
        var retry = TurnRetryState(maxAttempts: maxAttempts)

        // Start the agent progress entry for this turn. The sessionId defaults to
        // the taskId (= caller may use a richer id later; the OpenBox panel
        // matches by taskId today). The OpenBox panel polls `current(sessionId:)`
        // every render cycle.
        let sessionId = resolvedTaskId
        var progressEntry = await progressTracker.start(
            sessionId: sessionId,
            label: "Reading user message"
        )

        while retry.canRetry {
            retry.recordAttempt()
            do {
                // "Compressing context if needed". The current code path triggers
                // compression only after the LLM response (= hermes parity), so
                // this step is a no-op for now (= the tracker entry simply
                // advances past it). Future tickets that preflight-compress
                // before the LLM call can hook real work here.
                await progressTracker.advance(
                    id: progressEntry.id,
                    label: "Compressing context if needed"
                )

                // Compress before the call, not after (= hermes
                // run_turn_start_compaction). Doing it after means the provider
                // has already refused the oversized prompt, so the user waits
                // for a failure and then waits again for the recovery.
                let compressed = await compressIfNeeded(
                    messages: conversationHistory,
                    incomingMessage: userMessage,
                    systemMessage: await composeSystemPrompt(
                        override: systemMessage,
                        persistent: systemPrompt,
                        settings: settings
                    ) ?? ""
                ) ?? conversationHistory

                // "Building prompt" + "Calling LLM". Prompt construction and the
                // actual LLM round-trip both happen inside runConversation; we
                // surface this combined phase with a generous ETA (= the LLM
                // round-trip dominates wall-clock time). The ETA estimate is
                // intentionally conservative (= 8s for the calling phase) so the
                // OpenBox panel shows a realistic countdown that the next step
                // will clear.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 3,
                    label: "Building prompt",
                    etaSeconds: nil
                )
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 4,
                    label: "Calling LLM",
                    etaSeconds: 8
                )

                // Run the basic conversation (= 1 LLM call + 1 turn). If the
                // assistant message contains tool_use blocks, the tool executor
                // dispatches them sequentially (= the current ToolExecutor
                // default; concurrent path is available via executeConcurrent for
                // callers wanting parallelism).
                var result = try await runConversation(
                    userMessage: userMessage,
                    systemMessage: systemMessage,
                    conversationHistory: compressed,
                    taskId: resolvedTaskId,
                    streamCallback: streamCallback,
                    toolSchemas: toolSchemas,
                    // The settings for THIS turn (= the prompt guidance the
                    // user chose, the recovery policy, the memory backend).
                    // Without them the base path assembles the prompt from
                    // the defaults, so a switch the user flipped would do
                    // nothing until the turn took the tool branch.
                    settings: settings,
                    maxTokens: maxTokens,
                    thinkingBudget: thinkingBudget
                )

                // "Parsing response". The LLM response is already in
                // result.response (= parsed blocks); the loop has nothing extra
                // to do here other than signal that the parse phase finished.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 5,
                    label: "Parsing response",
                    etaSeconds: nil
                )

                // Reply guard (= hermes turn_empty_response / turn_truncation /
                // turn_overflow / turn_stop_gates, collapsed into one ladder).
                // Sits here because this is the first point where a finished
                // reply exists to judge: continuing a truncated answer and
                // rejecting an empty one both need the text, and both must
                // happen before tool dispatch so a retry does not run a tool
                // twice.
                let replyFacts = ReplyFacts(
                    text: Self.flattenText(result.response.blocks),
                    finishReason: result.response.stopReason.rawValue,
                    hasToolCalls: result.messages.last?.blocks.contains { block in
                        if case .toolUse = block {
                            return true
                        }
                        return false
                    } ?? false
                )
                let ladder = RecoveryLadder(
                    settings: settings.recovery,
                    requiredDeliverables: requiredDeliverables,
                    attemptsUsed: retry.attemptNumber,
                    isLastAttempt: !retry.canRetry
                )
                switch ladder.evaluate(replyFacts) {
                case .accept:
                    break
                case let .continueText(prompt):
                    // Keep the prose already produced and ask for the rest. A
                    // retry here would throw away text the user asked for.
                    result.messages.append(
                        LLMMessage(role: .user, blocks: [.text(prompt)])
                    )
                    let continued = try await streamInto(
                        messages: result.messages,
                        options: LLMCallOptions(
                            model: defaultModelForConnector(),
                            maxTokens: 4096,
                            systemPrompt: await composeSystemPrompt(
                                override: systemMessage,
                                persistent: systemPrompt,
                                settings: settings
                            ),
                            temperature: nil,
                            reasoningEffort: UserDefaults.standard.string(
                                forKey: "wenshu.llm.reasoningEffort"
                            ),
                            tools: toolSchemas
                        ),
                        streamCallback: streamCallback
                    )
                    result.messages.append(
                        LLMMessage(role: .assistant, blocks: continued.blocks)
                    )
                    result = ConversationResult(
                        response: TurnFinalizer.finalize(response: continued),
                        messages: result.messages,
                        taskId: resolvedTaskId
                    )
                case .retry, .degrade:
                    if !retry.canRetry {
                        break
                    }
                    retry.recordAttempt()
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: retry.attemptNumber,
                        label: "Retrying (\(Self.retryLabel(for: ladder.evaluate(replyFacts))))"
                    )
                    if settings.recovery.retryBackoffSeconds > 0 {
                        try? await Task.sleep(
                            nanoseconds: UInt64(settings.recovery.retryBackoffSeconds * 1_000_000_000)
                        )
                    }
                    continue
                case let .abort(_, message):
                    await progressTracker.complete(id: progressEntry.id, status: .failed)
                    return ConversationResult(
                        response: LLMResponse(blocks: [.text(message)]),
                        messages: result.messages,
                        taskId: resolvedTaskId
                    )
                }

                // The tool dispatch loop (= hermes'
                // `_execute_tool_calls_sequential`). The round limit is a
                // setting, not a constant (= hermes' `agent.max_turns`). The
                // safety policy's own caps bound the specific behaviours; this
                // bounds the worst case, and the two are not substitutes for each
                // other.
                let maxAgentTurns = max(1, settings.turn.maxIterations)
                var turnCount = 1 // first LLM call = turn 1
                // The turn's ledger of the calls made so far (= the loop
                // guardrails). It lives HERE, not in the executor: the
                // executor is built fresh inside every round, so a counter
                // there would die with the round.
                let safetyLedger = ToolSafetyLedger(policy: ToolSafetyPolicy.values)
                while let assistant = result.messages.last,
                      assistant.blocks.contains(where: {
                          if case .toolUse = $0 {
                              return true
                          } else {
                              return false
                          }
                      }),
                      turnCount < maxAgentTurns
                {
                    turnCount += 1
                    // The dead `[wenshu.agent] turn N/M` marker is gone (= no view
                    // consumes it). The loop counter is still kept internally (= it
                    // bounds the while condition); = only the user-visible
                    // marker is dropped. "Executing tools".
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 6,
                        label: "Executing tools (turn \(turnCount))",
                        etaSeconds: nil
                    )
                    let executor = ToolExecutor(safetyLedger: safetyLedger)
                    // Forward the stream callback so ToolExecutor
                    // emits.toolUse +.toolResult blocks to ChatView (= the
                    // ChatToolUsePartView / ChatToolResultPartView cards appear
                    // live, not only when the whole turn finishes).
                    try await executor.executeSequential(
                        assistantMessage: assistant,
                        messages: &result.messages,
                        taskId: resolvedTaskId,
                        tools: tools,
                        streamCallback: streamCallback
                    )

                    // Re-invoke LLM with tool results (= hermes
                    // "tool result -> next assistant message" loop body).
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 4,
                        label: "Calling LLM (turn \(turnCount))",
                        etaSeconds: 4
                    )
                    let reasoningEffort = UserDefaults.standard.string(forKey: "wenshu.llm.reasoningEffort")
                    let options = LLMCallOptions(
                        model: defaultModelForConnector(),
                        maxTokens: maxTokens,
                        systemPrompt: await composeSystemPrompt(
                            override: systemMessage,
                            persistent: systemPrompt,
                            settings: settings
                        ),
                        temperature: nil,
                        reasoningEffort: reasoningEffort,
                        tools: toolSchemas
                    )
                    let nextResponse = try await streamInto(
                        messages: result.messages,
                        options: options,
                        streamCallback: streamCallback
                    )
                    let nextAssistant = LLMMessage(role: .assistant, blocks: nextResponse.blocks)
                    result.messages.append(nextAssistant)
                    result = ConversationResult(
                        response: TurnFinalizer.finalize(response: nextResponse),
                        messages: result.messages,
                        taskId: resolvedTaskId
                    )
                }

                // "Finalizing reply". Post-turn compression (= hermes
                // conversation_history_after_compression) runs as part of
                // finalization; surface it under the same step.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 7,
                    label: "Finalizing reply",
                    etaSeconds: nil
                )
                let (compressedMessages, _) = await conversationCompression.historyAfterCompression(
                    messages: result.messages,
                    systemMessage: await composeSystemPrompt(
                        override: systemMessage,
                        persistent: systemPrompt,
                        settings: settings
                    ) ?? ""
                )

                // "Persisting memory". Write the turn's off-by-default users see
                // no behavior change. The turn's own settings decide whether this
                // happens. The memory adapter's write carries its own guard, but
                // that guard reads a global user-defaults key, so the turn's
                // settings could not turn the write off (= a caller that asks for
                // no memory would still leave a trace). The check belongs here,
                // where the write is: the settings are already in scope (= this
                // step reads them for the backend), so the switch reaches the
                // write without a new parameter or a new type. With the switch at
                // its default the write happens exactly as it does today, and a
                // caller that passes no settings keeps reading the global key
                // through the adapter.
                if settings.memory.enabled {
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 8,
                        label: "Persisting memory",
                        etaSeconds: nil
                    )
                    let provider: any MemoryProvider
                    if let memoryProvider {
                        provider = memoryProvider
                    } else {
                        provider = await MemoryAdapter.resolveProvider(for: settings.memory)
                    }
                    await MemoryAdapter(
                        provider: provider
                    ).write(
                        snippet: userMessage,
                        source: result.response.blocks.first(where: {
                            if case .text = $0 {
                                return true
                            } else {
                                return false
                            }
                        })
                        .map { block -> String in
                            if case let .text(s) = block {
                                return s
                            }
                            return ""
                        } ?? "",
                        bookId: nil
                    )
                }

                // "Submitting background-review proposals". The agent-side
                // auto-call hook per the auto+manual merge stance: the agent
                // scans the response for background-worthy events (= file writes,
                // entity changes, schedule edits) and submits a proposal per
                // event via `BackgroundReviewOps`. For the MVP the hook is the
                // simplest possible: always submit one proposal per turn whose
                // kind =.turnSummary (= the operator reviews the turn in the
                // inspector's BackgroundReview tab; = the manual surface remains
                // BackgroundReviewOps.approve / reject).
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 9,
                    label: "Submitting background-review proposal",
                    etaSeconds: nil
                )
                let turnSummary = result.response.blocks.first(where: {
                    if case .text = $0 {
                        return true
                    } else {
                        return false
                    }
                })
                .map { block -> String in
                    if case let .text(s) = block {
                        return s
                    }
                    return ""
                } ?? ""
                let autoProposal = BackgroundProposal(
                    kind: .turnSummary,
                    title: "Turn summary: \(turnSummary.prefix(80))",
                    description: turnSummary,
                    proposedChanges: []
                )
                await BackgroundReviewOps.submit(autoProposal)

                // mark the entry as succeeded.
                await progressTracker.complete(id: progressEntry.id, status: .succeeded)

                return ConversationResult(
                    response: result.response,
                    messages: compressedMessages,
                    taskId: resolvedTaskId
                )
            } catch let error as LLMConnectorError {
                // Mark the entry as failed on retryable error too (= the user
                // sees the failed step in the OpenBox panel even if the loop will
                // retry). The next retry iteration's `advance(..)` will reset the
                // step to step 4 "Calling LLM" so the user sees a fresh attempt.
                await progressTracker.complete(id: progressEntry.id, status: .failed)
                // Classifier-aware retry: transient errors get retried,
                // non-transient fail immediately.
                if !retry.canRetry || !LLMConnectorErrorClassifier.isTransient(error) {
                    throw error
                }
                // Open a fresh running entry for the retry iteration so the
                // OpenBox panel shows progress again. The previous entry is
                // already marked failed above; the `current(sessionId:)` lookup
                // will skip it (= status !=.running) and return the new entry
                // instead.
                progressEntry = await progressTracker.start(
                    sessionId: sessionId,
                    label: "Reading user message"
                )
                continue
            }
        }

        // Loop exited without success (= retries exhausted).
        await progressTracker.complete(id: progressEntry.id, status: .failed)
        throw LLMConnectorError.transport(
            provider: connector.connectorID,
            statusCode: 0,
            body: "ConversationLoop.runTurn retries exhausted (maxAttempts = \(maxAttempts))"
        )
    }

    /// The streaming path: it replaces the direct `connector.send(...)` call, so
    /// the caller (= runConversation + TurnFinalizer) still gets a valid shape.
    final class StreamTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _task: Task<[LLMBlock], Error>?

        var task: Task<[LLMBlock], Error>? {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _task
            }
            set {
                lock.lock()
                _task = newValue
                lock.unlock()
            }
        }
    }

    /// Whether a stream has produced anything yet.
    ///
    /// The streaming cap applies to the connection, not to the reply: once
    /// the provider has said anything, the stream is alive and is allowed
    /// to finish. This holder is the flag both sides read.
    final class StreamProgress: @unchecked Sendable {
        private let lock = NSLock()
        private var _sawFirstBlock = false

        var sawFirstBlock: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _sawFirstBlock
            }
            set {
                lock.lock()
                _sawFirstBlock = newValue
                lock.unlock()
            }
        }
    }
}
