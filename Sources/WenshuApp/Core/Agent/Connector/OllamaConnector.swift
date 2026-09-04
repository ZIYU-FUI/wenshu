//
//  OllamaConnector.swift · Wenshu · §11.2 connector-profile gap-fill
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

public actor OllamaConnector: LLMConnector {
    public nonisolated let connectorID = "ollama"

    private let delegate: OpenAICompatibleConnector

    public init(session: URLSession = .shared) {
        self.delegate = OpenAICompatibleConnector(provider: .ollama, session: session)
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        try await delegate.send(messages: messages, options: options)
    }
}
