//
//  AnthropicAdapterRedactedTests.swift · Wenshu · HERMES-PARTIAL-006 (2026-09-04)
//
//  Round-trip tests for the AnthropicAdapter extensions (= hermes
//  anthropic_adapter.py = 2,789 LOC):
//    1. testRedactedThinkingPropagate    — redacted_thinking data round-trip
//    2. testImageURLConvert             — OpenAI-style image URL → Anthropic
//    3. testImageDataURLConvert         — data: URL → base64 source
//    4. testDocumentConvert             — document block for PDFs
//    5. testThinkingSignaturePropagate  — signature preserved across turns
//    6. testIsClaudeModel               — model detection
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicAdapterRedacted (HERMES-PARTIAL-006)")
struct AnthropicAdapterRedactedTests {

    // MARK: - Test 1: redacted_thinking propagation

    @Test("redacted_thinking data propagates as a signature-able block")
    func testRedactedThinkingPropagate() {
        let (text, signature) = AnthropicAdapter.propagateRedactedThinking(data: "abc123")
        #expect(text.isEmpty)
        #expect(signature.contains("abc123"))
        // Round-trip into the wire format.
        let block = AnthropicAdapter.ContentBlock.redacted_thinking(data: "abc123")
        let json = block.asJSON
        #expect(json["type"] as? String == "redacted_thinking")
        #expect(json["data"] as? String == "abc123")
    }

    // MARK: - Test 2: OpenAI-style image URL convert

    @Test("imageSourceFromOpenAIURL converts https URL into url source")
    func testImageURLConvert() {
        let src = AnthropicAdapter.imageSourceFromOpenAIURL("https://example.com/cat.jpg")
        #expect(src.kind == .url)
        #expect(src.mediaType == "image/jpeg")
        #expect(src.data == "https://example.com/cat.jpg")
        let json = src.asJSON
        #expect(json["type"] as? String == "url")
    }

    // MARK: - Test 3: data: URL → base64 source

    @Test("imageSourceFromOpenAIURL converts data: URL into base64 source")
    func testImageDataURLConvert() {
        let url = "data:image/png;base64,iVBORw0KGgo="
        let src = AnthropicAdapter.imageSourceFromOpenAIURL(url)
        #expect(src.kind == .base64)
        #expect(src.mediaType == "image/png")
        #expect(src.data == "iVBORw0KGgo=")
        let json = src.asJSON
        #expect(json["type"] as? String == "base64")
    }

    // MARK: - Test 4: Document block convert

    @Test("convertOpenAIMessagesToAnthropic handles document blocks")
    func testDocumentConvert() {
        let messages: [[String: Any]] = [[
            "role": "user",
            "content": [[
                "type": "document",
                "document": [
                    "url": "https://example.com/chapter1.pdf",
                    "media_type": "application/pdf"
                ]
            ]]
        ]]
        let out = AnthropicAdapter.convertOpenAIMessagesToAnthropic(messages)
        #expect(out.count == 1)
        let content = out[0]["content"] as? [[String: Any]]
        #expect(content?.count == 1)
        #expect(content?[0]["type"] as? String == "document")
        let source = content?[0]["source"] as? [String: Any]
        #expect(source?["type"] as? String == "url")
        #expect(source?["media_type"] as? String == "application/pdf")
    }

    // MARK: - Test 5: Thinking signature propagation

    @Test("thinking block preserves signature across turns")
    func testThinkingSignaturePropagate() {
        let messages: [[String: Any]] = [[
            "role": "assistant",
            "content": [[
                "type": "thinking",
                "thinking": "reasoning...",
                "signature": "abc-sig"
            ]]
        ]]
        let out = AnthropicAdapter.convertOpenAIMessagesToAnthropic(messages)
        let content = out[0]["content"] as? [[String: Any]]
        #expect(content?[0]["type"] as? String == "thinking")
        #expect(content?[0]["thinking"] as? String == "reasoning...")
        #expect(content?[0]["signature"] as? String == "abc-sig")
    }

    // MARK: - Test 6: Claude model detection + max-output

    @Test("isClaudeModel + maxOutputTokens handle the model family table")
    func testIsClaudeModel() {
        #expect(AnthropicAdapter.isClaudeModel("claude-3-5-sonnet-20241022") == true)
        #expect(AnthropicAdapter.isClaudeModel("claude-opus-4-20250514") == true)
        #expect(AnthropicAdapter.isClaudeModel("gpt-4") == false)
        #expect(AnthropicAdapter.isClaudeModel(nil) == false)
        // Max output tokens per family.
        #expect(AnthropicAdapter.maxOutputTokens(for: "claude-opus-4-20250514") == 32_000)
        #expect(AnthropicAdapter.maxOutputTokens(for: "claude-sonnet-4-20250514") == 64_000)
        #expect(AnthropicAdapter.maxOutputTokens(for: "claude-3-5-haiku-20241022") == 8_192)
        // supportsAdaptiveThinking
        #expect(AnthropicAdapter.supportsAdaptiveThinking("claude-opus-4-20250514") == true)
        #expect(AnthropicAdapter.supportsAdaptiveThinking("claude-3-5-sonnet-20241022") == false)
    }
}