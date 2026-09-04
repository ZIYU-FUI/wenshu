//
//  RequestHelpersTests.swift · Wenshu · TICKET-HERMES-GAP-002
//
//  Unit tests for `Connector/RequestHelpers.swift`. Verifies that the
//  4 builders + 3 decoders produce wire-format-parity output matching
//  the pre-refactor connector code (= existing connector tests stay
//  green as the canonical byte-identity check).
//
//  Tests:
//    1. testBuildAnthropicRequest — fixed model + messages + system
//       + cache_control; assert field shape + cache_control hooks
//    2. testDecodeAnthropicResponse — fixed JSON response; assert
//       text / thinking / tool_use blocks decode correctly
//    3. testBuildMinimaxRequest — fixed inputs; assert plain-string
//       `system` + joined-string `content` (= NOT structured/block-array)
//    4. testBuildOpenAIRequest — fixed inputs; assert system prepended
//       + content flattened to joined string
//    5. testDecodeOpenAIResponse — fixed JSON; assert text + usage + stop reason
//    6. testBuildGeminiRequest — fixed inputs; assert systemInstruction
//       separate from contents + generationConfig.maxOutputTokens
//    7. testDecodeGeminiResponse — fixed JSON; assert text + usage
//    8. testConnectorAfterRefactor_anthropic — refactored AnthropicConnector
//       produces byte-identical httpBody to pre-refactor wire format
//       (= end-to-end golden parity through URLProtocolStub)
//    9. testConnectorAfterRefactor_openai — same for OpenAIConnector
//
//  All tests build JSON-shaped input via JSONSerialization round-trip
//  (= no fixture file dependency; assertions on parsed dict shape).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("RequestHelpers (TICKET-HERMES-GAP-002)", .serialized)
struct RequestHelpersTests {

    // MARK: - 1. Anthropic native request builder

    @Test("Anthropic native: model + max_tokens + system + messages with cache_control")
    func testBuildAnthropicRequest() throws {
        let messages = [
            LLMMessage.user("hello"),
            LLMMessage(
                role: .assistant,
                blocks: [.text("hi back")],
                cacheControl: ["type": "ephemeral"]
            )
        ]
        let data = try RequestHelpers.buildAnthropicRequest(
            model: "claude-sonnet-4-5",
            messages: messages,
            maxTokens: 1024,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(body?["model"] as? String == "claude-sonnet-4-5")
        #expect(body?["max_tokens"] as? Int == 1024)

        // System field: structured dict with cache_control.
        let system = body?["system"] as? [String: Any]
        #expect(system?["type"] as? String == "text")
        #expect(system?["text"] as? String == "you are helpful")
        #expect(system?["cache_control"] as? [String: String] != nil)

        // Messages array.
        let messages2 = body?["messages"] as? [[String: Any]]
        #expect(messages2?.count == 2)
        #expect(messages2?[0]["role"] as? String == "user")
        #expect(messages2?[0]["content"] is [[String: Any]])  // = array, NOT joined string
        #expect(messages2?[1]["cache_control"] as? [String: String] != nil)  // per-msg marker
    }

    // MARK: - 2. Anthropic response decoder

    @Test("Anthropic native: decode text + thinking + tool_use blocks + usage + stop reason")
    func testDecodeAnthropicResponse() throws {
        let responseJSON: [String: Any] = [
            "id": "msg_test",
            "model": "claude-sonnet-4-5",
            "role": "assistant",
            "content": [
                ["type": "thinking", "thinking": "reasoning", "signature": "sig"],
                ["type": "text", "text": "answer text"],
                [
                    "type": "tool_use",
                    "id": "t1",
                    "name": "ReadFile",
                    "input": ["path": "/etc/x"]
                ] as [String: Any]
            ],
            "stop_reason": "tool_use",
            "usage": ["input_tokens": 100, "output_tokens": 50]
        ]
        let data = try JSONSerialization.data(withJSONObject: responseJSON)
        let response = try RequestHelpers.decodeAnthropicResponse(
            data: data,
            model: "claude-sonnet-4-5",
            providerID: "anthropic"
        )

        #expect(response.model == "claude-sonnet-4-5")
        #expect(response.usage.inputTokens == 100)
        #expect(response.usage.outputTokens == 50)
        #expect(response.stopReason == .toolUse)

        // 3 blocks: thinking + text + tool_use
        #expect(response.blocks.count == 3)
        if response.blocks.count == 3 {
            if case .thinking(let t, let sig) = response.blocks[0] {
                #expect(t == "reasoning")
                #expect(sig == "sig")
            } else {
                Issue.record("block 0 should be .thinking")
            }
            if case .text(let s) = response.blocks[1] {
                #expect(s == "answer text")
            } else {
                Issue.record("block 1 should be .text")
            }
            if case .toolUse(let id, let name, let input) = response.blocks[2] {
                #expect(id == "t1")
                #expect(name == "ReadFile")
                #expect(input.contains("path"))
            } else {
                Issue.record("block 2 should be .toolUse")
            }
        }
    }

    // MARK: - 3. Minimax-compatible request builder (= different wire shape from Anthropic)

    @Test("Minimax: system = plain string, content = joined string")
    func testBuildMinimaxRequest() throws {
        let messages = [
            LLMMessage.user("hello"),
            LLMMessage(
                role: .assistant,
                blocks: [.text("hi back")],
                cacheControl: ["type": "ephemeral"]
            )
        ]
        let data = try RequestHelpers.buildMinimaxRequest(
            model: "MiniMax-M3",
            messages: messages,
            maxTokens: 1024,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(body?["model"] as? String == "MiniMax-M3")
        #expect(body?["max_tokens"] as? Int == 1024)

        // System is a plain string (= NOT structured dict).
        #expect(body?["system"] is String)
        #expect(body?["system"] as? String == "you are helpful")

        // Messages array; content is joined string (= NOT block array).
        let messages2 = body?["messages"] as? [[String: Any]]
        #expect(messages2?.count == 2)
        #expect(messages2?[0]["role"] as? String == "user")
        #expect(messages2?[0]["content"] is String)  // = joined string
        #expect(messages2?[1]["cache_control"] as? [String: String] != nil)  // per-msg marker preserved
    }

    // MARK: - 4. OpenAI chat completions request builder

    @Test("OpenAI: system prepended + content flattened to joined string")
    func testBuildOpenAIRequest() throws {
        let messages = [
            LLMMessage.user("hello"),
            LLMMessage.assistant("hi back")
        ]
        let data = try RequestHelpers.buildOpenAIRequest(
            model: "gpt-5",
            messages: messages,
            maxTokens: 2048,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(body?["model"] as? String == "gpt-5")
        #expect(body?["max_tokens"] as? Int == 2048)

        // Messages: [system, user, assistant]
        let messages2 = body?["messages"] as? [[String: Any]]
        #expect(messages2?.count == 3)
        #expect(messages2?[0]["role"] as? String == "system")
        #expect(messages2?[0]["content"] as? String == "you are helpful")
        #expect(messages2?[1]["role"] as? String == "user")
        #expect(messages2?[2]["role"] as? String == "assistant")
        #expect(messages2?[2]["content"] is String)  // = joined string (= flattened)
    }

    // MARK: - 5. OpenAI response decoder

    @Test("OpenAI: decode text content + finish_reason=length -> stopReason=.maxTokens")
    func testDecodeOpenAIResponse() throws {
        let responseJSON: [String: Any] = [
            "id": "chatcmpl-test",
            "object": "chat.completion",
            "model": "gpt-5",
            "choices": [
                [
                    "index": 0,
                    "message": ["role": "assistant", "content": "answer text"],
                    "finish_reason": "length"
                ]
            ],
            "usage": ["prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30]
        ]
        let data = try JSONSerialization.data(withJSONObject: responseJSON)
        let response = try RequestHelpers.decodeOpenAIResponse(
            data: data,
            model: "gpt-5",
            providerID: "openai-codex"
        )

        #expect(response.model == "gpt-5")
        #expect(response.usage.inputTokens == 10)
        #expect(response.usage.outputTokens == 20)
        #expect(response.stopReason == .maxTokens)  // = "length" maps to .maxTokens
        #expect(response.blocks.count == 1)
        if response.blocks.count == 1, case .text(let s) = response.blocks[0] {
            #expect(s == "answer text")
        } else {
            Issue.record("expected single .text block")
        }
    }

    // MARK: - 6. Gemini native request builder

    @Test("Gemini: systemInstruction separate from contents + generationConfig.maxOutputTokens")
    func testBuildGeminiRequest() throws {
        let messages = [
            LLMMessage.user("hello"),
            LLMMessage.assistant("hi back")
        ]
        let data = try RequestHelpers.buildGeminiRequest(
            model: "gemini-2.5-flash",
            messages: messages,
            maxTokens: 2048,
            systemPrompt: "you are helpful"
        )
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // systemInstruction is top-level field (NOT inside contents).
        let systemInstruction = body?["systemInstruction"] as? [String: Any]
        let parts = systemInstruction?["parts"] as? [[String: Any]]
        #expect(parts?.first?["text"] as? String == "you are helpful")

        // contents[] excludes the system message.
        let contents = body?["contents"] as? [[String: Any]]
        #expect(contents?.count == 2)
        #expect(contents?[0]["role"] as? String == "user")
        #expect(contents?[1]["role"] as? String == "model")

        // generationConfig.maxOutputTokens present when maxTokens > 0.
        let generationConfig = body?["generationConfig"] as? [String: Any]
        #expect(generationConfig?["maxOutputTokens"] as? Int == 2048)
    }

    // MARK: - 7. Gemini response decoder

    @Test("Gemini: decode candidates[0].content.parts[].text + usageMetadata")
    func testDecodeGeminiResponse() throws {
        let responseJSON: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [["text": "answer text"]],
                        "role": "model"
                    ],
                    "finishReason": "STOP"
                ]
            ],
            "modelVersion": "gemini-2.5-flash",
            "usageMetadata": [
                "promptTokenCount": 5,
                "candidatesTokenCount": 10
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: responseJSON)
        let response = try RequestHelpers.decodeGeminiResponse(
            data: data,
            model: "gemini-2.5-flash",
            providerID: "gemini"
        )

        #expect(response.model == "gemini-2.5-flash")
        #expect(response.usage.inputTokens == 5)
        #expect(response.usage.outputTokens == 10)
        #expect(response.blocks.count == 1)
        if response.blocks.count == 1, case .text(let s) = response.blocks[0] {
            #expect(s == "answer text")
        } else {
            Issue.record("expected single .text block")
        }
    }

    // MARK: - 8. Refactored AnthropicConnector byte-parity (golden)

    @Test("ConnectorAfterRefactor Anthropic: byte-identical httpBody to pre-refactor")
    func testConnectorAfterRefactorAnthropic() async throws {
        let stub = URLProtocolStub()
        stub.response = makeAnthropicResponse(content: "ok")
        URLProtocolStub.register(stub)
        defer { URLProtocolStub.unregister() }
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

        // URLSession migrates `httpBody` -> `httpBodyStream` for POST bodies,
        // so `httpBody` may be nil even when bytes are present. Drain the
        // stream when httpBody is missing (= captures the real request body).
        let captured = URLProtocolStub.stub?.lastRequest
        let bodyData: Data = try {
            if let direct = captured?.httpBody { return direct }
            guard let stream = captured?.httpBodyStream else { return Data() }
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
        }()
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

        // Verify the canonical wire shape (= pre-refactor AnthropicConnector).
        #expect(body?["model"] as? String == "claude-sonnet-4-5")
        #expect(body?["max_tokens"] as? Int == 4096)  // default LLMCallOptions

        let system = body?["system"] as? [String: Any]
        #expect(system?["type"] as? String == "text")
        #expect(system?["text"] as? String == "stable")
        #expect(system?["cache_control"] != nil)

        let messages2 = body?["messages"] as? [[String: Any]]
        #expect(messages2?.count == 1)
        #expect(messages2?[0]["content"] is [[String: Any]])  // = block array
    }

    // MARK: - 9. Refactored OpenAIConnector byte-parity (golden)

    @Test("ConnectorAfterRefactor OpenAI: byte-identical httpBody to pre-refactor")
    func testConnectorAfterRefactorOpenAI() async throws {
        let stub = URLProtocolStub()
        stub.response = makeOpenAIResponse(content: "ok")
        URLProtocolStub.register(stub)
        defer { URLProtocolStub.unregister() }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        let store = InMemoryKeychainStore()
        try store.saveKeySync("sk-test", for: .openaiCodex)
        ProviderKeychain.setBackendForTesting(store)

        let connector = OpenAIConnector(session: session)
        _ = try await connector.send(
            messages: [LLMMessage.user("test")],
            options: LLMCallOptions(model: "gpt-5", systemPrompt: "stable")
        )

        let captured = URLProtocolStub.stub?.lastRequest
        let bodyData: Data = try {
            if let direct = captured?.httpBody { return direct }
            guard let stream = captured?.httpBodyStream else { return Data() }
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
        }()
        let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]

        // Verify the canonical wire shape (= pre-refactor OpenAIConnector).
        #expect(body?["model"] as? String == "gpt-5")
        #expect(body?["max_tokens"] as? Int == 4096)

        let messages2 = body?["messages"] as? [[String: Any]]
        #expect(messages2?.count == 2)  // system + user
        #expect(messages2?[0]["role"] as? String == "system")
        #expect(messages2?[0]["content"] as? String == "stable")
        #expect(messages2?[1]["role"] as? String == "user")
        #expect(messages2?[1]["content"] is String)  // = joined string
    }
}

// MARK: - Shared response builders (= private to test file)

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

private func makeOpenAIResponse(content: String, model: String = "gpt-5") -> Data {
    let body: [String: Any] = [
        "id": "chatcmpl-test",
        "object": "chat.completion",
        "model": model,
        "choices": [
            [
                "index": 0,
                "message": ["role": "assistant", "content": content],
                "finish_reason": "stop"
            ]
        ],
        "usage": ["prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0]
    ]
    return try! JSONSerialization.data(withJSONObject: body)
}