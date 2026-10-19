// ConversationLoop.swift
// … (= 49 rationale lines collapsed; = A112 docblock collapse per §1.8)
// unit tests + callers that don't care about progress emission).
import Foundation
import WenshuData

// / Result of a single ConversationLoop.runConversation call.
// … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / full message history + taskId for tracing + telemetry).
struct ConversationResult: Sendable {
    let response: LLMResponse
    var messages: [LLMMessage]
    let taskId: String

    init(response: LLMResponse, messages: [LLMMessage], taskId: String) {
        self.response = response
        self.messages = messages
        self.taskId = taskId
    }
}

// / Agent main loop engine. One ConversationLoop per session (= per
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / profile per Settings → LLM Connector pane) and returns the result.
actor ConversationLoop {

    private let connector: any LLMConnector
    private let systemPrompt: String?

    // / Runtime state (= mock-time / verbose / debug / credential chain).
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / keeps the ConversationLoop actor's isolation contract intact.
    private let runtime: RuntimeHelpers

    // / Build a ConversationLoop bound to an active LLMConnector.
    // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /     by-step feedback in the OpenBox panel during a turn.
    init(
        connection: any LLMConnector,
        systemPrompt: String? = nil,
        runtime: RuntimeHelpers? = nil,
        shellHookChain: ShellHookChain = ShellHookChain(),
        conversationCompression: ConversationCompression = ConversationCompression(),
        progressTracker: AgentProgressTracker = .noop
    ) {
        // Back-compat: the parameter is named `connector` everywhere in
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // stored property below.
        self.connector = connection
        self.systemPrompt = systemPrompt
        self.runtime = runtime ?? RuntimeHelpers()
        self.shellHookChain = shellHookChain
        self.conversationCompression = conversationCompression
        self.progressTracker = progressTracker
    }

    // / Legacy initializer (= preserved for backward compat with callers
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / wenshu port init with default hook chain + compression actor.
    init(
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

    // / Shell hook chain (= wenshu port). Default = empty.
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / = no behavior change for callers not registering hooks.
    private let shellHookChain: ShellHookChain

    // / Conversation compression actor (= wenshu port). Default =
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / conversation_history_after_compression).
    private let conversationCompression: ConversationCompression

    // / Agent progress tracker (= WIRE-AGENT-006). Default = `.noop`
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / OpenBox panel during a conversation turn.
    private let progressTracker: AgentProgressTracker

    // / Resolve the current time via the runtime (= hermes-port Z-contract
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / can call the loop's clock instead of touching `Date()` directly.
    func now() async -> Date {
        await runtime.now()
    }
    // / Run a complete conversation turn (= hermes run_conversation L523-L546).
    // … (= 27 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / - Throws: LLMConnectorError on transport / auth / provider failure.
    func runConversation(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage]? = nil,
        taskId: String? = nil,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        persistUserMessage: String? = nil,
        persistUserTimestamp: TimeInterval? = nil,
        moaConfig: MOAConfig? = nil,
        toolSchemas: [ToolRegistrySchema] = []
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString

        // Per-turn setup (= wenshu port): sanitize the user
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // emit the pre-turn shell hook.
        let sanitizedUser = MessageSanitization.sanitizeText(userMessage)
        var retryState = TurnRetryState(maxAttempts: 1)
        retryState.reset() // single-shot = no retry; runTurn() manages retries
        let turnCtx = TurnContext(
            taskId: resolvedTaskId,
            userMessage: sanitizedUser,
            systemMessage: systemMessage,
            conversationHistory: conversationHistory ?? [],
            model: defaultModelForConnector(),
            maxTokens: 4096,
            attemptNumber: retryState.attemptNumber
        )
        try await shellHookChain.firePreTurn(sanitizedUser)
        _ = turnCtx  // captured for downstream debug accessors

        // Build message list = prior history + new user message
        var messages = conversationHistory ?? []
        messages.append(LLMMessage.user(sanitizedUser))

        // Resolve system prompt (= systemMessage override > persistent systemPrompt)
        // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // anywhere in the source tree.
        let effectiveSystemPrompt = await composeSystemPrompt(
            override: systemMessage,
            persistent: systemPrompt
        )

        // Build call options (= model defaults to first defaultModel of
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // the PromptCaching cache layer).
        let defaultModel = defaultModelForConnector()
        // read user-selected reasoning effort from
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // "xhigh"/"max"). nil = connector uses provider default.
        let reasoningEffort = UserDefaults.standard.string(forKey: "wenshu.llm.reasoningEffort")
        let options = LLMCallOptions(
            model: defaultModel,
            maxTokens: 4096,
            systemPrompt: effectiveSystemPrompt,
            temperature: nil,
            reasoningEffort: reasoningEffort,
            tools: toolSchemas
        )

        // Send to LLMConnector (= one round-trip)
        let response = try await streamInto(
            messages: messages, options: options, streamCallback: streamCallback
        )

        // Append assistant response to message list (= result.messages)
        let assistantMessage = LLMMessage(role: .assistant, blocks: response.blocks)
        messages.append(assistantMessage)

        // Post-turn hooks (= wenshu port):
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // 2. ShellHookChain.firePostTurn (= observation + optional mutation)
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
    // … (= 33 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // /   history + taskId.
    func runTurn(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage] = [],
        tools: [String: any Tool] = [:],
        taskId: String? = nil,
        maxAttempts: Int = 3,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        // / Tool schemas advertised to the model. Empty (= default)
        // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // / conductor before invoking runTurn).
        toolSchemas: [ToolRegistrySchema] = []
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString
        var retry = TurnRetryState(maxAttempts: maxAttempts)

        // : start the agent progress
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // `current(sessionId:)` every render cycle.
        let sessionId = resolvedTaskId
        var progressEntry = await progressTracker.start(
            sessionId: sessionId,
            label: "Reading user message"
        )

        while retry.canRetry {
            retry.recordAttempt()
            do {
                // step 2: "Compressing context if needed".
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // the LLM call can hook real work here.
                await progressTracker.advance(
                    id: progressEntry.id,
                    label: "Compressing context if needed"
                )

                // step 3 + 4: "Building prompt" + "Calling LLM".
                // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // realistic countdown that the next step will clear.
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

                // Run the basic conversation (= 1 LLM call + 1 turn).
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // parallelism).
                var result = try await runConversation(
                    userMessage: userMessage,
                    systemMessage: systemMessage,
                    conversationHistory: conversationHistory,
                    taskId: resolvedTaskId,
                    streamCallback: streamCallback,
                    toolSchemas: toolSchemas
                )

                // step 5: "Parsing response". The LLM
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // than signal that the parse phase finished.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 5,
                    label: "Parsing response",
                    etaSeconds: nil
                )

                // Tool dispatch loop (= hermes _execute_tool_calls_sequential).
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // at maxAgentTurns to prevent runaway loops).
                let maxAgentTurns = 10
                var turnCount = 1  // first LLM call = turn 1
                while let assistant = result.messages.last,
                      assistant.blocks.contains(where: { if case .toolUse = $0 { return true } else { return false } }),
                      turnCount < maxAgentTurns {
                    turnCount += 1
                    // dead `[wenshu.agent] turn N/M`
                    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // step 6: "Executing tools".
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 6,
                        label: "Executing tools (turn \(turnCount))",
                        etaSeconds: nil
                    )
                    let executor = ToolExecutor()
                    // T2-TOOL-UI (2026-09-18): forward streamCallback so
                    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // finishes).
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
                        maxTokens: 4096,
                        systemPrompt: await composeSystemPrompt(
                            override: systemMessage,
                            persistent: systemPrompt
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

                // step 7: "Finalizing reply". Post-turn
                // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // of finalization; surface it under the same step.
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
                        persistent: systemPrompt
                    ) ?? ""
                )

                // step 8: "Persisting memory". Write the turn's
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // off-by-default users see no behavior change.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 8,
                    label: "Persisting memory",
                    etaSeconds: nil
                )
                await MemoryAdapter().write(
                    snippet: userMessage,
                    source: result.response.blocks.first(where: { if case .text = $0 { return true } else { return false } })
                        .map { block -> String in
                            if case .text(let s) = block { return s }
                            return ""
                        } ?? "",
                    bookId: nil
                )

                // step 9: "Submitting background-review proposals".
                // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // surface remains BackgroundReviewOps.approve / reject).
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 9,
                    label: "Submitting background-review proposal",
                    etaSeconds: nil
                )
                let turnSummary = result.response.blocks.first(where: { if case .text = $0 { return true } else { return false } })
                    .map { block -> String in
                        if case .text(let s) = block { return s }
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
                // mark the entry as failed on retryable
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // attempt.
                await progressTracker.complete(id: progressEntry.id, status: .failed)
                // Classifier-aware retry: transient errors get retried,
                // non-transient fail immediately.
                if !retry.canRetry || !LLMConnectorErrorClassifier.isTransient(error) {
                    throw error
                }
                // Open a fresh running entry for the retry iteration
                // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // != .running) and return the new entry instead.
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

    // / T14-CONVLOOP-STREAMING (2026-09-18): replace direct `connector.send(...)`
    // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / (= runConversation + TurnFinalizer) still gets a valid shape.
    private func streamInto(
        messages: [LLMMessage],
        options: LLMCallOptions,
        streamCallback: (@Sendable (LLMBlock) async -> Void)?
    ) async throws -> LLMResponse {
        let stream = connector.stream(messages: messages, options: options)
        let streamTask = Task<[LLMBlock], Error> {
            var collected: [LLMBlock] = []
            for await block in stream {
                // P5-SSE-CANCEL (2026-10-19 follow-up to
                // 5568f909d + e77f82e22: the previous
                // commit's `cc944079e` "60s cap" only
                // CANCELED the child task; the underlying
                // `for await block in stream` (= an
                // `AsyncStream<LLMBlock>` produced by the
                // third-party mattt/EventSource parser) is
                // NOT cancellation-cooperative; = the
                // cancel propagated to the task but the
                // for-await stayed blocked on the EventSource
                // parser; = the cap never returned to the
                // caller's `await streamTask.value`. The
                // explicit `Task.checkCancellation()` here
                // (= checked once per inbound block) gives
                // the runtime a per-iteration chance to
                // observe the cancel and unwind the
                // for-await. The 60s cap path (the
                // sibling `timeoutTask`) cancels the child
                // (= this check fires on the next block
                // arrival; = if no block ever arrives the
                // cap's `Task.sleep(60s)` still fires via
                // the throwing task body in `timeoutTask`).
                try Task.checkCancellation()
                collected.append(block)
                if let streamCallback {
                    await streamCallback(block)
                }
            }
            return collected
        }
        let timeoutTask = Task<Void, Error> {
            try await Task.sleep(nanoseconds: 60_000_000_000)
            streamTask.cancel()
            throw CancellationError()
        }
        let accumulated: [LLMBlock]
        do {
            accumulated = try await streamTask.value
            timeoutTask.cancel()
        } catch {
            // P5-CAP-DIAG (2026-10-19 mac-mini
            // reproducer boss "至今还没有回复"): the
            // 60s cap (= the sibling timeoutTask)
            // throws an `LLMConnectorError.timeout`
            // (= a transient error per the existing
            // LLMConnectorErrorClassifier.isTransient
            // contract; = the ConversationLoop.runTurn
            // catch block at L394 will treat the
            // timeout as retryable; = the user sees a
            // silent "AI 思考中 60s" then a "文枢暂时
            // 无法回复" fallback with no actionable
            // signal). The classifier here (= the
            // NSError with NSLocalizedDescriptionKey
            // "流式响应超时（60 秒内无任何 block 到
            // 达）") is the canonical
            // UserFacingError.from source; = the
            // caller WenshuConductor.runConversation
            // LoopPath catch at L339 logs the
            // description (= visible in Console.app
            // under `[wenshu.conductor] PATH=legacy
            // REASON=ConversationLoop.runTurn threw`)
            // and the user can now tell the difference
            // between a 401 / 429 / 5xx / SSE hang
            // from the cap's description string.
            throw LLMConnectorError.transport(
                provider: connector.connectorID,
                statusCode: 0,
                body: "流式响应超时（60 秒内无任何 block 到达）"
            )
        }
        // Stable id + model shape (= mirrors what send() produces).
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // consistent model name regardless of send() vs stream().
        let model = defaultModelForConnector()
        return LLMResponse(
            id: "\(connector.connectorID)-stream-\(UUID().uuidString)",
            model: model,
            blocks: accumulated,
            stopReason: accumulated.contains(where: { if case .toolUse = $0 { return true } else { return false } })
                ? .toolUse : .endTurn,
            usage: LLMUsage(inputTokens: 0, outputTokens: 0)
        )
    }

    // / Resolve the default model for the active connector (= first model
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / model via the Settings pane).
    private nonisolated func defaultModelForConnector() -> String {
        // Provider enum lookup by connectorID (= thin integration in sub-step 3)
        if let provider = Provider.all.first(where: { $0.slug == connector.connectorID }) {
            return provider.defaultModels.first ?? "unknown-model"
        }
        // fix: when no Provider matches (= the
        // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // prefix makes the source of the model obvious).
        let connectorID = connector.connectorID
        // Mock connector + production connectors share the
        // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // supplied via the Provider.defaultModels list above.
        return "\(connectorID)-model"
    }

    // / Compose the effective system prompt via PromptBuilder
    // … (= 21 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / this method to read live data from those adapters.
    private func composeSystemPrompt(
        override: String?,
        persistent: String?
    ) async -> String? {
        // Determine the ephemeral hint source (= which string flows into
        // the dynamic tier's "Context: ..." section).
        let ephemeralHint = override ?? persistent ?? ""

        // Stable tier: always the byte-stable identity (no caller override
        // path for the stable tier — stable tier is byte-stable BY DEFINITION).
        let stable = SystemPrompt.stableTier()

        // Dynamic tier: composed via PromptBuilder (= the GAP-001 path).
        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // so the LLM sees relevant context on the first token.
        let prefetched = await MemoryAdapter().retrieve(
            forUserMessage: ephemeralHint,
            bookId: nil
        )
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

        // No hint + no dynamic = no system prompt at all (= caller chose
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // handles the default).
        if ephemeralHint.isEmpty {
            return stable.isEmpty ? nil : stable
        }

        // Join stable + dynamic with the canonical separator (= same
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // buildOpenAISystem / buildGeminiSystemInstruction output).
        return stable + "\n\n---\n\n" + dynamic
    }
}

// / Mixture-of-Agents config (= hermes `moa_config` param).
// … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / 9-param signature is hermes-compatible from day 1.
struct MOAConfig: Sendable {
    let advisorCount: Int
    let aggregatorModel: String

    init(advisorCount: Int, aggregatorModel: String) {
        self.advisorCount = advisorCount
        self.aggregatorModel = aggregatorModel
    }
}
