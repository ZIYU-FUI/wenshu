//
//  AnthropicStreamingToolUseAggregationTests.swift · Wenshu · T11-ANTHROPIC-TOOL-USE-STREAM-AGG (2026-09-18)
//
//  Verifies the stateful converter (= T11 addition): accumulates
//  tool_use blocks across contentBlockStart + input_delta deltas +
//  contentBlockStop and emits a single .toolUse LLMBlock with the
//  assembled JSON input. Also covers parallel tool_use blocks (=
//  different blockIndex = different in-flight tool calls).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicStreamingChunkToLLMBlock tool_use aggregation (T11)")
struct AnthropicStreamingToolUseAggregationTests {

    // MARK: - Ingest-level (= single ToolUseAccumulator)

    /// T11 contract: a complete tool_use block (= start + 2 deltas +
    /// stop) emits ONE .toolUse LLMBlock at stop time with the
    /// assembled JSON input.
    @Test func tool_use_block_assembled_at_stop() {
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "tool_use", blockIndex: 1,
                toolId: "tool-1", toolName: "read_file"
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "{\"path\":", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "\"foo.txt\"}", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 1)),
        ]
        var emitted: [LLMBlock] = []
        for chunk in chunks {
            if let block = acc.ingest(chunk) {
                emitted.append(block)
            }
        }
        #expect(emitted.count == 1, "expected exactly 1 .toolUse, got \(emitted.count)")
        if case .toolUse(let id, let name, let input) = emitted[0] {
            #expect(id == "tool-1")
            #expect(name == "read_file")
            #expect(input == "{\"path\":\"foo.txt\"}")
        } else {
            Issue.record("expected .toolUse, got \(emitted[0])")
        }
    }

    /// T11 contract: in the same response, text deltas emit IMMEDIATELY
    /// (= they don't wait for stop). This matches the user's expectation
    /// of streaming text + tool card = simultaneous.
    @Test func text_delta_emits_immediately_alongside_tool_use() {
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 0, textDelta: "Hello ",
                inputDelta: nil, thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 0, textDelta: "world.",
                inputDelta: nil, thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "tool_use", blockIndex: 1,
                toolId: "tool-1", toolName: "read_file"
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "{}", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 1)),
        ]
        var emitted: [LLMBlock] = []
        for chunk in chunks {
            if let block = acc.ingest(chunk) {
                emitted.append(block)
            }
        }
        #expect(emitted.count == 3, "expected 3 blocks (2 .text + 1 .toolUse), got \(emitted.count)")
        if case .text(let s1) = emitted[0] { #expect(s1 == "Hello ") } else { Issue.record("expected first .text") }
        if case .text(let s2) = emitted[1] { #expect(s2 == "world.") } else { Issue.record("expected second .text") }
        if case .toolUse(_, let name, _) = emitted[2] { #expect(name == "read_file") } else { Issue.record("expected .toolUse") }
    }

    /// T11 contract: parallel tool_use blocks (= different blockIndex)
    /// are tracked independently.
    @Test func parallel_tool_use_blocks_tracked_independently() {
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        // Block 0: tool_a, args {"a":1}
        // Block 1: tool_b, args {"b":2}
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "tool_use", blockIndex: 0,
                toolId: "tool-a", toolName: "callback_a"
            )),
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "tool_use", blockIndex: 1,
                toolId: "tool-b", toolName: "callback_b"
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 0, textDelta: nil,
                inputDelta: "{\"a\":1}", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "{\"b\":2}", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 0)),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 1)),
        ]
        var emitted: [LLMBlock] = []
        for chunk in chunks {
            if let block = acc.ingest(chunk) {
                emitted.append(block)
            }
        }
        #expect(emitted.count == 2, "expected 2 .toolUse blocks, got \(emitted.count)")
        // Order = stop order = block 0 first, block 1 second.
        if case .toolUse(let id0, let name0, let input0) = emitted[0] {
            #expect(id0 == "tool-a")
            #expect(name0 == "callback_a")
            #expect(input0 == "{\"a\":1}")
        } else {
            Issue.record("expected first .toolUse to be tool-a")
        }
        if case .toolUse(let id1, let name1, let input1) = emitted[1] {
            #expect(id1 == "tool-b")
            #expect(name1 == "callback_b")
            #expect(input1 == "{\"b\":2}")
        } else {
            Issue.record("expected second .toolUse to be tool-b")
        }
    }

    /// T11 contract: contentBlockStop without a preceding tool_use
    /// start (= e.g. a text block closing) emits no .toolUse (= no
    /// false positive).
    @Test func stop_without_prior_tool_use_emits_nothing() {
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "text", blockIndex: 0,
                toolId: nil, toolName: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 0, textDelta: "hi",
                inputDelta: nil, thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 0)),
        ]
        var emitted: [LLMBlock] = []
        for chunk in chunks {
            if let block = acc.ingest(chunk) {
                emitted.append(block)
            }
        }
        #expect(emitted.count == 1, "expected exactly 1 .text (no tool_use), got \(emitted.count)")
        if case .text = emitted[0] {
            // ok
        } else {
            Issue.record("expected .text block")
        }
    }

    /// T11 contract: thinking_delta emits as .thinking (= not changed
    /// from T6 behavior; = just verify the stateful variant doesn't
    /// accidentally swallow it).
    @Test func thinking_delta_emits_in_stateful_variant() {
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        let chunk = AnthropicStreamingChunk(kind: .contentBlockDelta(
            blockIndex: 0, textDelta: nil,
            inputDelta: nil, thinkingDelta: "thinking aloud"
        ))
        guard let block = acc.ingest(chunk) else {
            Issue.record("expected .thinking block, got nil")
            return
        }
        if case .thinking(let t, _) = block {
            #expect(t == "thinking aloud")
        } else {
            Issue.record("expected .thinking, got \(block)")
        }
    }

    // MARK: - Stream-level (= convert(stream:, accumulator:))

    /// T11 contract: the stateful stream variant yields the same
    /// blocks as the per-chunk loop (= end-to-end AsyncStream path).
    @Test func stateful_stream_emits_tool_use_at_stop() async {
        let chunks: [AnthropicStreamingChunk] = [
            AnthropicStreamingChunk(kind: .contentBlockStart(
                blockType: "tool_use", blockIndex: 1,
                toolId: "t1", toolName: "read_file"
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "{\"path\":", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockDelta(
                blockIndex: 1, textDelta: nil,
                inputDelta: "\"x.txt\"}", thinkingDelta: nil
            )),
            AnthropicStreamingChunk(kind: .contentBlockStop(blockIndex: 1)),
        ]
        let sourceStream = AsyncStream<AnthropicStreamingChunk> { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
        let acc = AnthropicChunkToLLMBlockConverter.ToolUseAccumulator()
        let outStream = AnthropicChunkToLLMBlockConverter.convert(
            stream: sourceStream, accumulator: acc
        )
        var collected: [LLMBlock] = []
        for await block in outStream {
            collected.append(block)
        }
        #expect(collected.count == 1, "expected 1 .toolUse, got \(collected.count)")
        if case .toolUse(let id, let name, let input) = collected[0] {
            #expect(id == "t1")
            #expect(name == "read_file")
            #expect(input == "{\"path\":\"x.txt\"}")
        } else {
            Issue.record("expected .toolUse, got \(collected[0])")
        }
    }
}