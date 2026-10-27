//
//  ConversationLoopMultiTurnTests.swift · Wenshu · T3-MULTI-TURN-LOOP (2026-09-18)
//
//  Verifies ConversationLoop.runTurn wraps the tool dispatch + LLM
//  re-prompt in a while loop (= keeps going as long as the assistant
//  message contains .toolUse blocks; = up to maxAgentTurns).
//

import Testing
import Foundation
import WenshuAgent
@testable import WenshuApp

/// Counts the calls the stub connector serves.
///
/// The production path builds the turn's stream through the
/// connector's `stream` method, and that method is a synchronous
/// call, so the count is lock-guarded rather than actor-isolated.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    /// Bumps the counter and returns the ordinal of this call.
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    /// How many calls the connector has served so far.
    var snapshot: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

@Suite("ConversationLoop multi-turn (T3-MULTI-TURN-LOOP)")
struct ConversationLoopMultiTurnTests {

    /// Actor wrapper around captured blocks (= the streamCallback is
    /// @Sendable + concurrent; = captured mutable state must be in an
    /// actor to avoid Swift 6 sendable warnings).
    private actor Sink {
        var blocks: [String] = []
        func append(_ s: String) { blocks.append(s) }
        func snapshot() -> [String] { blocks }
    }

    /// Mock tool that just echoes its input.
    private struct EchoTool: Tool {
        func execute(input: String) async throws -> String { "echo:\(input)" }
    }

    /// T3 contract: when the assistant's first response has NO
    /// .toolUse (= plain text), the loop does NOT emit a turn marker
    /// (= no extra dispatch loop iteration).
    @Test func runTurn_no_tool_use_skips_turn_marker() async throws {
        struct PlainTextConnector: LLMConnector {
            let connectorID = "mock-plain"
            func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
                LLMResponse(
                    id: "1",
                    model: options.model,
                    blocks: [.text("Direct answer.")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                )
            }
            func stream(
                messages: [LLMMessage],
                options: LLMCallOptions
            ) -> AsyncStream<LLMBlock> {
                AsyncStream { continuation in
                    continuation.yield(.text("Direct answer."))
                    continuation.finish()
                }
            }
        }
        let connector = PlainTextConnector()
        let sink = Sink()
        let cb: @Sendable (LLMBlock) async -> Void = { block in
            if case .text(let s) = block { await sink.append(s) }
        }
        let loop = ConversationLoop(
            connection: connector,
            systemPrompt: "test",
            runtime: RuntimeHelpers()
        )
        _ = try await loop.runTurn(
            userMessage: "test",
            systemMessage: nil,
            conversationHistory: [],
            tools: [:],
            streamCallback: cb
        )
        let captured = await sink.snapshot()
        let turnMarkers = captured.filter { $0.contains("wenshu.agent") }
        #expect(turnMarkers.isEmpty, "no turn marker when no tool_use; got \(turnMarkers)")
    }

    /// T3 contract: when the assistant returns .toolUse then on the
    /// next LLM call returns .text, the loop MUST iterate (= 2
    /// LLM calls total; = the loop must keep going as long as the
    /// assistant message contains .toolUse blocks).
    /// [wenshu.agent] turn 2/10` marker
    /// assertion was dropped (= marker emission deleted as dead
    /// plumbing; = ChatTurnProgress.swift was removed in v1.83).
    /// The multi-turn loop behavior is still exercised below; =
    /// the test now asserts on the connector's call count (= 2)
    /// rather than on a streamCallback marker.
    ///
    /// The count is the number of calls the production path really
    /// makes: the loop builds the turn's stream through the
    /// connector's `stream` method, so the stub counts there and
    /// serves the same two replies the `send` path serves (= a tool
    /// use first, then the text). A loop that stopped iterating
    /// after the tool use would count one call instead of two.
    @Test func runTurn_continues_until_no_tool_use() async throws {
        let counter = CallCounter()
        struct TwoTurnConnector: LLMConnector {
            let connectorID = "mock-two-turn"
            let counter: CallCounter
            func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
                let n = counter.next()
                if n == 1 {
                    return LLMResponse(
                        id: "1",
                        model: options.model,
                        blocks: [.toolUse(id: "t1", name: "echo_tool", input: "{\"x\":1}")],
                        stopReason: .toolUse,
                        usage: LLMUsage(inputTokens: 10, outputTokens: 10)
                    )
                } else {
                    return LLMResponse(
                        id: "2",
                        model: options.model,
                        blocks: [.text("Final answer.")],
                        stopReason: .endTurn,
                        usage: LLMUsage(inputTokens: 5, outputTokens: 5)
                    )
                }
            }
            func stream(
                messages: [LLMMessage],
                options: LLMCallOptions
            ) -> AsyncStream<LLMBlock> {
                let n = counter.next()
                let blocks: [LLMBlock] = n == 1
                    ? [.toolUse(id: "t1", name: "echo_tool", input: "{\"x\":1}")]
                    : [.text("Final answer.")]
                return AsyncStream { continuation in
                    for block in blocks {
                        continuation.yield(block)
                    }
                    continuation.finish()
                }
            }
        }
        let connector = TwoTurnConnector(counter: counter)
        let sink = Sink()
        let cb: @Sendable (LLMBlock) async -> Void = { block in
            if case .text(let s) = block { await sink.append(s) }
        }
        let loop = ConversationLoop(
            connection: connector,
            systemPrompt: "test",
            runtime: RuntimeHelpers()
        )
        _ = try await loop.runTurn(
            userMessage: "test",
            systemMessage: nil,
            conversationHistory: [],
            tools: ["echo_tool": EchoTool()],
            streamCallback: cb
        )
        // The connector was called twice (= 1 initial + 1 follow-up
        // because the first reply had a .toolUse block).
        let callCount = counter.snapshot
        #expect(callCount == 2, "expected 2 LLM calls (= loop must iterate on toolUse); got \(callCount)")
        // And no turn-marker is in the stream (= the dead marker
        // emission is gone).
        let captured = await sink.snapshot()
        let turnMarkers = captured.filter { $0.contains("wenshu.agent") && $0.contains("turn") }
        #expect(turnMarkers.isEmpty, "no turn marker; got \(turnMarkers)")
    }
}
