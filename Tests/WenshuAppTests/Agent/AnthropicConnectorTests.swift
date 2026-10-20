//
//  AnthropicConnectorTests.swift · Wenshu · v0.35 ticket 004 sub-step 1
//
//  Unit tests for AnthropicConnector (= ticket 004 sub-step 1, P0 connector).
//  Verifies full Anthropic-native wire format: cache_control, thinking blocks,
//  tool_use round-trip, system field with cache_control, structured content.
//
//  Stubbing is per test (`makeIsolatedStub`) rather than process-global
//  (`URLProtocolStub.register`). The global form registers the class for the
//  whole process and parks the canned response in a class-level static, so a
//  suite running in parallel reads whichever stub registered last. That made
//  this file fail its neighbours (Exa / MCP / Parallel / Keenable) whenever the
//  two ran together, while both passed alone.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicConnector (ticket 004 sub-step 1)", .serialized)
struct AnthropicConnectorTests {

    // MARK: - Harness

    /// A session wired to a stub that belongs to this test alone.
    private func makeSession() -> (session: URLSession, stub: URLProtocolStub) {
        let (stub, protocolClass) = URLProtocolStub.makeIsolatedStub()
        stub.response = makeAnthropicResponse(content: "ok")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [protocolClass]
        return (URLSession(configuration: config), stub)
    }

    private func keychainWithTestKey() throws -> InMemoryKeychainStore {
        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .anthropic)
        return store
    }

    // MARK: - Wire format

    @Test("Anthropic-native system field with cache_control")
    func testSystemFieldCacheControl() async throws {
        let (session, stub) = makeSession()
        let store = try keychainWithTestKey()

        try await ProviderKeychain.withBackendForTesting(store) {
            let connector = AnthropicConnector(session: session)
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "claude-sonnet-4-5", systemPrompt: "stable")
            )
        }

        let body = try decodedBody(from: stub)
        let system = body?["system"] as? [String: Any]
        #expect(system?["type"] as? String == "text")
        #expect(system?["text"] as? String == "stable")
        #expect(system?["cache_control"] as? [String: String] != nil)
    }

    @Test("Anthropic-native content blocks array (not joined string)")
    func testContentBlocksArray() async throws {
        let (session, stub) = makeSession()
        let store = try keychainWithTestKey()

        try await ProviderKeychain.withBackendForTesting(store) {
            let connector = AnthropicConnector(session: session)
            _ = try await connector.send(
                messages: [LLMMessage.user("test")],
                options: LLMCallOptions(model: "claude-sonnet-4-5")
            )
        }

        let body = try decodedBody(from: stub)
        let userMessage = (body?["messages"] as? [[String: Any]])?.first
        // Content must be an array (= Anthropic native), not a joined string
        #expect(userMessage?["content"] is [[String: Any]])
    }

    @Test("Tool use block encoded with type=tool_use + id + name + input as JSON object")
    func testToolUseBlock() async throws {
        let (session, stub) = makeSession()
        let store = try keychainWithTestKey()
        let messages = [
            LLMMessage(
                role: .assistant,
                blocks: [.toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/x\"}")]
            )
        ]

        try await ProviderKeychain.withBackendForTesting(store) {
            let connector = AnthropicConnector(session: session)
            _ = try await connector.send(
                messages: messages,
                options: LLMCallOptions(model: "claude-sonnet-4-5")
            )
        }

        let body = try decodedBody(from: stub)
        let content = (body?["messages"] as? [[String: Any]])?.first?["content"]
            as? [[String: Any]]
        let toolUse = content?.first
        #expect(toolUse?["type"] as? String == "tool_use")
        #expect(toolUse?["id"] as? String == "t1")
        #expect(toolUse?["name"] as? String == "ReadFile")
        // Anthropic native `input` field MUST be a JSON object (= dict),
        // not a base64 Data blob. The pre-refactor code crashed
        // NSJSONSerialization with "Invalid type in JSON write
        // (Foundation.__NSSwiftData)" when it tried to serialize a raw
        // Data value. This assertion guards the regression.
        let input = toolUse?["input"] as? [String: Any]
        #expect(input?["path"] as? String == "/tmp/x")
    }

    @Test("Tool result block encoded with type=tool_result + tool_use_id + content")
    func testToolResultBlock() async throws {
        let (session, stub) = makeSession()
        let store = try keychainWithTestKey()
        let messages = [
            LLMMessage.toolResult(toolUseID: "t1", output: "file content here")
        ]

        try await ProviderKeychain.withBackendForTesting(store) {
            let connector = AnthropicConnector(session: session)
            _ = try await connector.send(
                messages: messages,
                options: LLMCallOptions(model: "claude-sonnet-4-5")
            )
        }

        let body = try decodedBody(from: stub)
        let content = (body?["messages"] as? [[String: Any]])?.first?["content"]
            as? [[String: Any]]
        let toolResult = content?.first
        #expect(toolResult?["type"] as? String == "tool_result")
        #expect(toolResult?["tool_use_id"] as? String == "t1")
        #expect(toolResult?["content"] as? String == "file content here")
    }

    @Test("Missing API key throws LLMConnectorError.missingAPIKey")
    func testMissingAPIKey() async {
        let store = InMemoryKeychainStore()

        await ProviderKeychain.withBackendForTesting(store) {
            let connector = AnthropicConnector(session: .shared)
            await #expect(throws: LLMConnectorError.self) {
                _ = try await connector.send(
                    messages: [LLMMessage.user("test")],
                    options: LLMCallOptions(model: "claude-sonnet-4-5")
                )
            }
        }
    }

    // MARK: - Helpers

    /// Drain the captured POST request body. URLSession migrates
    /// `httpBody` to `httpBodyStream` for transport (= `httpBody` may be
    /// nil even when bytes are present). Reading from `httpBodyStream`
    /// recovers the original bytes.
    private func drainStream(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var buf = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&chunk, maxLength: chunk.count)
            if n <= 0 { break }
            buf.append(chunk, count: n)
        }
        return buf
    }

    /// The bytes this test's own stub captured on the wire.
    private func capturedRequestBody(from stub: URLProtocolStub) throws -> Data {
        let captured = try #require(stub.lastRequest, "connector made no request")
        if let direct = captured.httpBody { return direct }
        return drainStream(captured.httpBodyStream)
    }

    private func decodedBody(from stub: URLProtocolStub) throws -> [String: Any]? {
        let data = try capturedRequestBody(from: stub)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
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
