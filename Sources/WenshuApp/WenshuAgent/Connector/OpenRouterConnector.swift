//
//  OpenRouterConnector.swift
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
import WenshuAgent

actor OpenRouterConnector: LLMConnector {
    nonisolated let connectorID = "openrouter"

    private let delegate: OpenAICompatibleConnector

    init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .openrouter, session: session)
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }

    // MARK: - Native streaming (P0-AGENT-STREAMING, boss 2026-10-16)
    //
    // OpenRouter is an OpenAI-compat multi-provider router. The wire
    // format is byte-compatible with the OpenAI chat-completions
    // protocol (= `Authorization: Bearer <key>` + the same SSE
    // chunk shape). The native streaming SSE path lives in
    // `OpenAIStreamingWireupFactory.streamingStream` (= reused
    // wholesale; = the upstream emits OpenAI-shaped chunk events
    // that `OpenAIChunkToLLMBlockConverter` maps to LLMBlock).
    //
    // `nonisolated` (T9 protocol conformance): the underlying
    // `OpenAIStreamingWireupFactory.streamingStream` is `static`
    // and accepts the credentials by value (= Sendable + immutable
    // across actor contexts).
    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        let credentials = ConnectorCredentials.resolve(for: .openrouter)

        // Empty key -> emit synthetic error block (= no silent
        // stream end; = matches OpenAIConnector + DeepSeek pattern).
        if credentials.apiKey.isEmpty {
            return OpenAIChunkToLLMBlockConverter.errorStream(
                "[stream error] missing API key for openrouter",
                provider: connectorID
            )
        }

        // OpenRouter accepts `Authorization: Bearer <key>` (= the
        // OpenAI convention).
        let bearer = credentials.apiKey

        let rawStream = OpenAIStreamingWireupFactory.streamingStream(
            credentials: credentials,
            model: options.model,
            maxTokens: options.maxTokens,
            systemPrompt: options.systemPrompt,
            messages: messages,
            bearerToken: bearer,
            tools: options.tools
        )
        // T12b: stateful converter (= aggregates tool_calls across
        // chunks). = the agent's ReAct loop sees coherent .toolUse
        // blocks.
        let accumulator = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        return OpenAIChunkToLLMBlockConverter.convert(
            stream: rawStream,
            accumulator: accumulator
        )
    }
}
