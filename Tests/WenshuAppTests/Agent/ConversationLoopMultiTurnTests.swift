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
    /// next LLM call returns .text, the loop MUST emit a
    /// "[wenshu.agent] turn 2/10" marker (= ChatView's ChatTurnProgress
    /// button surfaces this).
    @Test func runTurn_continues_until_no_tool_use() async throws {
        actor CallCount {
            var n = 0
            func next() -> Int {
                n += 1
                return n
            }
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
        let captured = await sink.snapshot()
        let turnMarkers = captured.filter { $0.contains("wenshu.agent") && $0.contains("turn 2/10") }
        #expect(!turnMarkers.isEmpty, "expected turn 2/10 marker; got \(captured)")
    }
}