//
//  ConversationLoop.swift · Wenshu · v0.35 ticket 001 sub-step 3
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

    /// Build a ConversationLoop bound to an active LLMConnector.
    ///
    /// - Parameters:
    ///   - connector: The active connector profile (= e.g. minimax cn,
    ///     Anthropic, OpenAI, Gemini, DeepSeek, Ollama, OpenRouter).
    ///   - systemPrompt: Optional byte-stable system prompt prefix (= per
    ///     AGENTS.md §11.3 cache-stable invariant; full cache_control marker
    ///     lands in ticket 002 PromptCaching.swift).
    public init(connector: any LLMConnector, systemPrompt: String? = nil) {
        self.connector = connector
        self.systemPrompt = systemPrompt
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
        let effectiveSystemPrompt = systemMessage ?? systemPrompt

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