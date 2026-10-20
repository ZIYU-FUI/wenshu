//
//  DeepSeekConnector.swift
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
import WenshuAgent

actor DeepSeekConnector: LLMConnector {
    nonisolated let connectorID = "deepseek"

    private let delegate: OpenAICompatibleConnector

    init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .deepseek, session: session)
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }

    // MARK: - Native streaming (P0-AGENT-STREAMING, boss 2026-10-16)
    //
    // DeepSeek uses the OpenAI chat-completions protocol (= the same
    // wire format as `OpenAIConnector`). The native streaming SSE
    // path lives in `OpenAIStreamingWireupFactory.streamingStream`
    // (= reused wholesale; = DeepSeek has a documented `stream:
    // true` flag; = the upstream emits OpenAI-shaped chunk events
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
        let credentials = ConnectorCredentials.resolve(for: .deepseek)

        // Empty key -> emit synthetic error block (= no silent
        // stream end; = matches OpenAIConnector + AnthropicConnector
        // pattern).
        if credentials.apiKey.isEmpty {
            return OpenAIChunkToLLMBlockConverter.errorStream(
                "[stream error] missing API key for deepseek",
                provider: connectorID
            )
        }

        // DeepSeek accepts `Authorization: Bearer <key>` (= the OpenAI
        // convention; = not `x-api-key` like Anthropic / Minimax).
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
        // blocks (= no half-built tool calls in the chat).
        let accumulator = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        return OpenAIChunkToLLMBlockConverter.convert(
            stream: rawStream,
            accumulator: accumulator
        )
    }
}
