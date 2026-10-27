//
//  LLMConnectorStreamTests.swift · Wenshu · T7-STREAM-DEFAULT (2026-09-18)
//
//  Verifies how a connector's own `stream(...)` behaves. The default
//  implementation on LLMConnector was deleted (commit 4a9515bd5c), so
//  every connector owns its stream: the block sequence a connector
//  yields, and the failure a connector reports when it cannot serve
//  the call.
//

import Testing
import Foundation
import WenshuAgent
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

    /// A connector owns its stream (= the default `LLMConnector.stream()`
    /// extension was deleted in commit 4a9515bd5c), so the failure a
    /// connector cannot serve must reach the caller through that
    /// connector's own stream.
    ///
    /// The provider has no credential here, which is the failure the
    /// send path raises (`LLMConnectorError.missingAPIKey`). The
    /// connector's own stream reports that same failure in-band: one
    /// text block carrying the `[stream error]` marker and the
    /// provider it belongs to. A stream that ended without a word
    /// would look like a model that said nothing, so the caller has to
    /// see the refusal.
    @Test func connector_own_stream_reports_the_failure_send_would_throw() async throws {
        // The provider has no key, so the call cannot be served. The
        // store is injected, so the test never touches a real keychain.
        let store = InMemoryKeychainStore()
        try await ProviderKeychain.withBackendForTesting(store) {
            let connector = DeepSeekConnector()
            let options = LLMCallOptions(model: "deepseek-chat")

            // The send path raises the failure.
            await #expect(throws: LLMConnectorError.self) {
                try await connector.send(messages: [], options: options)
            }

            // The connector's own stream reports the same failure.
            var collected: [LLMBlock] = []
            for await block in connector.stream(messages: [], options: options) {
                collected.append(block)
            }
            let texts = collected.compactMap { block -> String? in
                if case .text(let s) = block { return s }
                return nil
            }
            #expect(texts.count == 1,
                    "expected exactly 1 text block, got \(collected.count)")
            #expect(texts.first?.contains("[stream error]") == true,
                    "the failure must carry the stream-error marker, got \(texts)")
            #expect(texts.first?.contains("deepseek") == true,
                    "the failure must name the provider it belongs to, got \(texts)")
        }
    }
}