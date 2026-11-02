// The conversation loop actor (= the Swift port of hermes'
// `conversation_loop.run_conversation`). This is the agent's main loop engine.
// Each user turn: 1. builds the message list (= the history plus the new user
// message). 2. invokes `LLMConnector.send(messages:options:)` (= one round-trip
// to the active connector profile). 3. appends the assistant response to the
// message list. 4. returns the result (= the response plus the full message
// history and the task id for tracing).
import Foundation
import os.log

/// The result of a single `ConversationLoop.runConversation` call: the
/// model's reply, the full message history, and the taskId used for tracing
/// and telemetry.
public struct ConversationResult: Sendable {
    public let response: LLMResponse
    public var messages: [LLMMessage]
    public let taskId: String

    public init(response: LLMResponse, messages: [LLMMessage], taskId: String) {
        self.response = response
        self.messages = messages
        self.taskId = taskId
    }
}

/// The agent's main loop engine. One ConversationLoop per session (= per
/// profile per Settings → LLM Connector pane) and returns the result.
public actor ConversationLoop {
    private let connector: any LLMConnector
    private let systemPrompt: String?

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
    private let shellHookChain: ShellHookChain

    /// The conversation compression actor (= the hermes port). Default = the
    /// compression actor that drops the conversation history after the
    /// compression.
    private let conversationCompression: ConversationCompression
    /// Reduces the transcript before the provider call. Injected so the
    /// budget is a construction-time decision rather than a constant read
    /// here (= see OOB.md #2026-10-20 on agent settings).
    private let historyCompressor: HistoryCompressor

    /// The agent progress tracker. Default = `.noop`, so the OpenBox panel shows
    /// nothing during a conversation turn.
    private let progressTracker: AgentProgressTracker

    /// The memory provider the turn writes into. The resolver decides which one
    /// is used, and nil = the user's own backend is resolved at the call site.
    private let memoryProvider: (any MemoryProvider)?

    /// Resolves the current time via the runtime (= the hermes-port Z-contract),
    /// so a caller can call the loop's clock instead of touching `Date()`
    /// directly.
    public func now() async -> Date {
        await runtime.now()
    }

    /// Runs a complete conversation turn (= the hermes `run_conversation`).
    /// It throws `LLMConnectorError` on a transport, auth or provider failure.
    public func runConversation(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage]? = nil,
        taskId: String? = nil,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        persistUserMessage _: String? = nil,
        persistUserTimestamp _: TimeInterval? = nil,
        moaConfig: MOAConfig? = nil,
        toolSchemas: [ToolRegistrySchema] = [],
        // The user's settings for this turn. The prompt assembly reads
        // them (= the guidance switches, the recovery policy, the memory
        // backend), so a turn that leaves them out runs on the defaults
        // no matter what the user chose.
        settings: AgentSettings = .init(),
        // The turn's output budget (= see runTurn).
        maxTokens: Int = 4096,
        // The thinking budget (= see runTurn).
        thinkingBudget: Int? = nil
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString

        // Per-turn setup (= wenshu port): sanitize the user message (= hermes
        // message_sanitization._sanitize_surrogates + _strip_non_ascii), reset
        // the retry counter for this turn, and emit the pre-turn shell hook.
        let sanitizedUser = MessageSanitization.sanitizeText(userMessage)
        var retryState = TurnRetryState(maxAttempts: 1)
        retryState.reset() // single-shot = no retry; runTurn() manages retries
        let turnCtx = TurnContext(
            taskId: resolvedTaskId,
            userMessage: sanitizedUser,
            systemMessage: systemMessage,
            conversationHistory: conversationHistory ?? [],
            model: defaultModelForConnector(),
            maxTokens: maxTokens,
            attemptNumber: retryState.attemptNumber
        )
        try await shellHookChain.firePreTurn(sanitizedUser)
        _ = turnCtx // captured for downstream debug accessors

        // Build message list = prior history + new user message
        var messages = conversationHistory ?? []
        messages.append(LLMMessage.user(sanitizedUser))

        // Resolve system prompt (= systemMessage override > persistent
        // systemPrompt) Per hermes-port wire-up: compose stable + dynamic tiers
        // via PromptBuilder instead of the v0.35 placeholder string that wrapped
        // the ephemeral hint with a Context: prefix. The dynamic tier composes
        // from ContextEngine + MemoryAdapter + SkillAdapter + caller extras; for
        // the minimum surface, those are empty (= ContextEngine + SkillAdapter
        // land in follow-on tickets), so the dynamic tier reduces to the
        // ephemeral hint as a final block. The placeholder Swift template no
        // longer appears anywhere in the source tree.
        let effectiveSystemPrompt = await composeSystemPrompt(
            override: systemMessage,
            persistent: systemPrompt,
            settings: settings
        )

        // Build call options (= model defaults to first defaultModel of the
        // active connector profile; per-call override lands in the PromptCaching
        // cache layer).
        let defaultModel = defaultModelForConnector()
        // Read user-selected reasoning effort from UserDefaults (= set by
        // SettingView picker; = "low"/"medium"/"high"/ "xhigh"/"max"). nil =
        // connector uses provider default.
        let reasoningEffort = UserDefaults.standard.string(forKey: "wenshu.llm.reasoningEffort")
        let options = LLMCallOptions(
            model: defaultModel,
            maxTokens: maxTokens,
            systemPrompt: effectiveSystemPrompt,
            temperature: nil,
            reasoningEffort: reasoningEffort,
            thinkingBudget: thinkingBudget,
            tools: toolSchemas
        )

        // Send to LLMConnector (= one round-trip)
        let response = try await streamInto(
            messages: messages, options: options, streamCallback: streamCallback
        )

        // Fold the turn's token counts into the conversation's cache
        // total, so the saving is readable while the conversation runs.
        //
        // The key is the CHAT SESSION, not the turn's task id: the task
        // id is a fresh UUID per turn when the caller does not supply
        // one (= the conductor's path), so keying on it would reset the
        // running total every turn and the total would never grow.
        // The session id is the thing the user calls a conversation.
        let cacheConversationId = TurnScope.currentSessionID ?? resolvedTaskId
        await PromptCacheRecorder.shared.record(
            conversationId: cacheConversationId,
            usage: response.usage
        )

        // Append assistant response to message list (= result.messages)
        let assistantMessage = LLMMessage(role: .assistant, blocks: response.blocks)
        messages.append(assistantMessage)

        // Post-turn hooks (= wenshu port): 1. TurnFinalizer.finalize (= drop
        // empty blocks, normalize) 2. ShellHookChain.firePostTurn (= observation
        // + optional mutation)
        let finalResponse = TurnFinalizer.finalize(response: response)
        try await shellHookChain.firePostTurn(finalResponse)

        // moaConfig deferred to v2 per spec §14 (= no-op for now)
        _ = moaConfig

        // persistUserMessage / persistUserTimestamp deferred (= transcript
        // persistence is WSChatRepository's job per spec §3.6 wenshu-side wins)

        return ConversationResult(
            response: finalResponse,
            messages: messages,
            taskId: resolvedTaskId
        )
    }

    // MARK: - wenshu port wire-up: runTurn (full turn orchestrator)

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
                    // Dead `[wenshu.agent] turn N/M` marker emission removed (=
                    // ChatTurnProgress.swift deleted in v1.83; = no view consumes
                    // the marker). The loop counter is still kept internally (=
                    // it bounds the while condition); = only the user-visible
                    // marker is dropped. "Executing tools".
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 6,
                        label: "Executing tools (turn \(turnCount))",
                        etaSeconds: nil
                    )
                    let executor = ToolExecutor(safetyLedger: safetyLedger)
                    // T2-TOOL-UI: forward streamCallback so ToolExecutor
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

    private func streamInto(
        messages: [LLMMessage],
        options: LLMCallOptions,
        streamCallback: (@Sendable (LLMBlock) async -> Void)?
    ) async throws -> LLMResponse {
        // The provider sends its token counters inside the stream events,
        // so the turn collects them as they arrive and reports the
        // provider's numbers rather than zeros.
        let usageCollector = StreamUsageCollector()
        let stream = StreamUsageScope.$collector.withValue(usageCollector) {
            connector.stream(messages: messages, options: options)
        }
        let streamProgress = StreamProgress()
        // The stream task is held in a box so the cap can await it: the cap
        // waits for the stream once the connection has answered. A box
        // rather than a local variable, because the cap task captures it
        // and a captured local of task type is not sendable.
        let streamBox = StreamTaskBox()
        streamBox.task = Task<[LLMBlock], Error> {
            var collected: [LLMBlock] = []
            for await block in stream {
                // The underlying `for await block in stream` (= an
                // `AsyncStream<LLMBlock>` produced by the third-party
                // event-stream parser) is NOT cancellation-cooperative:
                // cancelling the task propagates the cancel to the task but the
                // for-await stays blocked in the parser, so the cap never returns
                // to the caller's await. The explicit `Task.checkCancellation()`
                // here (= checked once per inbound block) gives the runtime a
                // per-iteration chance to observe the cancel and unwind the
                // for-await. The cap's own path cancels the child (= this check
                // fires on the next block arrival; if no block ever arrives the
                // cap's sleep still fires via the throwing task body).
                try Task.checkCancellation()
                if collected.isEmpty {
                    // The connection answered. The cap no longer applies:
                    // a reply that is still arriving is not a hang.
                    streamProgress.sawFirstBlock = true
                }
                collected.append(block)
                if let streamCallback {
                    await streamCallback(block)
                }
            }
            return collected
        }
        // The cap covers the wait for the FIRST block, not the whole
        // reply.
        //
        // It used to be a wall-clock limit on the entire stream, which was
        // added when the third-party SSE parser could not deliver a
        // provider's events at all (= every turn hit the cap and fell back
        // to a non-streaming call). The parser now reads the stream
        // directly, so a reply that is still arriving is not a hang: it is
        // a reply in progress, and the user is watching it arrive.
        //
        // A wall-clock limit on the whole stream would cut off exactly the
        // long replies the streaming path exists to deliver. So the limit
        // now applies to the connection only: if nothing arrives within
        // the window, the connection is dead and the non-streaming path
        // takes over. Once something arrives, the stream is allowed to
        // finish.
        //
        // The window is generous because it only has to outlast a slow
        // handshake. A provider that answers in two seconds has no chance
        // of tripping it.
        let firstBlockDeadline = Date().addingTimeInterval(60)
        let timeoutTask = Task<Void, Error> {
            while !streamProgress.sawFirstBlock, Date() < firstBlockDeadline {
                try await Task.sleep(for: .milliseconds(200))
            }
            if streamProgress.sawFirstBlock {
                // The stream is alive. Wait for it to finish rather than
                // racing it: the same result the other branch produces.
                _ = try? await streamBox.task?.value
                return
            }
            // The previous cap's
            // `streamTask.cancel()` did NOT unwind
            // the `for await block in stream` (= the
            // mattt/EventSource AsyncStream is not
            // cancellation-cooperative; = the for-await
            // stayed blocked on the parser; =
            // `streamTask.value` never returned; =
            // the catch block below never ran; = the
            // fallback to non-streaming send() never
            // fired). The trick below races
            // `streamTask.value` against
            // `timeoutTask.value`: whichever returns
            // first wins (= the cap's
            // `Task.sleep(60s)` is the deterministic
            // winner when the SSE parser hangs; = the
            // `streamTask.value` returns its collected
            // blocks when the SSE finishes normally).
            // When the cap wins, the throw
            // (= `CancellationError` from the
            // timeoutTask's race) propagates to the
            // catch block below, which routes the call
            // through `connector.send(...)` (= the
            // non-streaming request/response path; =
            // bypasses the EventSource SSE parser
            // entirely; = the only path that returns a
            // complete LLMResponse when the SSE
            // wireup hangs).
            streamBox.task?.cancel()
            throw CancellationError()
        }
        let accumulated: [LLMBlock]
        do {
            // Race streamTask vs timeoutTask. The
            // `withTaskGroup` makes the first one to
            // finish (= either the SSE parser
            // completing the for-await, or the cap
            // firing after 60s) the one whose result
            // the await below observes. The other task
            // is cancelled via the group on exit.
            accumulated = try await withThrowingTaskGroup(of: [LLMBlock].self) { group in
                group.addTask {
                    try await streamBox.task?.value ?? []
                }
                group.addTask {
                    try await timeoutTask.value
                    // = the cap fired; = the
                    // streamTask is still blocked; =
                    // return empty + throw via the
                    // outer try.
                    throw CancellationError()
                }
                let firstResult = try await group.next()!
                group.cancelAll()
                return firstResult
            }
            timeoutTask.cancel()
        } catch {
            // The cap (= the sibling timeout task) throws a transport error (= a
            // transient error per the existing transient-error contract, so the
            // turn's catch block treats the timeout as retryable; the user sees a
            // long think and then a "cannot reply yet" fallback with no
            // actionable signal). The classifier here (= the error with the
            // streaming-timeout description) is the canonical user-facing error
            // source, so the caller logs a description the user can act on (=
            // visible in Console.app under the conductor's legacy path), and the
            // user can tell a missing key from a rate limit from a server error
            // from an SSE hang by the description string. The cap and the
            // structured error alone are only the "tell the user we can't reply"
            // half: the "actually reply" half needs a fallback to the
            // non-streaming send path, so the user sees a real LLM response when
            // the SSE parser hangs on the upstream. The fallback routes the same
            // messages and options through `connector.send(...)` (= the
            // non-streaming request/response path, which bypasses the
            // event-stream parser entirely and is the only path that returns a
            // complete response even when the SSE wireup hangs). The catch below
            // emits a structured timeout log line so the user can still tell from
            // Console.app which path fired (= a streaming hang that fell back to
            // non-streaming, vs a clean streaming success).
            os_log("[wenshu.conversationLoop] PATH=stream-cap-fallback REASON=60s_no_blocks falling back to non-streaming send provider=%{public}@", log: .default, type: .error, connector.connectorID)
            do {
                return try await connector.send(
                    messages: messages,
                    options: options
                )
            } catch {
                // The non-streaming fallback also
                // failed (= genuine provider error, not
                // just a streaming parser hang). Throw
                // the structured timeout so the chat
                // surface shows the user-facing message
                // (= the `UserFacingError.from`
                // classifier maps this to the
                // streaming-timeout message, so the user can re-send
                // or fall back to a different provider).
                os_log("[wenshu.conversationLoop] PATH=stream-cap-fallback-failed REASON=non_streaming_also_failed error=%{public}@", log: .default, type: .error, String(describing: error))
                throw LLMConnectorError.transport(
                    provider: connector.connectorID,
                    statusCode: 0,
                    body: "流式响应超时（15 秒内无任何 block 到达；非流式重试也失败：\(String(describing: error))）"
                )
            }
        }
        // Stable id + model shape (= mirrors what send produces). The connector's
        // send implementation supplies its own id + model; = here we use the
        // deterministic connector-derived fallback (= "mock-model" for
        // MockLLMConnector, "<slug>-model" for real connectors) so downstream
        // code (TurnFinalizer, tests) sees a consistent model name regardless of
        // send vs stream.
        let model = defaultModelForConnector()
        // The counters the provider sent inside the stream events (= the
        // input count, the output count, and the cache counts). The
        // fallback path returns the provider's own usage object, so both
        // paths report the provider's numbers.
        let usage = usageCollector.usage
        return LLMResponse(
            id: "\(connector.connectorID)-stream-\(UUID().uuidString)",
            model: model,
            blocks: accumulated,
            stopReason: accumulated.contains(where: {
                if case .toolUse = $0 {
                    return true
                } else {
                    return false
                }
            })
                ? .toolUse : .endTurn,
            usage: usage
        )
    }

    /// Resolves the default model for the active connector (= the first model the
    /// connector offers, or the model the user chose via the Settings pane).
    private nonisolated func defaultModelForConnector() -> String {
        // The provider enum lookup by connector id (= a thin integration on the
        // provider's own slug).
        if let provider = Provider.all.first(where: { $0.slug == connector.connectorID }) {
            return provider.defaultModels.first ?? "unknown-model"
        }
        // Fix: when no Provider matches (= the common test path with
        // MockLLMConnector whose connectorID is "mock"), derive a stable fallback
        // from the connectorID itself so test assertions like
        // `result.response.model == "mock"` (= the Z contract per
        // `PromptCachingAndTurnContextTests.runConversationEcho`) match without
        // adding a synthetic Provider entry. The derived name is deterministic (=
        // connectorID-based) so test snapshots stay stable. For test-only
        // connectors (= connectorID == "mock") we return the bare ID (= "mock")
        // so the test sees the canonical model name; for production connectors
        // without a registered Provider we return "connectorID-model" to keep the
        // diagnostic shape visible in logs (= the connector ID prefix makes the
        // source of the model obvious).
        let connectorID = connector.connectorID
        // Mock connector + production connectors share the connectorID-derived
        // fallback (= "connectorID-model") so test snapshots and production logs
        // see the same shape. Real model identifiers for production connectors
        // are supplied via the Provider.defaultModels list above.
        return "\(connectorID)-model"
    }

    /// Composes the effective system prompt via the PromptBuilder. The
    /// adapters read live data, and this method reads it from those adapters.
    private func composeSystemPrompt(
        override: String?,
        persistent: String?,
        settings: AgentSettings = .init()
    ) async -> String? {
        // Determine the ephemeral hint source (= which string flows into
        // the dynamic tier's "Context: ..." section).
        let ephemeralHint = override ?? persistent ?? ""

        // Stable tier: always the byte-stable identity (no caller override
        // path for the stable tier — stable tier is byte-stable BY DEFINITION).
        //
        // The user's prompt settings decide which guidance blocks appear.
        // Without them the tier is assembled from fixed values, so a switch
        // the user flipped in the settings screen changes nothing.
        let stable = PromptTierBuilder.stableTier(
            settings: settings.prompt,
            provider: SystemPrompt.ProviderGuidance(providerSlug: connector.connectorID)
        )

        // Dynamic tier: composed via PromptBuilder. so the LLM sees relevant
        // context on the first token. The memory prefetch reads the user's stored
        // memories (= the turn's memory store, = on the main actor). A turn that
        // turned the memory off must not read it: = the turn asked for a clean
        // context, = and the read is a main-actor hop that can block the turn
        // behind whatever the main actor is doing.
        let prefetched: [MemoryAdapter.MemoryEntry]
        if settings.memory.enabled, settings.prompt.memoryGuidanceEnabled {
            // The loop's own provider comes first (= the same order the
            // write path uses), = so a caller that injected a provider
            // gets that one, = and the read and the write agree.
            let provider: any MemoryProvider
            if let memoryProvider {
                provider = memoryProvider
            } else {
                provider = await MemoryAdapter.resolveProvider(for: settings.memory)
            }
            prefetched = await MemoryAdapter(provider: provider).retrieve(
                forUserMessage: ephemeralHint,
                bookId: nil
            )
        } else {
            prefetched = []
        }
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: prefetched.map { entry in
                    ContextEngine.MemoryEntry(source: entry.source, snippet: entry.snippet)
                },
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: prefetched,
            callerExtras: [:],
            ephemeralHint: ephemeralHint
        )

        // No hint + no dynamic = no system prompt at all (= caller chose to send
        // the conversation without a system prompt; connector handles the
        // default).
        if ephemeralHint.isEmpty {
            return stable.isEmpty ? nil : stable
        }

        // Join stable + dynamic with the canonical separator (= same separator
        // SystemPrompt.build uses; matches PromptBuilder's buildOpenAISystem /
        // buildGeminiSystemInstruction output).
        return stable + "\n\n---\n\n" + dynamic
    }

    /// Compress the history when it has grown past the budget.
    ///
    /// Returns the reduced history, or nil when nothing was needed (= the
    /// caller keeps what it had). The provider call for the summary goes
    /// through the same connector as the turn itself: a summary produced by a
    /// different model than the one reading it is a summary with a different
    /// sense of what mattered.
    ///
    /// `incomingMessage` is measured with the history but never returned: the
    /// caller appends it itself when it builds the request, so folding it into
    /// the compressed history would deliver it twice.
    private func compressIfNeeded(
        messages history: [LLMMessage],
        incomingMessage: String,
        systemMessage: String
    ) async -> [LLMMessage]? {
        let window = connector.contextWindow
        let withIncoming = history + [LLMMessage(role: .user, blocks: [.text(incomingMessage)])]
        guard historyCompressor.needsCompression(withIncoming, contextWindow: window) else {
            return nil
        }
        // Compress the history alone. The incoming message is what the model is
        // being asked, not what it did, and replacing it with a summary would
        // answer a different question.
        let outcome = await historyCompressor.compress(history) { [weak self] middle in
            await self?.summariseHistory(middle, systemMessage: systemMessage)
        }
        switch outcome {
        case let .unnecessary(untouched):
            return untouched.count < history.count ? untouched : nil
        case let .pruned(reduced, _):
            return reduced.count < history.count ? reduced : nil
        case let .summarised(reduced, _, _):
            return reduced
        }
    }

    /// One provider call that turns a slice of history into prose.
    ///
    /// Deliberately small and non-streaming. A summary that fails returns nil
    /// and the caller keeps the un-summarised transcript, so a provider hiccup
    /// costs a little context rather than the turn.
    private func summariseHistory(
        _ messages: [LLMMessage],
        systemMessage: String
    ) async -> String? {
        guard !messages.isEmpty else { return nil }
        let transcript = messages.map { message in
            let role = message.role == .user ? "老板" : "文枢"
            let text = message.blocks.map(\.textValue).joined(separator: " ")
            return "\(role)：\(text)"
        }.joined(separator: "\n")

        let instruction = """
        把下面这段写作过程压缩成一份交接笔记，供同一个助手在后续对话里接着写。

        写清楚这些，不要加评论：
        - 已经确定的剧情、人物设定、世界规则
        - 尚未解决的情节伏笔
        - 用户明确表达过的偏好和约束
        - 故事当前进行到哪里

        不要复述原文，不要评价，不要加建议。控制在 400 字以内。

        \(transcript)
        """
        do {
            let response = try await connector.send(
                messages: [
                    LLMMessage(role: .user, blocks: [.text(instruction)]),
                ],
                options: LLMCallOptions(
                    model: defaultModelForConnector(),
                    maxTokens: 1024,
                    systemPrompt: systemMessage,
                    temperature: 0.2,
                    reasoningEffort: nil,
                    tools: []
                )
            )
            let text = response.blocks.map(\.textValue).joined().trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Flatten a reply's text blocks for the guards (= the content-filter and
    /// tail-punctuation checks both read prose, not block structure).
    static func flattenText(_ blocks: [LLMBlock]) -> String {
        blocks.compactMap { block in
            if case let .text(text) = block {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Progress label for a retry, so the user sees why the agent is still
    /// working rather than a bare spinner.
    static func retryLabel(for verdict: ResponseVerdict) -> String {
        switch verdict.reason {
        case .emptyReply: return "empty reply"
        case .truncated, .incompleteSentence: return "incomplete reply"
        case .contextOverflow: return "context too long"
        case .contentFiltered: return "filtered by provider"
        case .quotaExhausted: return "quota exhausted"
        case .transientError: return "connection issue"
        case .permanentError, .none: return "error"
        }
    }
}

/// The mixture-of-Agents config (= the hermes `moa_config` parameter). The
/// 9-parameter signature is hermes-compatible from day 1.
public struct MOAConfig: Sendable {
    public let advisorCount: Int
    public let aggregatorModel: String

    public init(advisorCount: Int, aggregatorModel: String) {
        self.advisorCount = advisorCount
        self.aggregatorModel = aggregatorModel
    }
}
