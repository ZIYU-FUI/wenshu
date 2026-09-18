//
//  OpenAIToolCallsAggregationTests.swift · Wenshu · T12-OPENAI-TOOL-CALLS-AGG (2026-09-18)
//
//  Verifies the stateful converter (= T12 addition): accumulates
//  tool_calls across multiple SSE deltas into single .toolUse
//  LLMBlocks at stream end (= [DONE] marker).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("OpenAIToolCallsAggregation (T12)")
struct OpenAIToolCallsAggregationTests {

    private func makeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    /// T12 contract: complete tool_call across 3 chunks + [DONE]
    /// emits ONE .toolUse with assembled JSON arguments at stream end.
    @Test func tool_call_assembled_at_done() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "tool-1", "type": "function",
                             "function": ["name": "read_file", "arguments": ""]]
                        ]
                    ]
                ]]
            ]),
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0,
                             "function": ["arguments": "{\"path\":"]]
                        ]
                    ]
                ]]
            ]),
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0,
                             "function": ["arguments": "\"foo.txt\"}"]]
                        ]
                    ]
                ]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 1, "expected 1 .toolUse, got \(collected.count)")
        if case .toolUse(let id, let name, let input) = collected[0] {
            #expect(id == "tool-1")
            #expect(name == "read_file")
            #expect(input == "{\"path\":\"foo.txt\"}")
        } else {
            Issue.record("expected .toolUse, got \(collected[0])")
        }
    }

    /// T12 contract: parallel tool_calls (= different `index`) are
    /// tracked independently.
    @Test func parallel_tool_calls_tracked_independently() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "tool-a", "type": "function",
                             "function": ["name": "callback_a", "arguments": ""]],
                            ["index": 1, "id": "tool-b", "type": "function",
                             "function": ["name": "callback_b", "arguments": ""]]
                        ]
                    ]
                ]]
            ]),
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "function": ["arguments": "{\"a\":1}"]],
                            ["index": 1, "function": ["arguments": "{\"b\":2}"]]
                        ]
                    ]
                ]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 2, "expected 2 .toolUse, got \(collected.count)")
        if case .toolUse(let id0, let name0, let input0) = collected[0] {
            #expect(id0 == "tool-a")
            #expect(name0 == "callback_a")
            #expect(input0 == "{\"a\":1}")
        } else {
            Issue.record("expected first .toolUse = tool-a")
        }
        if case .toolUse(let id1, let name1, let input1) = collected[1] {
            #expect(id1 == "tool-b")
            #expect(name1 == "callback_b")
            #expect(input1 == "{\"b\":2}")
        } else {
            Issue.record("expected second .toolUse = tool-b")
        }
    }

    /// T12 contract: text and tool_calls in same stream emit text
    /// immediately, tool_use at end.
    @Test func text_emits_immediately_tool_use_at_end() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": ["content": "Calling tool..."]
                ]]
            ]),
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "t1", "type": "function",
                             "function": ["name": "echo", "arguments": "{}"]]
                        ]
                    ]
                ]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 2, "expected 2 blocks (1 .text + 1 .toolUse), got \(collected.count)")
        if case .text(let s) = collected[0] {
            #expect(s == "Calling tool...")
        } else {
            Issue.record("expected first .text, got \(collected[0])")
        }
        if case .toolUse(_, let name, _) = collected[1] {
            #expect(name == "echo")
        } else {
            Issue.record("expected second .toolUse")
        }
    }

    /// T12 contract: stream ending without [DONE] (= connection drop)
    /// still flushes pending tool_use blocks.
    @Test func stream_drop_flushes_pending_tool_use() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "t1", "type": "function",
                             "function": ["name": "echo", "arguments": "{\"x\":1}"]]
                        ]
                    ]
                ]]
            ])
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            // No [DONE] = stream truncated.
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 1, "expected flush to emit 1 .toolUse, got \(collected.count)")
        if case .toolUse(_, let name, let input) = collected[0] {
            #expect(name == "echo")
            #expect(input == "{\"x\":1}")
        } else {
            Issue.record("expected .toolUse, got \(collected[0])")
        }
    }

    /// T12 contract: incomplete tool_call (= id but no name by stream
    /// end) is dropped (= better to skip than emit malformed block).
    @Test func incomplete_tool_call_dropped() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": [
                        "tool_calls": [
                            ["index": 0, "id": "t1",
                             "function": ["arguments": "{}"]]
                        ]
                    ]
                ]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.isEmpty, "expected no blocks (= incomplete dropped), got \(collected)")
    }

    /// T12 contract: reasoning_delta emits as .thinking (= preserved
    /// from T10 behavior; = the stateful variant doesn't swallow it).
    @Test func reasoning_delta_emits_in_stateful_variant() async {
        let chunks: [String] = [
            makeJSON([
                "choices": [[
                    "delta": ["reasoning": "let me think..."]
                ]]
            ]),
            "[DONE]"
        ]
        let sourceStream = AsyncStream<String> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        let out = OpenAIChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 1)
        if case .thinking(let t, _) = collected[0] {
            #expect(t == "let me think...")
        } else {
            Issue.record("expected .thinking, got \(collected[0])")
        }
    }
}