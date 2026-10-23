// PromptCacheRecorderPathTests.swift
//
// The recorder's number must reach the conversation it belongs to.
//
// The recorder is fed from the running turn, so the test drives the
// PRODUCTION path (= the conductor's handle, into the real turn, into
// the real provider stream, through the real OpenAI-compatible chunk
// decoder) rather than calling the recorder directly. A test that calls
// `record(...)` proves the arithmetic; it does not prove the turn's
// number ever lands there, nor that two turns of the SAME conversation
// land on the SAME total.
//
// The key is the chat session (= what the user calls a conversation),
// not the turn's task id: the task id is a fresh UUID per turn when
// the caller does not supply one, so keying on it would reset the
// running total every turn and the total would never grow.

import Foundation
import Testing
@testable import WenshuAgent

/// A connector that speaks the OpenAI-compatible SSE wire (= the family
/// whose routes carry the cache marker).
///
/// The stream it produces is the shape a provider sends: content
/// deltas, then a final chunk carrying the `usage` object beside an
/// empty `choices` array. The chunks are decoded by the REAL
/// OpenAI-compatible decoder (= the same one the production connector
/// uses), so the test proves the counters survive the whole trip
/// rather than proving the mock can count.
private actor CacheCountingConnector: LLMConnector {
    nonisolated let connectorID: String = "mock"
    nonisolated let contextWindow: Int = 32_000

    init() {}

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        LLMResponse(
            id: "mock",
            model: "mock",
            blocks: [.text("done")],
            stopReason: .endTurn,
            usage: LLMUsage(
                inputTokens: 1000,
                outputTokens: 50,
                cacheReadTokens: 800,
                cacheCreationTokens: 200
            )
        )
    }

    nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        // The provider's wire: a content delta, then the final chunk
        // with the counters.
        let raw = AsyncStream<String> { continuation in
            continuation.yield("""
            {"choices":[{"index":0,"delta":{"content":"done"}}]}
            """)
            continuation.yield("""
            {"choices":[],"usage":{"prompt_tokens":1000,"completion_tokens":50,\
            "prompt_tokens_details":{"cached_tokens":800}}}
            """)
            continuation.finish()
        }
        // The production decoder (= the same call the OpenAI-compatible
        // connector makes).
        return OpenAIChunkToLLMBlockConverter.convert(
            stream: raw,
            accumulator: OpenAIChunkToLLMBlockConverter.ToolUseAccumulator()
        )
    }
}

@Suite("The cache totals reach the conversation")
struct PromptCacheRecorderPathTests {

    /// The turn's provider counters land on the conversation's total,
    /// and a second turn of the same conversation lands on the SAME
    /// total (= the running total grows instead of resetting).
    @Test("two turns of one conversation share one running total")
    @MainActor
    func twoTurnsShareOneRunningTotal() async throws {
        let sessionId = "s_cache-session-1"
        let conductor = WenshuConductor(connector: CacheCountingConnector())

        let first = await conductor.handle(
            userMessage: "first turn",
            sessionId: sessionId,
            model: "mock"
        )
        #expect(
            first.totalTokens == 1050,
            "the turn must report the provider's counters (= input + output, not zero)"
        )

        let afterFirst = await PromptCacheRecorder.shared.totals(conversationId: sessionId)
        #expect(afterFirst.callCount == 1)
        #expect(afterFirst.cacheReadTokens == 800)
        #expect(
            afterFirst.cacheCreationTokens == 0,
            "the OpenAI-compatible wire reports no cache-creation count (= it has no field for one)"
        )

        // The second turn of the SAME conversation.
        let second = await conductor.handle(
            userMessage: "second turn",
            sessionId: sessionId,
            model: "mock"
        )
        #expect(second.totalTokens == 1050)

        let afterSecond = await PromptCacheRecorder.shared.totals(conversationId: sessionId)
        #expect(
            afterSecond.callCount == 2,
            "the second turn must land on the same total (= the key is the conversation, not the turn)"
        )
        #expect(afterSecond.cacheReadTokens == 1600)
        #expect(afterSecond.cacheCreationTokens == 0)
        #expect(afterSecond.savedInputTokens == 1600)
    }

    /// Another conversation keeps its own total (= the numbers are not
    /// one global pile).
    @Test("another conversation keeps its own total")
    @MainActor
    func anotherConversationKeepsItsOwnTotal() async throws {
        let conductor = WenshuConductor(connector: CacheCountingConnector())

        _ = await conductor.handle(
            userMessage: "one",
            sessionId: "s_cache-session-a",
            model: "mock"
        )
        _ = await conductor.handle(
            userMessage: "two",
            sessionId: "s_cache-session-b",
            model: "mock"
        )

        let a = await PromptCacheRecorder.shared.totals(conversationId: "s_cache-session-a")
        let b = await PromptCacheRecorder.shared.totals(conversationId: "s_cache-session-b")
        #expect(a.callCount == 1)
        #expect(b.callCount == 1)
        #expect(a.cacheReadTokens == 800)
        #expect(b.cacheReadTokens == 800)
    }
}
