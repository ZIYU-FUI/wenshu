//
//  AnthropicStreamingChunkToLLMBlock.swift · Wenshu · T6-ANTHROPIC-STREAMING-THINKING
//                                                  T11-ANTHROPIC-TOOL-USE-STREAM-AGG
//
//  Pure converter from Anthropic SSE chunks -> cross-connector LLMBlock.
//
//  Boss symptom (2026-09-18 'thinking 不可见'): T1 hides the legacy
//  DisclosureGroup when message.parts contains a .reasoning part; but
//  no reasoning part ever arrives (= the streamCallback never gets a
//  .thinking block). Root cause: AnthropicConnector.send() goes through
//  the synchronous path (= no streaming); even when the streaming
//  wire-up exists (= AnthropicStreamingWireup.swift), no one converts
//  its AnthropicStreamingChunk events into LLMBlock.thinking.
//
//  T6 scope (= wenshu-pocock-workflow §11.1 minimal change):
//    1. Add this converter (= single-purpose pure function).
//    2. Test it (= hermes-style: input a sequence of AnthropicStreamingChunks,
//       assert the output LLMBlock stream contains .thinking blocks).
//    3. NOT wired into AnthropicConnector (= that's a separate ticket;
//       = the converter sits in place so a future T7 ticket only has
//       to thread the stream through, not write the conversion).
//
//  T11 extension: aggregate tool_use blocks across 3 SSE event types
//  (= content_block_start with type=tool_use + content_block_delta with
//  input_delta + content_block_stop). Until T11, input_delta chunks
//  were dropped (= the full tool_use JSON never reached ChatView).
//
//  Conversion rules (per Anthropic SSE spec + wenshu LLMBlock contract):
//    - contentBlockStart(.text, ...)                   -> no LLMBlock
//    - contentBlockStart(.thinking, ...)              -> no LLMBlock
//    - contentBlockStart(.tool_use, ...)               -> no LLMBlock (= record state)
//    - contentBlockDelta(textDelta:...)               -> .text(textDelta)
//    - contentBlockDelta(thinkingDelta:...)           -> .thinking(text, signature: nil)
//    - contentBlockDelta(inputDelta:...)              -> no LLMBlock (= append to buffer)
//    - contentBlockStop                                -> emit .toolUse if state has one
//                                                        (= drops .toolResult on the floor;
//                                                        = ToolExecutor in T2 already emits
//                                                        the real .toolResult from the
//                                                        server-side execution). For wenshu
//                                                        chat zone this means tool cards
//                                                        appear (= .toolUse) without a
//                                                        follow-up .toolResult (= which T2
//                                                        emits separately via the LLM block
//                                                        emitted by the ToolExecutor path).
//    - thinking content_block_stop                     -> drop (= T6/T7 deferred signature pairing)
//    - messageDelta / messageStop / ping / unknown    -> no LLMBlock
//
//  Note on accumulation: Anthropic streaming emits MANY deltas per
//  block (= 1 text chunk per token). This converter emits 1 .text
//  LLMBlock per delta (= ChatView's accumulator merges consecutive
//  .text parts). The caller doesn't need to pre-aggregate.
//
//  Note on thread-safety: T11's per-blockIndex state is stored on a
//  `stateful` variant of the converter (= a struct passed by
//  reference). The pure stateless function remains for callers that
//  don't need tool_use aggregation (= e.g. non-streaming). The stateful
//  variant is used by `convert(stream:stateful:)`.
//

import Foundation

public enum AnthropicChunkToLLMBlockConverter {

    // MARK: - Stateless converter (= T6 / T9 contract; = unchanged)

    /// Convert one AnthropicStreamingChunk to zero or one LLMBlock.
    /// Returns nil for chunks that don't produce a user-visible block.
    /// Tool_use aggregation is NOT performed here (= use the stateful
    /// variant when tool_use needs to be assembled from delta chunks).
    public static func convert(_ chunk: AnthropicStreamingChunk) -> LLMBlock? {
        switch chunk.kind {
        case .contentBlockStart:
            // Block headers don't carry content yet. = nil.
            return nil
        case .contentBlockDelta(let blockIndex, let textDelta, _, let thinkingDelta):
            // Anthropic sends ONE delta kind per delta event (= either
            // textDelta OR inputDelta OR thinkingDelta, never multiple).
            if let text = textDelta, !text.isEmpty {
                return .text(text)
            }
            if let thinking = thinkingDelta, !thinking.isEmpty {
                // T6 emits .thinking without a signature (= the
                // signature comes from a separate content_block_stop
                // in extended-thinking mode; = future T7 ticket will
                // wire the signature pairing).
                return .thinking(text: thinking, signature: nil)
            }
            // inputDelta (= tool_use JSON partial) doesn't become a
            // user-visible block in the stateless variant (= use the
            // stateful variant for tool_use aggregation).
            _ = blockIndex
            return nil
        case .contentBlockStop:
            return nil
        case .messageDelta:
            return nil
        case .messageStop:
            return nil
        case .ping:
            return nil
        case .unknown:
            return nil
        }
    }

    /// Convert an AsyncStream of AnthropicStreamingChunk to an
    /// AsyncStream of LLMBlock (= drops the chunks that don't produce
    /// user-visible blocks; = no tool_use aggregation here; = use the
    /// stateful variant for that).
    public static func convert(
        stream: AsyncStream<AnthropicStreamingChunk>
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                for await chunk in stream {
                    if let block = convert(chunk) {
                        continuation.yield(block)
                    }
                }
                continuation.finish()
            }
        }
    }

    /// T9-ANTHROPIC-STREAMING-WIRE (2026-09-18): produce a synthetic
    /// error stream that yields exactly one `.text` block carrying the
    /// error message, then finishes. Used by AnthropicConnector.stream()
    /// when credentials are missing (= no SSE connection can be opened)
    /// so ChatView surfaces the error instead of ending the stream
    /// silently.
    public static func errorStream(_ message: String) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            continuation.yield(.text("[stream error] \(message)"))
            continuation.finish()
        }
    }

    // MARK: - T11 stateful converter (= aggregates tool_use across deltas)

    /// Per-tool-use-block state (= one entry per open content_block_start
    /// of type=tool_use that hasn't yet been closed by content_block_stop).
    ///
    /// `inputBuffer` accumulates partial JSON across content_block_delta
    /// events. When content_block_stop fires, the converter emits a
    /// `.toolUse` LLMBlock with `input` set to the assembled JSON.
    ///
    /// Reference type so callers can hold the state across `convert(stream:)`
    /// iterations without copying (= parallel to the AsyncStream accumulator
    /// pattern in ChatView streamCallback).
    ///
    /// `@unchecked Sendable`: the only mutation entry point is `ingest(_:)`,
    /// which is serial within a single `convert(stream:, accumulator:)`
    /// invocation (= the AsyncStream yields one chunk at a time; =
    /// no concurrent mutation). Cross-stream sharing would require
    /// external synchronization (= future ticket if needed).
    public final class ToolUseAccumulator: @unchecked Sendable {
        private struct PendingToolUse: Sendable {
            var id: String
            var name: String
            var inputBuffer: String
        }
        private var pending: [Int: PendingToolUse] = [:]

        public init() {}

        /// Per-chunk state mutation. Returns zero or one LLMBlock to emit
        /// (= text/thinking deltas emit immediately; tool_use emits
        /// on content_block_stop with the assembled JSON).
        public func ingest(_ chunk: AnthropicStreamingChunk) -> LLMBlock? {
            switch chunk.kind {
            case .contentBlockStart(let blockType, let blockIndex, let toolId, let toolName):
                if blockType == "tool_use", let id = toolId, let name = toolName {
                    pending[blockIndex] = PendingToolUse(
                        id: id, name: name, inputBuffer: ""
                    )
                }
                return nil
            case .contentBlockDelta(let blockIndex, let textDelta, let inputDelta, let thinkingDelta):
                // 1. inputDelta: append to tool_use input buffer.
                if let input = inputDelta, !input.isEmpty,
                   var entry = pending[blockIndex] {
                    entry.inputBuffer += input
                    pending[blockIndex] = entry
                }
                // 2. textDelta: emit immediately.
                if let text = textDelta, !text.isEmpty {
                    return .text(text)
                }
                // 3. thinkingDelta: emit as .thinking (= preserves T6 behavior).
                if let thinking = thinkingDelta, !thinking.isEmpty {
                    return .thinking(text: thinking, signature: nil)
                }
                return nil
            case .contentBlockStop(let blockIndex):
                if let entry = pending.removeValue(forKey: blockIndex) {
                    return .toolUse(
                        id: entry.id,
                        name: entry.name,
                        input: entry.inputBuffer
                    )
                }
                return nil
            case .messageDelta, .messageStop, .ping, .unknown:
                return nil
            }
        }
    }

    /// T11: stateful streaming converter. Aggregates tool_use blocks
    /// (= contentBlockStart + input_delta contentBlockDelta + contentBlockStop)
    /// into single `.toolUse` LLMBlocks at block close. Text/thinking
    /// deltas still emit immediately (= the accumulator only tracks
    /// tool_use state).
    ///
    /// Wire-format example (= one tool_use block, three events):
    ///   1. contentBlockStart(index=1, type=tool_use, id=tool-1, name=read_file)
    ///   2. contentBlockDelta(index=1, input_delta='{"path":')
    ///   3. contentBlockDelta(index=1, input_delta='"foo.txt"}')
    ///   4. contentBlockStop(index=1)
    ///   -> yields 1 .toolUse(id=tool-1, name=read_file, input='{"path":"foo.txt"}')
    ///
    /// Parallel tool_use blocks (= multiple contentBlockStart with
    /// different blockIndex in the same response) are tracked
    /// independently.
    public static func convert(
        stream: AsyncStream<AnthropicStreamingChunk>,
        accumulator: ToolUseAccumulator
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task { @Sendable in
                for await chunk in stream {
                    if let block = accumulator.ingest(chunk) {
                        continuation.yield(block)
                    }
                }
                continuation.finish()
            }
        }
    }
}