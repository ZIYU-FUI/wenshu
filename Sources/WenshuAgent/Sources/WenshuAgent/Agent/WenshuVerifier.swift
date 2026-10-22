// WenshuVerifier.swift
//
// Verifier that proves the wenshu `AgentProtocol` works against the
// minimax-cn key.
//
// Plain-language summary (user-readable):
//   - wenshu `AgentProtocol` (A2A protocol) → minimax-cn API
//     (Anthropic-compatible protocol).
//   - Goal: use the minimax-cn key to call the `MiniMax-M3` model;
//     verify a "ping" returns HTTP 200.
//   - Tests: (1) ping returns 200. (2) wenshu `AgentProtocol`
//     integrates with the minimax-cn API.

import Foundation
import os

// AUDIT.md §2.6 partial (2026-10-16 boss 2026-10-16 OOB
// "包要有 LOG 能力" arc): WenshuVerifier used to log to
// `com.wenshu/wenshuverifier` (= the legacy WenshuApp
// subsystem). The boss's "包要有 LOG 能力" directive
// means all agent / LLM-related logs should land in
// `com.wenshu.agent/...` (= the canonical WALogger
// subsystem; = matches hermes `agent.Agent` log
// shape; = the boss can filter Console.app by
// subsystem:com.wenshu.agent and see the full LLM
// trace).
private let wenshuLogger = Logger(subsystem: "com.wenshu.agent", category: "agent")

/// minimax-cn ground-truth probe (Anthropic-compatible protocol)
/// WenshuVerifier: ground-truth probe for wenshu AgentProtocol against the minimax-cn API
public actor WenshuVerifier {
    // AUDIT.md §2.6 partial (2026-10-16 boss "清老代码必须做完" arc):
    // the actor's chat/ping/send methods (= the legacy LLM probe) have been
    // deleted; = the WenshuLLM* types now live in WenshuLLMTypes.swift. The
    // actor itself remains as a bridge for the 2 remaining callers that
    // still construct it (= AgentProtocol A2A + ConversationOps
    // summarize); = this chat() method delegates to the canonical
    // `WenshuAgent.shared.chat()` entry point and translates the
    // WenshuLLMResponse back (= the legacy reply type) so the callers'
    // downstream code does not need to migrate in this arc.
    public init() {}

    /// Bridge: delegates to WenshuAgent.shared.chat() (= the canonical
    /// LLM call entry point) and translates the (reply, tokens, thinking)
    /// tuple back into the legacy WenshuLLMResponse shape (= so
    /// ConversationOps.summarizeIfNeeded + AgentProtocol.handleMessageSend
    /// keep working unchanged).
    public func chat(_ text: String) async throws -> WenshuLLMResponse {
        // The app owns the chat entry point (= the installed
        // conductor, the provider key, the model choice), so the
        // runtime asks the installed provider instead of naming an
        // app type.
        guard let provider = AgentChatProviders.current else {
            throw LLMConnectorError.streamingFailed(provider: "wenshu-verifier-bridge")
        }
        // Use the resolved model from the active keychain (= the same
        // logic the deleted method used; = the WenshuLLMModel.allCases
        // .first is the historical default).
        let model = provider.modelIdentifier
        guard let r = await provider.chat(
            userMessage: text,
            sessionId: "wenshu-verifier-bridge",
            model: model
        ) else {
            throw LLMConnectorError.streamingFailed(provider: "wenshu-verifier-bridge")
        }
        // Translate the canonical (reply, tokens, thinking) tuple into
        // the legacy WenshuLLMResponse shape. The legacy consumers
        // (= ConversationOps + AgentProtocol) only read .content
        // (= a [WenshuLLMBlock] of .text cases), .id, .stop_reason,
        // and .usage. The legacy .displayText accessor on WenshuLLMBlock
        // = .text(s).s.
        let blocks: [WenshuLLMBlock] = [WenshuLLMBlock.text(r.reply)]
        return WenshuLLMResponse(
            id: "wenshu-verifier-bridge-\(UUID().uuidString)",
            model: model,
            role: "assistant",
            content: blocks,
            stop_reason: "end_turn",
            usage: WenshuLLMUsage(input_tokens: 0, output_tokens: r.totalTokens)
        )
    }
}
