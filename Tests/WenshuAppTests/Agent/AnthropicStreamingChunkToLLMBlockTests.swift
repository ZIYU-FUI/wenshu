//
//  AnthropicStreamingChunkToLLMBlockTests.swift · Wenshu · T6-ANTHROPIC-STREAMING-THINKING (2026-09-18)
//
//  Verifies AnthropicStreamingChunk → LLMBlock conversion rules:
//    • text deltas → .text
//    • thinking deltas → .thinking
//    • block start/stop, message delta/stop, ping → no block (filtered)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicStreamingChunkToLLMBlock (T6-ANTHROPIC-STREAMING-THINKING)")
struct AnthropicStreamingChunkToLLMBlockTests {

    /// T6 contract: text deltas become .text blocks (= exactly 1 per
    /// non-empty textDelta; empty deltas filtered).
    @Test func text_delta_becomes_text_block() {
        let chunk = AnthropicStreamingChunk(kind: .contentBlockDelta(
            blockIndex: 0, textDelta: "Hello", inputDelta: nil, thinkingDelta: nil
        ))
        let block = AnthropicChunkToLLMBlockConverter.convert(chunk)
        #expect(block != nil)
        if case .text(let s) = block {
            #expect(s == "Hello")
        } else {
            Issue.record("expected .text, got \(String(describing: block))")
        }
    }

    /// T6 contract: thinking deltas become .thinking blocks (= no
    /// signature yet; = streaming extended-thinking still requires
    /// a separate content_block_stop that T6 doesn't handle).
    @Test func thinking_delta_becomes_thinking_block() {
        let chunk = AnthropicStreamingChunk(kind: .contentBlockDelta(
            blockIndex: 0, textDelta: nil, inputDelta: nil, thinkingDelta: "Let me think..."
        ))
        let block = AnthropicChunkToLLMBlockConverter.convert(chunk)
        #expect(block != nil)
        if case .thinking(let text, let signature) = block {
            #expect(text == "Let me think...")
            #expect(signature == nil, "signature pairing is a T7 concern")
        } else {
            Issue.record("expected .thinking, got \(String(describing: block))")
        }
    }

    /// T6 contract: empty textDelta + empty thinkingDelta = no block.
    @Test func empty_delta_returns_nil() {
        let chunk = AnthropicStreamingChunk(kind: .contentBlockDelta(
            blockIndex: 0, textDelta: "", inputDelta: nil, thinkingDelta: ""
        ))
        let block = AnthropicChunkToLLMBlockConverter.convert(chunk)
        #expect(block == nil)
    }

    /// T6 contract: contentBlockStart / Stop / messageStop / ping /
    /// unknown = all return nil (= don't pollute streamCallback).
    @Test func non_content_chunks_return_nil() {
        let cases: [AnthropicStreamingChunk.Kind] = [
            .contentBlockStart(blockType: "text", blockIndex: 0, toolId: nil, toolName: nil),
            .contentBlockStop(blockIndex: 0),
            .messageDelta(stopReason: "end_turn"),
            .messageStop,
            .ping,
            .unknown("weird_event"),
        ]
        for kind in cases {
            let chunk = AnthropicStreamingChunk(kind: kind)
            let block = AnthropicChunkToLLMBlockConverter.convert(chunk)
            #expect(block == nil, "expected nil for \(kind), got \(String(describing: block))")
        }
    }

    /// T6 contract: when a full chunk stream is fed, only content
    /// blocks emerge (= the rest are dropped).
    @Test func full_chunk_stream_produces_only_content_blocks() async {
        // Build an AsyncStream of chunks.
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockStart(blockType: "thinking", blockIndex: 0, toolId: nil, toolName: nil)),
            AnthropicStreamingChunk(kind: .contentBlockDelta(blockIndex: 0, textDelta: nil, inputDelta: nil, thinkingDelta: "Reasoning...")),
            AnthropicStreamingChunk(kind: .contentBlockDelta(blockIndex: 0, textDelta: nil, inputDelta: nil, thinkingDelta: "more reasoning")),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 0)),
            AnthropicStreamingChunk(kind: .contentBlockStart(blockType: "text", blockIndex: 1, toolId: nil, toolName: nil)),
            AnthropicStreamingChunk(kind: .contentBlockDelta(blockIndex: 1, textDelta: "Hello ", inputDelta: nil, thinkingDelta: nil)),
            AnthropicStreamingChunk(kind: .contentBlockDelta(blockIndex: 1, textDelta: "world.", inputDelta: nil, thinkingDelta: nil)),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 1)),
            AnthropicStreamingChunk(kind: .messageDelta(stopReason: "end_turn")),
            AnthropicStreamingChunk(kind: .messageStop),
        ]
        let sourceStream = AsyncStream<AnthropicStreamingChunk> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        // Convert + collect.
        let outStream = AnthropicChunkToLLMBlockConverter.convert(stream: sourceStream)
        var collected: [LLMBlock] = []
        for await block in outStream {
            collected.append(block)
        }
        // Expect: 2 .thinking + 2 .text (= 4 blocks total).
        #expect(collected.count == 4, "expected 4 content blocks, got \(collected.count)")
        // First 2 are thinking blocks.
        if case .thinking(let t1, _) = collected[0] {
            #expect(t1 == "Reasoning...")
        } else {
            Issue.record("expected first block to be .thinking")
        }
        if case .thinking(let t2, _) = collected[1] {
            #expect(t2 == "more reasoning")
        } else {
            Issue.record("expected second block to be .thinking")
        }
        // Last 2 are text blocks.
        if case .text(let s1) = collected[2] {
            #expect(s1 == "Hello ")
        } else {
            Issue.record("expected third block to be .text")
        }
        if case .text(let s2) = collected[3] {
            #expect(s2 == "world.")
        } else {
            Issue.record("expected fourth block to be .text")
        }
    }
}