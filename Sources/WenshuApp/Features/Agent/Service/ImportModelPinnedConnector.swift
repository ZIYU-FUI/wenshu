// ImportModelPinnedConnector.swift · wenshu
//
// Pins the model of every call made through a wrapped connector.
//
// Why this exists: the agent's turn loop resolves the model from the
// CONNECTOR (= the provider's first default model), so a driver that holds
// a model slug never reaches the request. The import driver holds the
// user's picked model (= `wenshu.llm.model`), and the import must run on
// THAT model, not on the provider's first default.
//
// Why it lives here and not in the agent package: the turn loop's public
// API takes no model, and the rule for this project is that a caller
// must not add a parameter to the runtime's public turn function. A
// connector is the request's own carrier (= every connector sends
// `options.model` to the provider), so pinning the model at that seam
// needs no change to the runtime at all.

import Foundation
import WenshuAgent

/// A connector that sends every call on one fixed model.
///
/// The wrapped connector does the transport; this type only replaces the
/// model in the call options, so the provider receives the model the
/// user picked and the request's other settings (= the system prompt, the
/// token cap, the tool declarations) reach the provider unchanged.
struct ImportModelPinnedConnector: LLMConnector {

    /// The connector that does the transport.
    let base: any LLMConnector

    /// The model every call goes out on.
    let model: String

    init(base: any LLMConnector, model: String) {
        self.base = base
        self.model = model
    }

    var connectorID: String { base.connectorID }

    var contextWindow: Int { base.contextWindow }

    func send(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) async throws -> LLMResponse {
        try await base.send(messages: messages, options: pinned(options))
    }

    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        base.stream(messages: messages, options: pinned(options))
    }

    /// The same call options, with the model replaced.
    private func pinned(_ options: LLMCallOptions) -> LLMCallOptions {
        LLMCallOptions(
            model: model,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            temperature: options.temperature,
            reasoningEffort: options.reasoningEffort,
            tools: options.tools
        )
    }
}
