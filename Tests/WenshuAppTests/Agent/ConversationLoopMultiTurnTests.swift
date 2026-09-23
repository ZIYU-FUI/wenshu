//
//  ConversationLoopMultiTurnTests.swift · Wenshu · T3-MULTI-TURN-LOOP (2026-09-18)
//
//  Verifies ConversationLoop.runTurn wraps the tool dispatch + LLM
//  re-prompt in a while loop (= keeps going as long as the assistant
//  message contains .toolUse blocks; = up to maxAgentTurns).
//

import Testing
import Foundation
@testable import WenshuApp

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
    /// v2.00 (2026-09-23): the `[wenshu.agent] turn 2/10` marker
    /// assertion was dropped (= marker emission deleted as dead
    /// plumbing; = ChatTurnProgress.swift was removed in v1.83).
    /// The multi-turn loop behavior is still exercised below; =
    /// the test now asserts on the connector's call count (= 2)
    /// rather than on a streamCallback marker.
    @Test func runTurn_continues_until_no_tool_use() async throws {
        actor CallCount {
            var n = 0
            func next() -> Int {
                n += 1
                return n
            }
            func snapshot() -> Int { n }
        }
        let counter = CallCount()
        struct TwoTurnConnector: LLMConnector {
            let connectorID = "mock-two-turn"
            let counter: CallCount
            func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
                let n = await counter.next()
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
        let callCount = await counter.snapshot()
        #expect(callCount == 2, "expected 2 LLM calls (= loop must iterate on toolUse); got \(callCount)")
        // And no turn-marker is in the stream (= the dead marker
        // emission is gone).
        let captured = await sink.snapshot()
        let turnMarkers = captured.filter { $0.contains("wenshu.agent") && $0.contains("turn") }
        #expect(turnMarkers.isEmpty, "no turn marker; got \(turnMarkers)")
    }
}