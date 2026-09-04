//
//  TurnContext.swift · Wenshu · HERMES-PARTIAL-007 (2026-09-04)
//
//  Per-turn state bundle + per-turn setup helpers.
//  Direct port of hermes agent/turn_context.py (= 565 LOC; provides
//  build_turn_context = the once-per-turn prologue that conversation_loop
//  used to inline as ~470 lines of straight-line setup before the tool
//  loop ever started).
//
//  Per hermes turn_context.py L2-15:
//
//    "All once-per-turn setup -- stdio guarding, runtime-main wiring,
//     retry-counter resets, user-message sanitization, todo/nudge-counter
//     hydration, system-prompt restore-or-build, crash-resilience
//     persistence, preflight context compression, the pre_llm_call plugin
//     hook, and external-memory prefetch -- lives in build_turn_context."
//
//  In sub-step 4 (= the original v0.35 minimum surface) TurnContext was a
//  pure value type bundling the inputs ConversationLoop already used.
//  HERMES-PARTIAL-007 adds the build_turn_context() side-effect driver
//  that performs the actual setup (= reset retry counters, install safe
//     stdio, restore system prompt, refresh credentials) and returns the
//  value type. ConversationLoop.runTurn now calls this once per turn.
//
//  v0.35 sub-step 4 of 8 for ticket 001 + HERMES-PARTIAL-007 (2026-09-04)
//  for ticket 007.
//

import Foundation

public struct TurnContext: Sendable, Equatable {
    public let taskId: String
    public let userMessage: String
    public let systemMessage: String?
    public let conversationHistory: [LLMMessage]
    public let model: String
    public let maxTokens: Int
    public let attemptNumber: Int

    /// Timestamp the per-turn setup completed (= .now when build_turn_context ran).
    public let builtAt: Date

    /// Per-turn retry-counter reset log (= hermes `agent._invalid_tool_retries = 0`
    /// etc. inline assignments).
    public let resetCounters: [String: Int]

    public init(
        taskId: String,
        userMessage: String,
        systemMessage: String?,
        conversationHistory: [LLMMessage],
        model: String,
        maxTokens: Int,
        attemptNumber: Int,
        builtAt: Date = .now,
        resetCounters: [String: Int] = [:]
    ) {
        self.taskId = taskId
        self.userMessage = userMessage
        self.systemMessage = systemMessage
        self.conversationHistory = conversationHistory
        self.model = model
        self.maxTokens = maxTokens
        self.attemptNumber = attemptNumber
        self.builtAt = builtAt
        self.resetCounters = resetCounters
    }
}

/// Per-turn setup driver. Performs the once-per-turn side effects
/// (= hermes build_turn_context body L119-565) and produces a TurnContext.
///
/// Each side effect is exposed as a closure that the caller wires through;
/// the driver itself only orchestrates (= hermes pattern: the original
/// prologue mutated agent heavily, so the helpers are passed in explicitly
/// to keep the module free of import cycles with the agent runtime).
public struct TurnContextBuilder: Sendable {

    /// Side-effect hooks (= hermes passes these into build_turn_context as
    /// explicit callables so the module stays free of agent imports).
    public struct Hooks: Sendable {
        /// Install safe stdio (= guard against OSError from broken pipes
        /// under systemd/headless/daemon launches).
        public var installSafeStdio: @Sendable () -> Void
        /// Sanitize surrogate characters from a user string (= NFC + strip
        /// unpaired surrogates).
        public var sanitizeSurrogates: @Sendable (String) -> String
        /// Restore the primary runtime (= undo any fallback that activated
        /// in the previous turn).
        public var restorePrimaryRuntime: @Sendable () -> Void
        /// Set the auxiliary client's runtime main (= provider / model /
        /// base_url / api_key / api_mode).
        public var setAuxiliaryRuntimeMain: @Sendable (String, String, String, String, String) -> Void
        /// Reset the tool guardrails for a fresh turn.
        public var resetToolGuardrails: @Sendable () -> Void
        /// Refresh credentials (= oauth / api key rotation before the turn).
        public var refreshCredentials: @Sendable () -> Void
        /// Restore the cached system prompt (or rebuild from scratch if missing).
        public var restoreOrBuildSystemPrompt: @Sendable () -> String?
        /// Reset all retry counters (= invalid_tool_retries,
        /// invalid_json_retries, empty_content_retries,
        /// incomplete_scratchpad_retries, codex_incomplete_retries,
        /// thinking_prefill_retries, post_tool_empty_retried, etc.).
        public var resetRetryCounters: @Sendable () -> [String: Int]
        /// Persist the user message (= DB / session row).
        public var persistUserMessage: @Sendable (String, String?) -> Void

        public init(
            installSafeStdio: @escaping @Sendable () -> Void = {},
            sanitizeSurrogates: @escaping @Sendable (String) -> String = { $0 },
            restorePrimaryRuntime: @escaping @Sendable () -> Void = {},
            setAuxiliaryRuntimeMain: @escaping @Sendable (String, String, String, String, String) -> Void = { _, _, _, _, _ in },
            resetToolGuardrails: @escaping @Sendable () -> Void = {},
            refreshCredentials: @escaping @Sendable () -> Void = {},
            restoreOrBuildSystemPrompt: @escaping @Sendable () -> String? = { nil },
            resetRetryCounters: @escaping @Sendable () -> [String: Int] = { [:] },
            persistUserMessage: @escaping @Sendable (String, String?) -> Void = { _, _ in }
        ) {
            self.installSafeStdio = installSafeStdio
            self.sanitizeSurrogates = sanitizeSurrogates
            self.restorePrimaryRuntime = restorePrimaryRuntime
            self.setAuxiliaryRuntimeMain = setAuxiliaryRuntimeMain
            self.resetToolGuardrails = resetToolGuardrails
            self.refreshCredentials = refreshCredentials
            self.restoreOrBuildSystemPrompt = restoreOrBuildSystemPrompt
            self.resetRetryCounters = resetRetryCounters
            self.persistUserMessage = persistUserMessage
        }

        /// Default no-op hooks (= for tests).
        public static let noop = Hooks()
    }

    public let hooks: Hooks
    public init(hooks: Hooks = .noop) { self.hooks = hooks }

    /// Run the once-per-turn setup and return the loop's input context
    /// (= hermes build_turn_context L119-565 body).
    ///
    /// Operations performed (in order, matching hermes):
    ///   1. installSafeStdio                  — guard against broken pipes
    ///   2. setAuxiliaryRuntimeMain           — tell auxiliary_client who the
    ///      main provider/model are this turn
    ///   3. restorePrimaryRuntime             — undo prior-turn fallback
    ///   4. refreshCredentials                — rotate oauth/api keys before use
    ///   5. resetRetryCounters                — zero the 8 retry counters
    ///   6. resetToolGuardrails               — fresh guardrail state per turn
    ///   7. sanitizeSurrogates(userMessage)   — strip unpaired surrogates
    ///   8. restoreOrBuildSystemPrompt        — cache-stable identity layer
    ///   9. persistUserMessage                — DB / session row
    @discardableResult
    public func buildTurnContext(
        userMessage: String,
        conversationHistory: [LLMMessage],
        model: String,
        maxTokens: Int = 4096,
        taskId: String = UUID().uuidString,
        attemptNumber: Int = 0,
        provider: String = "",
        baseURL: String = "",
        apiKey: String = "",
        apiMode: String = ""
    ) -> TurnContext {
        // 1. stdio guard
        hooks.installSafeStdio()

        // 2. auxiliary client runtime main
        hooks.setAuxiliaryRuntimeMain(provider, model, baseURL, apiKey, apiMode)

        // 3. restore primary runtime (= undo prior fallback)
        hooks.restorePrimaryRuntime()

        // 4. refresh credentials
        hooks.refreshCredentials()

        // 5. reset retry counters + capture them for the context bundle
        let reset = hooks.resetRetryCounters()

        // 6. reset tool guardrails
        hooks.resetToolGuardrails()

        // 7. sanitize surrogates on the user message (= hermes
        //    sanitize_surrogates(user_message) at L205-208)
        let cleanUser = hooks.sanitizeSurrogates(userMessage)

        // 8. restore-or-build system prompt (= cache-stable identity)
        let system = hooks.restoreOrBuildSystemPrompt()

        // 9. persist the user message (= DB row creation)
        hooks.persistUserMessage(cleanUser, nil)

        return TurnContext(
            taskId: taskId,
            userMessage: cleanUser,
            systemMessage: system,
            conversationHistory: conversationHistory,
            model: model,
            maxTokens: maxTokens,
            attemptNumber: attemptNumber,
            builtAt: .now,
            resetCounters: reset
        )
    }

    /// Compute whether a preflight compression pass should run
    /// (= hermes _should_run_preflight_estimate L64-92).
    ///
    /// Returns `true` when either:
    ///   (a) message count exceeds the protected ranges, or
    ///   (b) a cheap char-based estimate already crosses the threshold.
    public static func shouldRunPreflightEstimate(
        messagesCount: Int,
        protectFirstN: Int,
        protectLastN: Int,
        thresholdTokens: Int,
        estimatedTokens: Int
    ) -> Bool {
        if messagesCount > protectFirstN + protectLastN + 1 {
            return true
        }
        return estimatedTokens >= thresholdTokens
    }

    /// Compute whether a compression pass made material progress
    /// (= hermes _compression_made_progress L41-58).
    ///
    /// Token reduction must be material (>5%) to count as progress so a
    /// sub-5% wobble doesn't keep the multi-pass loop spinning.
    public static func compressionMadeProgress(
        origMessageCount: Int,
        newMessageCount: Int,
        origTokens: Int,
        newTokens: Int
    ) -> Bool {
        if newMessageCount < origMessageCount {
            return true
        }
        return origTokens > 0 && newTokens < Int(Double(origTokens) * 0.95)
    }
}