//
//  OpenAIConnectorTests.swift · Wenshu · v0.35 ticket 005
//
//  Unit tests for OpenAIConnector + OpenAICompatibleConnector
//  (= ticket 005, P0 connector for both OpenAI native + all
//  OpenAI-compatible providers).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OpenAIConnector (ticket 005)")
struct OpenAIConnectorTests {

    @Test("OpenAI native: Bearer auth + Authorization header")
    func testOpenAINativeAuth() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "hi")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-openai-test", for: .openaiCodex)
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAIConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("hi")],
            options: LLMCallOptions(model: "gpt-5")
        )

        let captured = stub.lastRequest
        let auth = captured?.value(forHTTPHeaderField: "Authorization")
        #expect(auth == "Bearer sk-openai-test")
        #expect(captured?.url?.path.contains("/chat/completions") == true)
    }

    @Test("OpenAI native: system message prepended in messages array")
    func testSystemPrepended() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk", for: .openaiCodex)
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAIConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("hi")],
            options: LLMCallOptions(model: "gpt-5", systemPrompt: "you are helpful")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        let messages = body?["messages"] as? [[String: Any]]
        #expect(messages?[0]["role"] as? String == "system")
        #expect(messages?[0]["content"] as? String == "you are helpful")
        #expect(messages?[1]["role"] as? String == "user")
    }

    @Test("OpenAI-compatible (DeepSeek): connectorID = 'deepseek' + base URL")
    func testOpenAICompatibleDeepSeek() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-ds", for: .deepseek)
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAICompatibleConnector(provider: .deepseek, session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "deepseek-chat")
        )

        #expect(connector.connectorID == "deepseek")
        let captured = stub.lastRequest
        #expect(captured?.url?.host == "api.deepseek.com")
    }

    @Test("Ollama: empty apiKey allowed (no auth required per AGENTS.md §11.2)")
    func testOllamaNoAuth() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        // No key saved for ollama
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAICompatibleConnector(provider: .ollama, session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "llama3.3")
        )

        let captured = stub.lastRequest
        #expect(captured?.url?.host == "localhost")
        #expect(captured?.url?.port == 11434)
        // No Authorization header for Ollama
        #expect(captured?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("OpenAI-compatible (Ollama): missing key does NOT throw")
    func testOllamaMissingKeyNoThrow() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAICompatibleConnector(provider: .ollama, session: session)
        // Should NOT throw missingAPIKey (= Ollama no-auth)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "llama3.3")
        )
    }
}

// MARK: - Shared OpenAI response builder

private func makeOpenAIResponse(content: String, model: String = "gpt-5") -> Data {
    let body: [String: Any] = [
        "id": "chatcmpl-test",
        "object": "chat.completion",
        "model": model,
        "choices": [
            [
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": content
                ],
                "finish_reason": "stop"
            ]
        ],
        "usage": [
            "prompt_tokens": 0,
            "completion_tokens": 0,
            "total_tokens": 0
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: body)
}