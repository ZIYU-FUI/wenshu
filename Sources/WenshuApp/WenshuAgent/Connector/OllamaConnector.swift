//
//  OllamaConnector.swift
//
//  Ollama connector (= one of 7 LLM connector profiles per AGENTS.md §11.2).
//
//  Ollama is a LOCAL model server (= http://localhost:11434/v1 by default).
//  Per AGENTS.md §11.2 row "Ollama | None (local)": no API key required,
//  requests go to localhost:11434 with the OpenAI-compatible chat
//  completions protocol (= same wire format as OpenAI native).
//
//  Per AGENTS.md §11.3 wenshu-side wins: this struct is a thin typed wrapper
//  over the shared `OpenAICompatibleConnector` (= it owns the slug identity
//  + the credential resolver, but delegates wire-format marshaling and HTTP
//  transport to the existing openai-compatible path via RequestHelpers).
//
//  Special handling: `OpenAICompatibleConnector.send` skips Bearer auth when
//  the resolved credentials have an empty apiKey (= Ollama's no-auth case).
//  See ConnectorCredentials.resolve: Ollama slug forces key = "" without
//  hitting the Keychain.
//

import Foundation
import WenshuAgent

actor OllamaConnector: LLMConnector {
    nonisolated let connectorID = "ollama"

    private let delegate: OpenAICompatibleConnector

    init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .ollama, session: session)
    }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }

    // MARK: - Native streaming (P0-AGENT-STREAMING, boss 2026-10-16)
    //
    // Ollama's `/v1/chat/completions` endpoint is OpenAI-compatible
    // (= per Ollama docs; = the same wire format as `OpenAIConnector`
    // and `DeepSeekConnector`; = `stream: true` flag + OpenAI-shaped
    // SSE chunk events). No API key = no `Authorization` header
    // (= the empty-key path in `OpenAIStreamingWireupFactory`
    // handles this by setting bearer = nil).
    //
    // `nonisolated` (T9 protocol conformance): the underlying
    // `OpenAIStreamingWireupFactory.streamingStream` is `static`
    // and accepts the credentials by value (= Sendable + immutable
    // across actor contexts).
    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        let credentials = ConnectorCredentials.resolve(for: .ollama)

        // Ollama = no API key. The credentials resolver enforces
        // an empty apiKey for the .ollama slug; = the no-auth
        // path here matches that contract. If the resolver is
        // ever changed to require a key, the empty-key branch
        // below emits a synthetic error block (= same as the
        // other connectors; = no silent stream end).
        let bearer: String? = credentials.apiKey.isEmpty ? nil : credentials.apiKey

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
        // blocks. Note: local Ollama typically does NOT support
        // tool_use; = the converter's tool aggregator degrades
        // gracefully (= no .toolUse blocks emitted; = text only).
        let accumulator = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        return OpenAIChunkToLLMBlockConverter.convert(
            stream: rawStream,
            accumulator: accumulator
        )
    }
}
