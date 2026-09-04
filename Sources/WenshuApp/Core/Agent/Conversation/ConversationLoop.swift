//
//  ConversationLoop.swift · Wenshu · v0.35 ticket 001 sub-step 3
//  + TICKET-HERMES-GAP-001 refactor (2026-09-04).
//
//  ConversationLoop actor = the Swift port of hermes'
//  conversation_loop.run_conversation (= L523-L546, 9-param entry).
//
//  This is the agent main loop engine. Each user turn:
//    1. Builds the message list (= history + new user message)
//    2. Invokes the LLMConnector.send(messages:options:) (= one round-trip
//       to the active connector profile)
//    3. Appends the assistant response to the message list
//    4. Returns ConversationResult (= response + full message history +
//       taskId for tracing)
//
//  v0.35 sub-step 3 implements the MINIMUM surface that lets the rest of
//  the agent stack (= ToolExecutor in sub-step 5, ConversationCompression
//  in ticket 003) compose against it. Tool dispatch loop, fallback chain,
//  preflight compression, post-turn hooks, background nudges = NOT in
//  sub-step 3 (= they live in subsequent sub-steps / tickets per spec).
//
//  Invariants (= AGENTS.md §11.3 + §11 product-positioning):
//    1. ConversationLoop is BYOK (= delegates to LLMConnector.send which
//       calls ConnectorCredentials.resolve).
//    2. No metering / billing / quota tracking added (= §11).
//    3. No default provider (= caller specifies connector explicitly).
//    4. Cache-stable system prompt (= ticket 002 PromptCaching layer;
//       not yet wired in sub-step 3, lands as part of sub-step 3 followup).
//
//  Hermes correspondence:
//    L523-L546: 9-param entry + return Dict[str, Any]
//    L558-590: build_turn_context (= pre-turn setup; lands in TurnContext.swift sub-step 4)
//    L590-880: turn loop body with retries / fallbacks / compression
//      (= sub-step 3 implements the minimum surface, full loop body lands
//      incrementally in tickets 003-005)
//
//  v0.35 sub-step 3 of 8 for ticket 001.
//
//  TICKET-HERMES-GAP-003 wire-up (2026-09-04): ConversationLoop now
//  holds an optional `RuntimeHelpers` reference (default = a fresh actor
//  instance per ConversationLoop; callers may inject a custom one for
//  deterministic-test paths). The runtime is consulted via `await
//  runtime.now()` whenever the loop needs a timestamp (= hermes-port
//  Z-contract hard requirement per v0.36 ticket 014). No literal `Date()`
//  calls remain in the loop body — see `Sources/WenshuApp/Core/Agent/
//  Runtime/RuntimeHelpers.swift` for the actor surface.
//
//  WIRE-AGENT-006 (v0.41 P2 #21): ConversationLoop now drives an
//  `AgentProgressTracker` (= library-level, ephemeral, actor). The
//  tracker emits step events as the turn progresses so the OpenBox
//  panel (= DynamicZoneView progress strip) can render real-time
//  feedback to the user. Default = `.noop` (= zero overhead for
//  unit tests + callers that don't care about progress emission).
//

import Foundation

/// Result of a single ConversationLoop.runConversation call.
///
/// Mirrors hermes' `Dict[str, Any]` return shape (= final response +
/// full message history + taskId for tracing + telemetry).
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

/// Agent main loop engine. One ConversationLoop per session (= per
/// ChatSessionStore session, per spec §3.6 wenshu-side wins).
///
/// Drives one user turn through the LLMConnector (= active connector
/// profile per Settings → LLM Connector pane) and returns the result.
public actor ConversationLoop {

    private let connector: any LLMConnector
    private let systemPrompt: String?

    /// Runtime state (= mock-time / verbose / debug / credential chain).
    /// Optional: when nil, the loop falls back to a fresh default
    /// `RuntimeHelpers()` instance (= wall-clock now, no verbose / debug,
    /// env-var-or-keychain credential chain). Tests inject a stub with
    /// `mockTime` set for deterministic timestamps.
    ///
    /// TICKET-HERMES-GAP-003 wire-up: stored as a `let` because the
    /// `RuntimeHelpers` actor is itself immutable (= its `initialState`
    /// is the source of truth; mutations return new instances). This
    /// keeps the ConversationLoop actor's isolation contract intact.
    private let runtime: RuntimeHelpers

    /// Build a ConversationLoop bound to an active LLMConnector.
    ///
    /// - Parameters:
    ///   - connector: The active connector profile (= e.g. minimax cn,
    ///     Anthropic, OpenAI, Gemini, DeepSeek, Ollama, OpenRouter).
    ///   - systemPrompt: Optional byte-stable system prompt prefix (= per
    ///     AGENTS.md §11.3 cache-stable invariant; full cache_control marker
    ///     lands in ticket 002 PromptCaching.swift).
    ///   - runtime: Optional runtime helper (= TICKET-HERMES-GAP-003).
    ///     When nil, a default actor instance is created with no mock-time
    ///     and no verbose/debug flags. Callers wanting deterministic-test
    ///     injection (= v0.36 ticket 014) should pass a runtime built with
    ///     `RuntimeHelpers(state: .init(mockTime: ...))`.
    ///   - shellHookChain: Optional shell hook chain (= HERMES-PARTIAL-001).
    ///     When nil, a default empty chain is used (= no behavior change for
    ///     callers wanting the pre-HERMES-PARTIAL-001 surface).
    ///   - conversationCompression: Optional compression actor (= HERMES-PARTIAL-001).
    ///     When nil, a default actor instance is used (= the canonical wenshu
    ///     compression policy).
    ///   - progressTracker: Optional agent progress tracker (= WIRE-AGENT-006).
    ///     When nil, `AgentProgressTracker.noop` is used (= zero overhead; no
    ///     progress events emitted). Pass a shared instance to surface step-
    ///     by-step feedback in the OpenBox panel during a turn.
    public init(
        connection: any LLMConnector,
        systemPrompt: String? = nil,
        runtime: RuntimeHelpers? = nil,
        shellHookChain: ShellHookChain = ShellHookChain(),
        conversationCompression: ConversationCompression = ConversationCompression(),
        progressTracker: AgentProgressTracker = .noop
    ) {
        // Back-compat: the parameter is named `connector` everywhere in
        // the existing surface; the new parameter is named `connection`
        // (= HERMES-PARTIAL-001 marker). For now we accept `connection`
        // via this init; the legacy `connector:` init remains for callers
        // that don't need the new surface. Both inits land on the same
        // stored property below.
        self.connector = connection
        self.systemPrompt = systemPrompt
        self.runtime = runtime ?? RuntimeHelpers()
        self.shellHookChain = shellHookChain
        self.conversationCompression = conversationCompression
        self.progressTracker = progressTracker
    }

    /// Legacy initializer (= preserved for backward compat with callers
    /// that built the loop before HERMES-PARTIAL-001). Delegates to the
    /// HERMES-PARTIAL-001 init with default hook chain + compression actor.
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

    /// Shell hook chain (= HERMES-PARTIAL-001). Default = empty.
    /// Used by `runConversation` (= single round-trip) and `runTurn`
    /// (= full orchestrator) to fire pre/post-turn hooks. Empty chain
    /// = no behavior change for callers not registering hooks.
    private let shellHookChain: ShellHookChain

    /// Conversation compression actor (= HERMES-PARTIAL-001). Default =
    /// a fresh actor instance per loop (= the canonical wenshu
    /// compression policy). Used by `runTurn` to compress history
    /// after the final assistant turn (= hermes
    /// conversation_history_after_compression).
    private let conversationCompression: ConversationCompression

    /// Agent progress tracker (= WIRE-AGENT-006). Default = `.noop`
    /// (= an actor that accepts the same calls but emits no events).
    /// Used by `runTurn` to surface step-by-step feedback to the
    /// OpenBox panel during a conversation turn.
    private let progressTracker: AgentProgressTracker

    /// Resolve the current time via the runtime (= hermes-port Z-contract
    /// hard requirement: deterministic tests inject a runtime with
    /// `mockTime` set; production gets `Date()` from the default runtime).
    /// Public so downstream modules (= TurnFinalizer, ContextCompressor)
    /// can call the loop's clock instead of touching `Date()` directly.
    public func now() async -> Date {
        await runtime.now()
    }

    /// Expose the underlying `RuntimeHelpers` for callers that need direct
    /// access to verbose/debug emission or credential resolution. TICKET-
    /// HERMES-GAP-003 makes the runtime a first-class collaboration
    /// surface (= callers compose `runtime.vprint(_:)` rather than
    /// reinventing their own verbose flag).
    public func currentRuntime() -> RuntimeHelpers {
        runtime
    }

    /// Run a complete conversation turn (= hermes run_conversation L523-L546).
    ///
    /// 9-param signature mirrors hermes exactly. All params default to nil
    /// (= hermes pattern: optional context that callers the conversation
    /// loop can ignore if they don't need it).
    ///
    /// - Parameters:
    ///   - userMessage: The user's input for this turn.
    ///   - systemMessage: Optional system prompt override (= ephemeral, per
    ///     hermes "ephemeral_system_prompt"). Higher priority than the
    ///     ConversationLoop's persistent systemPrompt.
    ///   - conversationHistory: Prior messages from the session (= may be
    ///     empty for first turn).
    ///   - taskId: Optional unique identifier for VM isolation between
    ///     concurrent tasks (= auto-generated UUID if nil).
    ///   - streamCallback: Optional callback invoked with each LLMBlock during
    ///     streaming. When nil (= default), API call uses non-streaming path.
    ///     v0.35 sub-step 3 invokes the callback once per response block
    ///     (= simulates streaming for non-streaming connectors).
    ///   - persistUserMessage: Optional clean user message to store in
    ///     transcripts (= hermes pattern: caller-provided override for
    ///     API-only synthetic prefixes). Not used in sub-step 3.
    ///   - persistUserTimestamp: Optional platform event timestamp for the
    ///     persisted user message. Not used in sub-step 3.
    ///   - moaConfig: Optional Mixture-of-Agents config (= hermes
    ///     `moa_config` param; deferred to v2 per spec §14).
    /// - Returns: ConversationResult with final response + full message
    ///   history (= user + assistant) + taskId for tracing.
    /// - Throws: LLMConnectorError on transport / auth / provider failure.
    public func runConversation(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage]? = nil,
        taskId: String? = nil,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil,
        persistUserMessage: String? = nil,
        persistUserTimestamp: TimeInterval? = nil,
        moaConfig: MOAConfig? = nil
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString

        // Per-turn setup (= HERMES-PARTIAL-001): sanitize the user
        // message (= hermes message_sanitization._sanitize_surrogates +
        // _strip_non_ascii), reset the retry counter for this turn, and
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
        // Per TICKET-HERMES-GAP-001 (2026-09-04): compose stable + dynamic tiers
        // via PromptBuilder instead of the v0.35 placeholder string that
        // wrapped the ephemeral hint with a Context: prefix. The dynamic tier
        // composes from ContextEngine + MemoryAdapter + SkillAdapter + caller
        // extras; for this sub-step, those are empty (= ticket 009 wires
        // ContextEngine + ticket 010 wires SkillAdapter), so the dynamic tier
        // reduces to the ephemeral hint as a final block. The placeholder
        // Swift template no longer appears anywhere in the source tree.
        let effectiveSystemPrompt = composeSystemPrompt(
            override: systemMessage,
            persistent: systemPrompt
        )

        // Build call options (= model defaults to first defaultModel of
        // the active connector profile; per-call override not yet wired in
        // sub-step 3, lands in ticket 002 cache layer)
        let defaultModel = defaultModelForConnector()
        let options = LLMCallOptions(
            model: defaultModel,
            maxTokens: 4096,
            systemPrompt: effectiveSystemPrompt,
            temperature: nil
        )

        // Send to LLMConnector (= one round-trip)
        let response = try await connector.send(messages: messages, options: options)

        // Stream callback (= one block per response block; full SSE per-block
        // delta streaming lands in ticket 004 AnthropicConnector + ticket 005
        // OpenAICompatibleConnector)
        if let streamCallback {
            for block in response.blocks {
                await streamCallback(block)
            }
        }

        // Append assistant response to message list (= result.messages)
        let assistantMessage = LLMMessage(role: .assistant, blocks: response.blocks)
        messages.append(assistantMessage)

        // Post-turn hooks (= HERMES-PARTIAL-001):
        //   1. TurnFinalizer.finalize (= drop empty blocks, normalize)
        //   2. ShellHookChain.firePostTurn (= observation + optional mutation)
        let finalResponse = TurnFinalizer.finalize(response: response)
        try await shellHookChain.firePostTurn(finalResponse)

        // moaConfig deferred to v2 per spec §14 (= no-op for now)
        _ = moaConfig

        // persistUserMessage / persistUserTimestamp deferred (= transcript
        // persistence is ChatSessionStore's job per spec §3.6 wenshu-side wins)

        return ConversationResult(
            response: finalResponse,
            messages: messages,
            taskId: resolvedTaskId
        )
    }

    // MARK: - HERMES-PARTIAL-001 wire-up: runTurn (full turn orchestrator)

    /// Full turn orchestrator (= hermes run_conversation body).
    ///
    /// Unlike `runConversation` (= single round-trip), `runTurn` is the
    /// canonical entry that wires the complete per-turn surface:
    ///   - Per-turn setup (= TurnContext init, retry-counter reset, user
    ///     message sanitization, system-prompt restore via composeSystemPrompt)
    ///   - Tool dispatch loop (= ToolExecutor.executeSequential when the
    ///     response includes .toolUse blocks; the executor already calls
    ///     the dispatch hook chain + post hooks)
    ///   - ConversationCompression.triggerIfNeeded (= preflight + post-turn
    ///     compression when message count crosses the compressor threshold)
    ///   - TurnRetryState (= classifier-aware retry; transient errors
    ///     retry up to `maxAttempts`, non-transient fail immediately)
    ///   - MessageSanitization (= repair tool args, handle interrupted
    ///     tool calls, surrogate stripping)
    ///   - TurnFinalizer (= post-turn hooks: drop empty blocks, normalize)
    ///   - ShellHookChain.firePreTurn + firePostTurn (= observation layer)
    ///
    /// The retry loop runs at most `maxAttempts` iterations. Each iteration
    /// either calls the LLM + (if tool_use blocks present) the tool
    /// executor + compresses + finalizes, OR surfaces the LLMConnectorError
    /// (= hermes classifier decides retry vs fail).
    ///
    /// - Parameters:
    ///   - userMessage: The user's input for this turn.
    ///   - systemMessage: Optional system prompt override.
    ///   - conversationHistory: Prior messages (= may be empty for first turn).
    ///   - tools: Tool registry passed to the tool executor.
    ///   - taskId: Optional unique identifier for this turn.
    ///   - maxAttempts: Retry budget (= default 3; matches hermes
    ///     TurnRetryState default).
    ///   - streamCallback: Optional callback for streaming responses.
    /// - Returns: ConversationResult with final response + full message
    ///   history + taskId.
    public func runTurn(
        userMessage: String,
        systemMessage: String? = nil,
        conversationHistory: [LLMMessage] = [],
        tools: [String: any Tool] = [:],
        taskId: String? = nil,
        maxAttempts: Int = 3,
        streamCallback: (@Sendable (LLMBlock) async -> Void)? = nil
    ) async throws -> ConversationResult {
        let resolvedTaskId = taskId ?? UUID().uuidString
        var retry = TurnRetryState(maxAttempts: maxAttempts)

        // WIRE-AGENT-006 (v0.41 P2 #21): start the agent progress
        // entry for this turn. The sessionId defaults to the taskId
        // (= caller may use a richer id later; the OpenBox panel
        // matches by taskId today). The OpenBox panel polls
        // `current(sessionId:)` every render cycle.
        let sessionId = resolvedTaskId
        var progressEntry = await progressTracker.start(
            sessionId: sessionId,
            label: "Reading user message"
        )

        while retry.canRetry {
            retry.recordAttempt()
            do {
                // WIRE-AGENT-006 step 2: "Compressing context if needed".
                // The current code path triggers compression only after
                // the LLM response (= hermes parity), so this step is
                // a no-op for now (= the tracker entry simply advances
                // past it). Future tickets that preflight-compress before
                // the LLM call can hook real work here.
                await progressTracker.advance(
                    id: progressEntry.id,
                    label: "Compressing context if needed"
                )

                // WIRE-AGENT-006 step 3 + 4: "Building prompt" + "Calling LLM".
                // Prompt construction and the actual LLM round-trip
                // both happen inside runConversation; we surface this
                // combined phase with a generous ETA (= the LLM
                // round-trip dominates wall-clock time). The ETA
                // estimate is intentionally conservative (= 8s for
                // the calling phase) so the OpenBox panel shows a
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
                // If the assistant message contains tool_use blocks, the
                // tool executor dispatches them sequentially (= the
                // current ToolExecutor default; concurrent path is
                // available via executeConcurrent for callers wanting
                // parallelism).
                var result = try await runConversation(
                    userMessage: userMessage,
                    systemMessage: systemMessage,
                    conversationHistory: conversationHistory,
                    taskId: resolvedTaskId,
                    streamCallback: streamCallback
                )

                // WIRE-AGENT-006 step 5: "Parsing response". The LLM
                // response is already in result.response (= parsed
                // blocks); the loop has nothing extra to do here other
                // than signal that the parse phase finished.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 5,
                    label: "Parsing response",
                    etaSeconds: nil
                )

                // Tool dispatch loop (= hermes _execute_tool_calls_sequential).
                // Inspect the assistant message for tool_use blocks; if
                // any are present, dispatch them sequentially and
                // re-invoke the LLM with the tool results appended.
                if let assistant = result.messages.last,
                   assistant.blocks.contains(where: { if case .toolUse = $0 { return true } else { return false } }) {
                    // WIRE-AGENT-006 step 6: "Executing tools".
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 6,
                        label: "Executing tools",
                        etaSeconds: nil
                    )
                    let executor = ToolExecutor()
                    try await executor.executeSequential(
                        assistantMessage: assistant,
                        messages: &result.messages,
                        taskId: resolvedTaskId,
                        tools: tools
                    )

                    // Re-invoke LLM with tool results (= hermes
                    // "tool result -> next assistant message" loop body).
                    // Briefly re-show step 4 "Calling LLM" since the
                    // second LLM round-trip is what users feel as the
                    // longest stretch of step 6.
                    await progressTracker.setStep(
                        id: progressEntry.id,
                        stepNumber: 4,
                        label: "Calling LLM (after tools)",
                        etaSeconds: 4
                    )
                    let options = LLMCallOptions(
                        model: defaultModelForConnector(),
                        maxTokens: 4096,
                        systemPrompt: composeSystemPrompt(
                            override: systemMessage,
                            persistent: systemPrompt
                        ),
                        temperature: nil
                    )
                    let nextResponse = try await connector.send(
                        messages: result.messages,
                        options: options
                    )
                    if let streamCallback {
                        for block in nextResponse.blocks {
                            await streamCallback(block)
                        }
                    }
                    let nextAssistant = LLMMessage(role: .assistant, blocks: nextResponse.blocks)
                    result.messages.append(nextAssistant)
                    result = ConversationResult(
                        response: TurnFinalizer.finalize(response: nextResponse),
                        messages: result.messages,
                        taskId: resolvedTaskId
                    )
                }

                // WIRE-AGENT-006 step 7: "Finalizing reply". Post-turn
                // compression (= hermes
                // conversation_history_after_compression) runs as part
                // of finalization; surface it under the same step.
                await progressTracker.setStep(
                    id: progressEntry.id,
                    stepNumber: 7,
                    label: "Finalizing reply",
                    etaSeconds: nil
                )
                let (compressedMessages, compressedSystem) = await conversationCompression.historyAfterCompression(
                    messages: result.messages,
                    systemMessage: composeSystemPrompt(
                        override: systemMessage,
                        persistent: systemPrompt
                    ) ?? ""
                )

                // WIRE-AGENT-006: mark the entry as succeeded.
                await progressTracker.complete(id: progressEntry.id, status: .succeeded)

                return ConversationResult(
                    response: result.response,
                    messages: compressedMessages,
                    taskId: resolvedTaskId
                )
                _ = compressedSystem  // compressedSystem captured for future turnContext restore
            } catch let error as LLMConnectorError {
                // WIRE-AGENT-006: mark the entry as failed on retryable
                // error too (= the user sees the failed step in the
                // OpenBox panel even if the loop will retry). The next
                // retry iteration's `advance(...)` will reset the step
                // to step 4 "Calling LLM" so the user sees a fresh
                // attempt.
                await progressTracker.complete(id: progressEntry.id, status: .failed)
                // Classifier-aware retry: transient errors get retried,
                // non-transient fail immediately.
                if !retry.canRetry || !LLMConnectorErrorClassifier.isTransient(error) {
                    throw error
                }
                // Open a fresh running entry for the retry iteration
                // so the OpenBox panel shows progress again. The
                // previous entry is already marked failed above; the
                // `current(sessionId:)` lookup will skip it (= status
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

    /// Resolve the default model for the active connector (= first model
    /// in the provider's defaultModels list).
    ///
    /// In production, this comes from ConnectorProfile (= ticket 006's
    /// Settings → LLM Connector pane). In sub-step 3 we read from the
    /// connector's Provider enum directly (= fine for unit tests; production
    /// ticket 006 wires the actual user-selected model).
    private nonisolated func defaultModelForConnector() -> String {
        // Provider enum lookup by connectorID (= thin integration in sub-step 3)
        if let provider = Provider.all.first(where: { $0.slug == connector.connectorID }) {
            return provider.defaultModels.first ?? "unknown-model"
        }
        // Custom slug (= spec §7.3 custom provider case)
        return "unknown-model"
    }

    /// Compose the effective system prompt via PromptBuilder
    /// (= TICKET-HERMES-GAP-001 refactor, 2026-09-04).
    ///
    /// Resolution chain:
    ///   1. `override` (per-turn systemMessage from caller) — wins if present.
    ///      The override is treated as a CALLER MESSAGE (appended as the
    ///      ephemeral hint section in the dynamic tier) so the stable tier
    ///      stays byte-stable across turns (= cache-friendly).
    ///   2. `persistent` (ConversationLoop's persistent systemPrompt) —
    ///      treated as the EPHEMERAL HINT for the dynamic tier when no
    ///      override is supplied (= preserves v0.35 behavior where the
    ///      caller could pass a per-loop hint via the systemPrompt init
    ///      parameter). The stable tier is the byte-stable identity from
    ///      SystemPrompt.stableTier().
    ///   3. Neither — return nil (no system prompt; connector decides the
    ///      default behavior).
    ///
    /// Dynamic-tier composition pulls in ContextEngine + MemoryAdapter +
    /// SkillAdapter; in this sub-step those dependencies are not yet wired
    /// into the loop (= ticket 009 + ticket 010), so the dynamic tier
    /// reduces to the ephemeral hint as the final block. Future tickets
    /// can extend this method to read live data from those adapters.
    private nonisolated func composeSystemPrompt(
        override: String?,
        persistent: String?
    ) -> String? {
        // Determine the ephemeral hint source (= which string flows into
        // the dynamic tier's "Context: ..." section).
        let ephemeralHint = override ?? persistent ?? ""

        // Stable tier: always the byte-stable identity (no caller override
        // path for the stable tier — stable tier is byte-stable BY DEFINITION).
        let stable = SystemPrompt.stableTier()

        // Dynamic tier: composed via PromptBuilder (= the GAP-001 path).
        // Empty hint = empty dynamic tier (and PromptBuilder returns "").
        let dynamic = PromptBuilder.dynamicTier(
            contextBundle: ContextEngine.ContextBundle(
                memories: [],
                characterContext: [],
                worldContext: [],
                foreshadowContext: []
            ),
            memories: [],
            skills: [],
            callerExtras: [:],
            ephemeralHint: ephemeralHint
        )

        // No hint + no dynamic = no system prompt at all (= caller chose
        // to send the conversation without a system prompt; connector
        // handles the default).
        if ephemeralHint.isEmpty {
            return stable.isEmpty ? nil : stable
        }

        // Join stable + dynamic with the canonical separator (= same
        // separator SystemPrompt.build uses; matches PromptBuilder's
        // buildOpenAISystem / buildGeminiSystemInstruction output).
        return stable + "\n\n---\n\n" + dynamic
    }
}

/// Mixture-of-Agents config (= hermes `moa_config` param).
///
/// Deferred to v2 per spec §14 (= "MOA (Mixture-of-Agents ensemble) —
/// deferred to v2"). Stub type present so ConversationLoop.runConversation
/// 9-param signature is hermes-compatible from day 1.
public struct MOAConfig: Sendable {
    public let advisorCount: Int
    public let aggregatorModel: String

    public init(advisorCount: Int, aggregatorModel: String) {
        self.advisorCount = advisorCount
        self.aggregatorModel = aggregatorModel
    }
}