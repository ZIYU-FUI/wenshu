//
//  GeminiStreamingChunkToLLMBlockTests.swift · Wenshu · T15-GEMINI-STREAM (2026-09-18)
//
//  Verifies GeminiStreamingParser.parse(...) + GeminiChunkToLLMBlockConverter.convert(...)
//  cover the full Gemini wire format surface (= text deltas,
//  thinking parts, tool_calls, finishReason markers, malformed
//  payloads).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Gemini streaming chunks (T15)")
struct GeminiStreamingChunkToLLMBlockTests {

    private func makeJSON(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    /// T15 contract: text part -> .text LLMBlock.
    @Test func text_part_becomes_text_block() {
        let raw = makeJSON([
            "candidates": [[
                "content": [
                    "parts": [["text": "hello"]],
                    "role": "model"
                ],
                "index": 0
            ]]
        ])
        let chunk = GeminiStreamingParser.parse(rawData: raw)
        #expect(chunk != nil)
        let block = GeminiChunkToLLMBlockConverter.convert(chunk!)
        #expect(block != nil)
        if case .text(let s) = block {
            #expect(s == "hello")
        } else {
            Issue.record("expected .text, got \(String(describing: block))")
        }
    }

    /// T15 contract: thinking part (thought: true) -> .thinking LLMBlock
    /// (= Gemini 2.5+).
    @Test func thinking_part_becomes_thinking_block() {
        let raw = makeJSON([
            "candidates": [[
                "content": [
                    "parts": [["text": "let me consider this...", "thought": true]],
                    "role": "model"
                ],
                "index": 0
            ]]
        ])
        let chunk = GeminiStreamingParser.parse(rawData: raw)
        #expect(chunk != nil)
        let block = GeminiChunkToLLMBlockConverter.convert(chunk!)
        #expect(block != nil)
        if case .thinking(let text, let signature) = block {
            #expect(text == "let me consider this...")
            #expect(signature == nil)
        } else {
            Issue.record("expected .thinking, got \(String(describing: block))")
        }
    }

    /// T15 contract: functionCall part -> .toolUse LLMBlock.
    /// Gemini returns tool_calls fully assembled (= not partial),
    /// = no aggregation needed.
    @Test func function_call_part_becomes_tool_use_block() {
            let raw = makeJSON([
                "candidates": [[
                    "content": [
                        "parts": [[
                            "functionCall": [
                                "name": "ReadFile",
                                "args": ["path": "/tmp/x"]
                            ]
                        ]],
                        "role": "model"
                    ],
                    "index": 0
                ]]
            ])
            let chunk = GeminiStreamingParser.parse(rawData: raw)
            #expect(chunk != nil)
            let block = GeminiChunkToLLMBlockConverter.convert(chunk!)
            #expect(block != nil)
            if case .toolUse(let id, let name, let input) = block {
                #expect(id.hasPrefix("gemini-"))
                #expect(name == "ReadFile")
                // JSONSerialization may escape "/" as "\/"; both forms are
                // valid JSON. Verify the structural content (= has
                // "path" key with "/tmp/x" value).
                #expect(input.contains("\"path\""))
                #expect(input.contains("\"\\/tmp\\/x\"") || input.contains("\"/tmp/x\""))
                // Verify it round-trips as valid JSON.
                let parsed = input.data(using: .utf8).flatMap {
                    try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
                }
                #expect(parsed?["path"] as? String == "/tmp/x")
            } else {
                Issue.record("expected .toolUse, got \(String(describing: block))")
            }
        }

    /// T15 contract: same tool_call twice produces the same id
    /// (= deterministic = safe for reconnect dedup).
    @Test func same_tool_call_produces_same_id() {
        let raw = makeJSON([
            "candidates": [[
                "content": [
                    "parts": [[
                        "functionCall": [
                            "name": "ReadFile",
                            "args": ["path": "/tmp/x"]
                        ]
                    ]],
                    "role": "model"
                ],
                "index": 0
            ]]
        ])
        let chunk1 = GeminiStreamingParser.parse(rawData: raw)
        let chunk2 = GeminiStreamingParser.parse(rawData: raw)
        let block1 = GeminiChunkToLLMBlockConverter.convert(chunk1!)
        let block2 = GeminiChunkToLLMBlockConverter.convert(chunk2!)
        if case .toolUse(let id1, _, _) = block1,
           case .toolUse(let id2, _, _) = block2 {
            #expect(id1 == id2)
        } else {
            Issue.record("expected both blocks to be .toolUse")
        }
    }

    /// T15 contract: finishReason -> .finish marker (= drives stream
    /// termination in the convert(stream:) variant).
    @Test func finish_reason_becomes_finish_marker() {
        let raw = makeJSON([
            "candidates": [[
                "content": ["parts": [], "role": "model"],
                "finishReason": "STOP",
                "index": 0
            ]]
        ])
        let chunk = GeminiStreamingParser.parse(rawData: raw)
        #expect(chunk != nil)
        if case .finish(let reason) = chunk {
            #expect(reason == "STOP")
        } else {
            Issue.record("expected .finish, got \(String(describing: chunk))")
        }
        // convert(_:) returns nil for .finish (= stream caller
        // detects end-of-stream via the chunk case, not the LLMBlock).
        let block = GeminiChunkToLLMBlockConverter.convert(chunk!)
        #expect(block == nil)
    }

    /// T15 contract: malformed JSON returns nil (= caller treats as
    /// end-of-stream).
    @Test func malformed_json_returns_nil() {
        let chunk = GeminiStreamingParser.parse(rawData: "{not valid json")
        #expect(chunk == nil)
    }

    /// T15 contract: empty / [DONE] markers return nil.
    @Test func done_marker_returns_nil() {
        #expect(GeminiStreamingParser.parse(rawData: "[DONE]") == nil)
        #expect(GeminiStreamingParser.parse(rawData: "") == nil)
        #expect(GeminiStreamingParser.parse(rawData: "  \n  ") == nil)
    }

    /// T15 contract: stream variant finishes on .finish marker.
    @Test func stream_variant_finishes_on_finish_marker() async {
        let chunks: [GeminiStreamingChunk] = [
            .textDelta("hello"),
            .finish(reason: "STOP")
        ]
        let source = AsyncStream<GeminiStreamingChunk> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let out = GeminiChunkToLLMBlockConverter.convert(stream: source)
        var collected: [LLMBlock] = []
        for await block in out {
            collected.append(block)
        }
        #expect(collected.count == 1)
        if case .text(let s) = collected[0] {
            #expect(s == "hello")
        } else {
            Issue.record("expected .text, got \(String(describing: collected[0]))")
        }
    }
}