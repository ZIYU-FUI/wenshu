//
//  WenshuAgentChatProvider.swift · Wenshu · agent runtime boundary
//
//  The app's implementation of the runtime's chat seam.
//
//  The runtime's verifier probes the agent through the app's
//  canonical chat entry point (= `WenshuAgent.shared.chat()`, which
//  routes to the installed conductor). The runtime cannot call an app
//  type, so the app installs this provider and the runtime asks it.
//

import Foundation
import WenshuAgent

/// Bridges the runtime's chat seam to the app's canonical entry point.
struct WenshuAgentChatProvider: AgentChatProvider {

    /// The model the app routes with (= the same model the verifier
    /// asked for before the seam existed).
    var modelIdentifier: String { WenshuLLMModel.m3.rawValue }

    func chat(userMessage: String, sessionId: String, model: String) async -> AgentChatOutcome? {
        guard let result = await WenshuAgent.shared.chat(
            userMessage: userMessage,
            sessionId: sessionId,
            model: model
        ) else {
            // No conductor is installed (= the call site surfaces the
            // failure instead of faking a reply).
            return nil
        }
        return AgentChatOutcome(
            reply: result.reply,
            totalTokens: result.totalTokens,
            thinking: result.thinking
        )
    }
}
