//
//  DeepSeekConnector.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  DeepSeek connector (= one of 7 LLM connector profiles per AGENTS.md §11.2).
//
//  DeepSeek exposes an OpenAI-compatible chat completions endpoint at
//  https://api.deepseek.com/v1/chat/completions (= same wire format as
//  OpenAI native, with `Authorization: Bearer <DEEPSEEK_API_KEY>`).
//
//  Per AGENTS.md §11.3 wenshu-side wins: this struct is a thin typed wrapper
//  over the shared `OpenAICompatibleConnector` (= it owns the slug identity
//  + the credential resolver, but delegates wire-format marshaling and HTTP
//  transport to the existing openai-compatible path via RequestHelpers).
//
//  This is intentional duplication-by-identity: callers that need a DeepSeek-
//  specific connector (= e.g. ProviderPicker, per-connector tests, or any
//  downstream that switches on `connectorID == "deepseek"`) get a typed
//  entry point that matches the shape of AnthropicConnector / OpenAIConnector
//  / GeminiNativeConnector / MinimaxConnector. The actual HTTP path stays
//  single-source-of-truth in `OpenAICompatibleConnector`.
//

import Foundation

public actor DeepSeekConnector: LLMConnector {
    public nonisolated let connectorID = "deepseek"

    private let delegate: OpenAICompatibleConnector

    public init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .deepseek, session: session)
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }
}
