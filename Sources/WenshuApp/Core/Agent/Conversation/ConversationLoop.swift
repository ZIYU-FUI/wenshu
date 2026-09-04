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

import Foundation

/// Result of a single ConversationLoop.runConversation call.
///
/// Mirrors hermes' `Dict[str, Any]` return shape (= final response +
/// full message history + taskId for tracing + telemetry).
public struct ConversationResult: Sendable {
    public let response: LLMResponse
    public let messages: [LLMMessage]
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
    public init(
        connector: any LLMConnector,
        systemPrompt: String? = nil,
        runtime: RuntimeHelpers? = nil
    ) {
        self.connector = connector
        self.systemPrompt = systemPrompt
        self.runtime = runtime ?? RuntimeHelpers()
    }

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

        // Build message list = prior history + new user message
        var messages = conversationHistory ?? []
        messages.append(LLMMessage.user(userMessage))

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

        // moaConfig deferred to v2 per spec §14 (= no-op for now)
        _ = moaConfig

        // persistUserMessage / persistUserTimestamp deferred (= transcript
        // persistence is ChatSessionStore's job per spec §3.6 wenshu-side wins)

        return ConversationResult(
            response: response,
            messages: messages,
            taskId: resolvedTaskId
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