// PromptCacheStreamTests.swift
//
// The cache counters that arrive INSIDE the stream.
//
// A provider sends its counters in its stream events, not in one place:
// the input count and the cache counts with the first event, the output
// count with the last one. These tests drive the decoder and the turn's
// collector, so the counters have to survive the trip and land in the
// usage the turn reports.

import Foundation
import Testing
@testable import WenshuAgent

@Suite("Prompt cache counters in the stream")
struct PromptCacheStreamTests {

    /// The Anthropic stream sends the input count and the cache counts
    /// with its first event.
    @Test("the Anthropic stream decoder reads the cache counts")
    func anthropicStreamDecoderReadsCacheCounts() throws {
        let event = """
        {
          "type": "message_start",
          "message": {
            "id": "msg_1",
            "model": "claude-sonnet-4-5",
            "usage": {
              "input_tokens": 1000,
              "output_tokens": 1,
              "cache_read_input_tokens": 800,
              "cache_creation_input_tokens": 200
            }
          }
        }
        """
        let chunk = try #require(
            AnthropicSSEDecoder.decode(event: "message_start", data: event)
        )
        let usage = try #require(chunk.usage)
        #expect(usage.inputTokens == 1000)
        #expect(usage.cacheReadTokens == 800)
        #expect(usage.cacheCreationTokens == 200)
    }

    /// The output count arrives with the last event.
    @Test("the Anthropic stream decoder reads the output count")
    func anthropicStreamDecoderReadsOutputCount() throws {
        let event = """
        {
          "type": "message_delta",
          "delta": {"stop_reason": "end_turn"},
          "usage": {"output_tokens": 120}
        }
        """
        let chunk = try #require(
            AnthropicSSEDecoder.decode(event: "message_delta", data: event)
        )
        let usage = try #require(chunk.usage)
        #expect(usage.outputTokens == 120)
    }

    /// The counters the decoder reads reach the turn that owns the
    /// stream, so the turn reports the provider's numbers.
    @Test("the stream counters reach the turn's collector")
    func streamCountersReachTheCollector() async throws {
        let collector = StreamUsageCollector()
        let first = """
        {
          "type": "message_start",
          "message": {"usage": {"input_tokens": 1000, "cache_read_input_tokens": 800}}
        }
        """
        let last = """
        {
          "type": "message_delta",
          "delta": {"stop_reason": "end_turn"},
          "usage": {"output_tokens": 120}
        }
        """
        StreamUsageScope.$collector.withValue(collector) {
            _ = AnthropicSSEDecoder.decode(event: "message_start", data: first)
            _ = AnthropicSSEDecoder.decode(event: "message_delta", data: last)
        }

        let usage = collector.usage
        #expect(usage.inputTokens == 1000)
        #expect(usage.outputTokens == 120)
        #expect(usage.cacheReadTokens == 800)
    }

    /// The turn's reported usage is the provider's number, not zero.
    @Test("the assembled turn reports the provider's counters")
    func assembledTurnReportsProviderCounters() async throws {
        let collector = StreamUsageCollector()
        StreamUsageScope.$collector.withValue(collector) {
            _ = AnthropicSSEDecoder.decode(
                event: "message_start",
                data: """
                {
                  "type": "message_start",
                  "message": {"usage": {"input_tokens": 1000, "cache_read_input_tokens": 800}}
                }
                """
            )
            _ = AnthropicSSEDecoder.decode(
                event: "message_delta",
                data: """
                {
                  "type": "message_delta",
                  "delta": {"stop_reason": "end_turn"},
                  "usage": {"output_tokens": 120}
                }
                """
            )
        }

        // The shape the turn assembles its response with (= the usage the
        // caller receives).
        let response = LLMResponse(
            id: "stream-1",
            model: "claude-sonnet-4-5",
            blocks: [.text("hi")],
            stopReason: .endTurn,
            usage: collector.usage
        )
        #expect(response.usage.inputTokens == 1000)
        #expect(response.usage.outputTokens == 120)
        #expect(response.usage.cacheReadTokens == 800)
        #expect(response.usage.inputTokens != 0)
    }
}
