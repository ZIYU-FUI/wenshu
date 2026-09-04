//
//  OpenRouterConnector.swift · Wenshu · §11.2 connector-profile gap-fill
//
//  OpenRouter connector (= one of 7 LLM connector profiles per AGENTS.md §11.2).
//
//  OpenRouter exposes an OpenAI-compatible chat completions endpoint at
//  https://openrouter.ai/api/v1/chat/completions (= multi-provider router
//  that proxies Anthropic, OpenAI, DeepSeek, Meta, Google, etc. behind a
//  single API key + OpenAI wire format).
//
//  Per AGENTS.md §11.3 wenshu-side wins: this struct is a thin typed wrapper
//  over the shared `OpenAICompatibleConnector` (= it owns the slug identity
//  + the credential resolver, but delegates wire-format marshaling and HTTP
//  transport to the existing openai-compatible path via RequestHelpers).
//
//  Per AGENTS.md §11.2 row "OpenRouter | OPENROUTER_API_KEY | Multi-provider
//  router (Anthropic, OpenAI, Google, Meta via single endpoint)": auth is
//  Bearer, base URL = https://openrouter.ai/api/v1, default models include
//  `anthropic/claude-opus-4.8` and `deepseek/deepseek-v4-pro`.
//

import Foundation

public actor OpenRouterConnector: LLMConnector {
    public nonisolated let connectorID = "openrouter"

    private let delegate: OpenAICompatibleConnector

    public init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .openrouter, session: session)
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }
}
