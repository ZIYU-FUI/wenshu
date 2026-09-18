//
//  OpenAIStreamingChunkToLLMBlockTests.swift · Wenshu · T10-OPENAI-STREAMING-WIRE (2026-09-18)
//
//  Verifies OpenAIChunkToLLMBlockConverter parsing + conversion rules:
//    - "[DONE]" -> nil (= stream end)
//    - "" -> nil (= empty payload)
//    - malformed JSON -> non-nil OpenAISSEEvent with parsed=nil
//    - delta.content -> .text block
//    - delta.reasoning -> .thinking block
//    - finish_reason != null -> no blocks (= stream-end marker convention)
//    - tool_calls delta -> no blocks (= T11 scope)
//    - full chunk stream -> only content blocks emerge
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OpenAIStreamingChunkToLLMBlock (T10-OPENAI-STREAMING-WIRE)")
struct OpenAIStreamingChunkToLLMBlockTests {

    private func makeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    /// T10 contract: "[DONE]" returns nil (= stream end marker).
    @Test func done_marker_returns_nil() {
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: "[DONE]")
        #expect(event == nil)
    }

    /// T10 contract: empty payload returns nil.
    @Test func empty_payload_returns_nil() {
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: "")
        #expect(event == nil)
        let event2 = OpenAIChunkToLLMBlockConverter.parse(rawData: "   \n\n")
        #expect(event2 == nil)
    }

    /// T10 contract: malformed JSON returns OpenAISSEEvent with parsed=nil.
    /// (= consumer can still see the raw data for debugging, but
    /// convert(...) returns [] for parsed=nil events.)
    @Test func malformed_json_returns_event_with_nil_parsed() {
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: "{not json")
        #expect(event != nil)
        #expect(event?.parsed == nil)
        #expect(OpenAIChunkToLLMBlockConverter.convert(event!) == [])
    }

    /// T10 contract: delta.content -> .text.
    @Test func content_delta_becomes_text_block() {
        let payload: [String: Any] = [
            "id": "chatcmpl-1",
            "choices": [
                ["index": 0, "delta": ["content": "Hello"], "finish_reason": NSNull()]
            ]
        ]
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: makeJSON(payload))!
        let blocks = OpenAIChunkToLLMBlockConverter.convert(event)
        #expect(blocks.count == 1)
        if case .text(let s) = blocks[0] {
            #expect(s == "Hello")
        } else {
            Issue.record("expected .text, got \(blocks[0])")
        }
    }

    /// T10 contract: delta.reasoning -> .thinking.
    @Test func reasoning_delta_becomes_thinking_block() {
        let payload: [String: Any] = [
            "id": "chatcmpl-2",
            "choices": [
                ["index": 0, "delta": ["reasoning": "Let me think..."], "finish_reason": NSNull()]
            ]
        ]
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: makeJSON(payload))!
        let blocks = OpenAIChunkToLLMBlockConverter.convert(event)
        #expect(blocks.count == 1)
        if case .thinking(let text, let signature) = blocks[0] {
            #expect(text == "Let me think...")
            #expect(signature == nil, "OpenAI reasoning has no signature counterpart")
        } else {
            Issue.record("expected .thinking, got \(blocks[0])")
        }
    }

    /// T10 contract: both content + reasoning in same delta -> both blocks.
    @Test func content_and_reasoning_both_emit() {
        let payload: [String: Any] = [
            "choices": [
                [
                    "delta": [
                        "content": "answer",
                        "reasoning": "thinking"
                    ],
                    "finish_reason": NSNull()
                ]
            ]
        ]
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: makeJSON(payload))!
        let blocks = OpenAIChunkToLLMBlockConverter.convert(event)
        #expect(blocks.count == 2, "expected 2 blocks, got \(blocks.count)")
    }

    /// T10 contract: finish_reason != null -> no blocks (= stream-end
    /// marker convention; = consumer should treat this as end-of-stream).
    @Test func finish_reason_present_emits_no_blocks() {
        let payload: [String: Any] = [
            "choices": [
                [
                    "delta": ["content": "tail"],
                    "finish_reason": "stop"
                ]
            ]
        ]
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: makeJSON(payload))!
        let blocks = OpenAIChunkToLLMBlockConverter.convert(event)
        #expect(blocks.isEmpty, "expected no blocks for finish_reason=stop, got \(blocks)")
    }

    /// T10 contract: tool_calls delta -> no blocks (= T11 scope;
    /// = skipped for now to avoid emitting incomplete tool_use).
    @Test func tool_calls_delta_emits_no_blocks() {
        let payload: [String: Any] = [
            "choices": [
                [
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "tool-1", "function": ["name": "read_file", "arguments": "{}"]]
                        ]
                    ]
                ]
            ]
        ]
        let event = OpenAIChunkToLLMBlockConverter.parse(rawData: makeJSON(payload))!
        let blocks = OpenAIChunkToLLMBlockConverter.convert(event)
        #expect(blocks.isEmpty, "tool_calls handling deferred to T11")
    }

    /// T10 contract: full chunk stream produces only content blocks.
    @Test func full_chunk_stream_produces_only_content_blocks() async {
        let payloads: [String] = [
            makeJSON([
                "choices": [["delta": ["content": "Hello "], "finish_reason": NSNull()]]
            ]),
            makeJSON([
                "choices": [["delta": ["content": "world."], "finish_reason": NSNull()]]
            ]),
            makeJSON([
                "choices": [["delta": ["reasoning": "thinking"], "finish_reason": NSNull()]]
            ]),
            makeJSON([
                "choices": [["delta": ["content": " answer"], "finish_reason": "stop"]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for payload in payloads {
                continuation.yield(payload)
            }
            continuation.finish()
        }
        let outStream = OpenAIChunkToLLMBlockConverter.convert(stream: sourceStream)
        var collected: [LLMBlock] = []
        for await block in outStream {
            collected.append(block)
        }
        #expect(collected.count == 3, "expected 3 content blocks, got \(collected.count)")
        if case .text(let s1) = collected[0] {
            #expect(s1 == "Hello ")
        } else {
            Issue.record("expected first .text, got \(collected[0])")
        }
        if case .text(let s2) = collected[1] {
            #expect(s2 == "world.")
        } else {
            Issue.record("expected second .text, got \(collected[1])")
        }
        if case .thinking(let t, _) = collected[2] {
            #expect(t == "thinking")
        } else {
            Issue.record("expected third .thinking, got \(collected[2])")
        }
    }

    /// T10 contract: errorStream yields synthetic error block.
    @Test func error_stream_emits_error_block() async {
        let stream = OpenAIChunkToLLMBlockConverter.errorStream(
            "missing API key for openai-compatible provider",
            provider: "deepseek"
        )
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 1)
        if case .text(let s) = collected[0] {
            #expect(s.contains("[stream error]"))
            #expect(s.contains("missing API key"))
            #expect(s.contains("deepseek"))
        } else {
            Issue.record("expected .text error block, got \(collected[0])")
        }
    }
}