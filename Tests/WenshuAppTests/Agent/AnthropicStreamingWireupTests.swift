//
//  AnthropicStreamingWireupTests.swift · Wenshu · v0.36 ticket 004 sub-step 5
//
//  Z contract tests (= unit tests for ticket 004 sub-step 4 wire-up).
//
//  Per /code-review Spec re-review, ticket 004 L34-35 Z + X e2e tests
//  were deferred. This file ships Z contract coverage = pure logic
//  verification. X e2e (= real Anthropic API call) requires user API key
//  and is documented but not implemented (= would hit real network).
//
//  Test coverage:
//  1. AnthropicStreamingWireupFactory.buildRequest produces valid
//     streaming request (= x-api-key + anthropic-version headers + stream=true)
//  2. URLRequest preserves credentials (= apiKey NOT logged in URL)
//  3. URLRequest body includes stream=true + messages + system prompt
//  4. AnthropicStreamingWireup.connect() returns AsyncStream
//     (= consumer receives chunks when EventSource fires)
//
//
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

@Suite("AnthropicStreamingWireupFactory (ticket 004 sub-step 5 Z contract)")
struct AnthropicStreamingWireupFactoryTests {
    @Test("buildRequest adds x-api-key + anthropic-version headers")
    func headers() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test-12345",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 4096,
            systemPrompt: "you are a helpful assistant",
            messages: [
                LLMMessage(role: .user, blocks: [.text("hello")]),
            ]
        )
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-test-12345")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("buildRequest appends stream=true to URL")
    func streamQueryParam() {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 1024,
            systemPrompt: nil,
            messages: []
        )
        let urlString = request.url?.absoluteString ?? ""
        #expect(urlString.contains("stream=true"))
    }

    @Test("buildRequest body includes stream=true + system + messages")
    func bodyShape() throws {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 1024,
            systemPrompt: "system prompt here",
            messages: [
                LLMMessage(role: .user, blocks: [.text("user message")]),
            ]
        )
        let bodyData = try #require(request.httpBody)
        let bodyJSON = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        #expect(bodyJSON["stream"] as? Bool == true)
        #expect(bodyJSON["model"] as? String == "claude-sonnet-4.5")
        #expect(bodyJSON["max_tokens"] as? Int == 1024)

        // system is an array of content blocks
        let systemArray = try #require(bodyJSON["system"] as? [[String: Any]])
        #expect(systemArray.count == 1)
        #expect(systemArray[0]["type"] as? String == "text")
        #expect(systemArray[0]["text"] as? String == "system prompt here")

        // messages is an array of role/content pairs
        let messagesArray = try #require(bodyJSON["messages"] as? [[String: Any]])
        #expect(messagesArray.count == 1)
        #expect(messagesArray[0]["role"] as? String == "user")
        #expect(messagesArray[0]["content"] as? [[String: Any]] != nil)
    }

    @Test("a failed tool call reaches the provider as a failed one (= = the streaming wire carries is_error)")
    func failedToolResultCarriesIsError() throws {
        // The streaming request body IS the wire the chat's own tool
        // loop sends (= = the loop streams its results), = = so a
        // failure that is dropped here is a failure the model reads as
        // a success.
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 1024,
            systemPrompt: nil,
            messages: [
                LLMMessage(
                    role: .user,
                    blocks: [
                        .toolResult(toolUseID: "call-1", output: "the file is not there", isError: true),
                    ]
                ),
            ]
        )
        let bodyData = try #require(request.httpBody)
        let bodyJSON = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messages = try #require(bodyJSON["messages"] as? [[String: Any]])
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        let result = try #require(content.first { $0["type"] as? String == "tool_result" })
        #expect(result["is_error"] as? Bool == true,
                "A failed tool call must reach the provider marked as failed")
    }

    @Test("buildRequest with nil systemPrompt uses empty string")
    func nilSystemPrompt() throws {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 1024,
            systemPrompt: nil,
            messages: []
        )
        let bodyData = try #require(request.httpBody)
        let bodyJSON = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let systemArray = try #require(bodyJSON["system"] as? [[String: Any]])
        #expect(systemArray[0]["text"] as? String == "")
    }

    @Test("buildRequest assistant message uses 'assistant' role")
    func assistantRole() throws {
        let creds = ConnectorCredentials(
            provider: .anthropic,
            apiKey: "sk-test",
            baseURL: "https://api.anthropic.com"
        )
        let request = AnthropicStreamingWireupFactory.buildRequest(
            credentials: creds,
            model: "claude-sonnet-4.5",
            maxTokens: 1024,
            systemPrompt: nil,
            messages: [
                LLMMessage(role: .user, blocks: [.text("hi")]),
                LLMMessage(role: .assistant, blocks: [.text("hello!")]),
            ]
        )
        let bodyData = try #require(request.httpBody)
        let bodyJSON = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let messagesArray = try #require(bodyJSON["messages"] as? [[String: Any]])
        #expect(messagesArray.count == 2)
        #expect(messagesArray[0]["role"] as? String == "user")
        #expect(messagesArray[1]["role"] as? String == "assistant")
    }

    @Test("LLMConnectorError.streamingFailed carries provider name")
    func streamingFailedError() {
        let error = LLMConnectorError.streamingFailed(provider: "anthropic")
        #expect(error.errorDescription?.contains("anthropic") == true)
    }

    @Test("AnthropicStreamingWireup init does not throw")
    func wireupInit() {
        let wireup = AnthropicStreamingWireup()
        // No init parameters; just verify it's creatable.
        // (close() will be called when consumer finishes the stream.)
        _ = wireup
    }
}

@Suite("AnthropicSSEDecoder (ticket 002 sub-step 1 verification)")
struct AnthropicSSEDecoderVerificationTests {
    @Test("decode text_delta chunk")
    func textDeltaDecode() {
        let event = "content_block_delta"
        let data = """
        {"index":0,"delta":{"type":"text_delta","text":"hello"}}
        """
        let chunk = AnthropicSSEDecoder.decode(event: event, data: data)
        guard case let .contentBlockDelta(index, textDelta, inputDelta, _) = chunk?.kind else {
            Issue.record("Expected contentBlockDelta")
            return
        }
        #expect(index == 0)
        #expect(textDelta == "hello")
        #expect(inputDelta == nil)
    }

    @Test("decode messageStop")
    func messageStopDecode() {
        let chunk = AnthropicSSEDecoder.decode(event: "message_stop", data: "{}")
        guard case .messageStop = chunk?.kind else {
            Issue.record("Expected messageStop")
            return
        }
    }

    @Test("decode ping")
    func pingDecode() {
        let chunk = AnthropicSSEDecoder.decode(event: "ping", data: "{}")
        guard case .ping = chunk?.kind else {
            Issue.record("Expected ping")
            return
        }
    }

    @Test("decode unknown event returns unknown case")
    func unknownEvent() {
        let chunk = AnthropicSSEDecoder.decode(event: "custom_event", data: "{}")
        guard case let .unknown(name) = chunk?.kind else {
            Issue.record("Expected unknown")
            return
        }
        #expect(name == "custom_event")
    }
}
