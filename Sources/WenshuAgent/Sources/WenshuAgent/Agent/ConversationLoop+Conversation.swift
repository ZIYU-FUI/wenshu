// ConversationLoop+Conversation.swift = part of ConversationLoop, = = moved out of ConversationLoop.swift.
// The members below keep their own comments; = = the actor's stored
// properties stay in ConversationLoop.swift (= = an actor's stored
// properties cannot live in an extension).

import Foundation
import os.log

public extension ConversationLoop {
    /// Runs a complete conversation turn (= the hermes `run_conversation`).
    /// It throws `LLMConnectorError` on a transport, auth or provider failure.
    func runConversation(
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
        // via PromptBuilder instead of a placeholder string that wrapped
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
}
