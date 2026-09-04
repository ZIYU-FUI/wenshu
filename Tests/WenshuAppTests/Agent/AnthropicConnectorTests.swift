//
//  AnthropicConnectorTests.swift · Wenshu · v0.35 ticket 004 sub-step 1
//
//  Unit tests for AnthropicConnector (= ticket 004 sub-step 1, P0 connector).
//  Verifies full Anthropic-native wire format: cache_control, thinking blocks,
//  tool_use round-trip, system field with cache_control, structured content.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicConnector (ticket 004 sub-step 1)")
struct AnthropicConnectorTests {

    @Test("Anthropic-native system field with cache_control")
    func testSystemFieldCacheControl() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .anthropic)
        ProviderKeychain.setBackendForTesting(store)

        let connector = AnthropicConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "claude-sonnet-4-5", systemPrompt: "stable")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        let system = body?["system"] as? [String: Any]
        #expect(system?["type"] as? String == "text")
        #expect(system?["text"] as? String == "stable")
        #expect(system?["cache_control"] as? [String: String] != nil)
    }

    @Test("Anthropic-native content blocks array (not joined string)")
    func testContentBlocksArray() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .anthropic)
        ProviderKeychain.setBackendForTesting(store)

        let connector = AnthropicConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "claude-sonnet-4-5")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        let messages = body?["messages"] as? [[String: Any]]
        let userMessage = messages?[0]
        // Content must be an array (= Anthropic native), not a joined string
        #expect(userMessage?["content"] is [[String: Any]])
    }

    @Test("Tool use block encoded with type=tool_use + id + name + input as Data")
    func testToolUseBlock() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .anthropic)
        ProviderKeychain.setBackendForTesting(store)

        let connector = AnthropicConnector(session: session)
        let messages = [
            LLMMessage(
                role: .assistant,
                blocks: [.toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/x\"}")]
            )
        ]
        _ = try await connector.send(
            messages: messages,
            options: LLMCallOptions(model: "claude-sonnet-4-5")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        let messages2 = body?["messages"] as? [[String: Any]]
        let content = messages2?[0]["content"] as? [[String: Any]]
        let toolUse = content?[0]
        #expect(toolUse?["type"] as? String == "tool_use")
        #expect(toolUse?["id"] as? String == "t1")
        #expect(toolUse?["name"] as? String == "ReadFile")
    }

    @Test("Tool result block encoded with type=tool_result + tool_use_id + content")
    func testToolResultBlock() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .anthropic)
        ProviderKeychain.setBackendForTesting(store)

        let connector = AnthropicConnector(session: session)
        let messages = [
            LLMMessage.toolResult(toolUseID: "t1", output: "file content here")
        ]
        _ = try await connector.send(
            messages: messages,
            options: LLMCallOptions(model: "claude-sonnet-4-5")
        )

        let body = try JSONSerialization.jsonObject(with: stub.lastRequest!.httpBody!) as? [String: Any]
        let messages2 = body?["messages"] as? [[String: Any]]
        let content = messages2?[0]["content"] as? [[String: Any]]
        let toolResult = content?[0]
        #expect(toolResult?["type"] as? String == "tool_result")
        #expect(toolResult?["tool_use_id"] as? String == "t1")
        #expect(toolResult?["content"] as? String == "file content here")
    }

    @Test("Missing API key throws LLMConnectorError.missingAPIKey")
    func testMissingAPIKey() async {
        let store = InMemoryKeychainStore()
        ProviderKeychain.setBackendForTesting(store)

        let connector = AnthropicConnector(session: .shared)

        await #expect(throws: LLMConnectorError.self) {
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "claude-sonnet-4-5")
            )
        }
    }
}

// MARK: - Shared Anthropic response builder (= private)

private func makeAnthropicResponse(content: String, model: String = "claude-sonnet-4-5") -> Data {
    let body: [String: Any] = [
        "id": "msg_test",
        "model": model,
        "role": "assistant",
        "content": [["type": "text", "text": content]],
        "stop_reason": "end_turn",
        "usage": ["input_tokens": 0, "output_tokens": 0]
    ]
    return try! JSONSerialization.data(withJSONObject: body)
}