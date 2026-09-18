//
//  LLMConnectorStreamTests.swift · Wenshu · T7-STREAM-DEFAULT (2026-09-18)
//
//  Verifies the default `stream()` implementation on LLMConnector
//  yields each block from `send(...)` (= one AsyncStream per call).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LLMConnector stream() default (T7-STREAM-DEFAULT)")
struct LLMConnectorStreamTests {

    private struct MockConnector: LLMConnector {
        let connectorID = "mock-t7"
        func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
            LLMResponse(
                id: "1", model: options.model,
                blocks: [
                    .text("Hello "),
                    .text("world."),
                    .thinking(text: "internal reasoning", signature: nil),
                ],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 5, outputTokens: 5)
            )
        }
    }

    @Test func default_stream_yields_all_response_blocks() async {
        let connector = MockConnector()
        let options = LLMCallOptions(model: "mock", maxTokens: 100)
        let stream = connector.stream(messages: [], options: options)
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 3, "expected 3 blocks, got \(collected.count)")
        if case .text(let s1) = collected[0] {
            #expect(s1 == "Hello ")
        } else {
            Issue.record("expected first .text, got \(collected[0])")
        }
        if case .text(let s2) = collected[1] {
            #expect(s2 == "world.")
        } else {
            Issue.record("expected second .text, got \(collected[1])")
        }
        if case .thinking(let t, _) = collected[2] {
            #expect(t == "internal reasoning")
        } else {
            Issue.record("expected third .thinking, got \(collected[2])")
        }
    }

    @Test func default_stream_emits_error_on_send_failure() async {
        struct FailingConnector: LLMConnector {
            let connectorID = "mock-fail"
            func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
                throw LLMConnectorError.transport(
                    provider: "mock-fail", statusCode: 500, body: "boom"
                )
            }
        }
        let stream = FailingConnector().stream(
            messages: [],
            options: LLMCallOptions(model: "x")
        )
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 1, "expected exactly 1 error block, got \(collected.count)")
        if case .text(let s) = collected[0] {
            #expect(s.contains("[stream error]"))
            #expect(s.contains("boom"))
        } else {
            Issue.record("expected .text error block, got \(collected[0])")
        }
    }
}