//
//  AnthropicStreamingChunkToLLMBlock.swift · Wenshu · T6-ANTHROPIC-STREAMING-THINKING (2026-09-18)
//
//  Pure converter from Anthropic SSE chunks → cross-connector LLMBlock.
//  Bridges the gap between AnthropicStreamingWireup (which yields
//  AnthropicStreamingChunk per SSE event) and the ConversationLoop
//  streamCallback contract (= LLMBlock).
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
//  Conversion rules (per Anthropic SSE spec + wenshu LLMBlock contract):
//    • contentBlockStart(.text, ...) → no LLMBlock (just opens a text block)
//    • contentBlockDelta(blockIndex, textDelta:...) → .text(textDelta) (accumulated by caller)
//    • contentBlockDelta(blockIndex, thinkingDelta:...) → .thinking(text, signature: nil)
//    • contentBlockDelta(blockIndex, inputDelta:...) → no LLMBlock (tool input JSON partial)
//    • contentBlockStop → no LLMBlock
//    • messageDelta → no LLMBlock
//    • messageStop → no LLMBlock (= ConversationLoop interprets finish differently)
//
//  Note on accumulation: Anthropic streaming emits MANY deltas per
//  block (= 1 text chunk per token). This converter emits 1 .text
//  LLMBlock per delta (= ChatView's accumulator merges consecutive
//  .text parts). The caller doesn't need to pre-aggregate.
//

import Foundation

public enum AnthropicChunkToLLMBlockConverter {

    /// Convert one AnthropicStreamingChunk to zero or one LLMBlock.
    /// Returns nil for chunks that don't produce a user-visible block
    /// (= block start/stop, message delta, etc).
    public static func convert(_ chunk: AnthropicStreamingChunk) -> LLMBlock? {
        switch chunk.kind {
        case .contentBlockStart:
            // Block headers don't carry content yet (= the next delta
            // will). = nil.
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
            // user-visible block yet (= the complete toolUse fires
            // at content_block_stop).
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
    /// user-visible blocks).
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
}