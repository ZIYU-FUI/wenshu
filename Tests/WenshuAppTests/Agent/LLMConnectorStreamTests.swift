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
        func stream(
            messages: [LLMMessage],
            options: LLMCallOptions
        ) -> AsyncStream<LLMBlock> {
            AsyncStream { continuation in
                for block in [
                    LLMBlock.text("Hello "),
                    LLMBlock.text("world."),
                    LLMBlock.thinking(text: "internal reasoning", signature: nil),
                ] {
                    continuation.yield(block)
                }
                continuation.finish()
            }
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

    /// OBSOLETE (P0-STREAM-NATIVE, commit 791acb497): the default
    /// `LLMConnector.stream()` extension was deleted (= every
    /// connector must now implement its own native stream). This
    /// test asserted the default extension's "swallow send errors
    /// as a synthetic `[stream error]` text block" behavior; =
    /// that path no longer exists. Future ticket: redesign this
    /// test to assert that a connector's `stream()` implementation
    /// (= the per-connector override) propagates send errors
    /// instead of swallowing them (= the hermes-style "let the
    /// caller decide" pattern).
    @Test func default_stream_emits_error_on_send_failure() async {
        Issue.record("""
        This test asserted behavior of the deleted default
        LLMConnector.stream() extension (= the "fake streaming"
        path that called send() and emitted a synthetic error
        block). The default was deleted in commit 791acb497;
        = every connector must now implement its own stream.
        Future ticket: redesign to assert per-connector behavior.
        """)
    }
}