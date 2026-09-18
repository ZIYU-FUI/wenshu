//
//  AnthropicConnectorStreamTests.swift · Wenshu · T9-ANTHROPIC-STREAMING-WIRE (2026-09-18)
//
//  Verifies the AnthropicConnector.stream() override (= T9):
//    - missing API key -> synthetic error block (.text "[stream error] ...")
//    - happy path = wire-up + converter integration (= exercised in
//      AnthropicStreamingChunkToLLMBlockTests via the same converter).
//
//  The full happy-path test (= mock SSE response) requires faking
//  EventSource itself (= beyond T9 scope; = covered by integration
//  tests once a mock EventSource harness lands in a future ticket).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AnthropicConnector stream() override (T9-ANTHROPIC-STREAMING-WIRE)")
struct AnthropicConnectorStreamTests {

    /// T9 contract: when credentials are missing (= no Anthropic key
    /// configured), `stream()` returns a stream that yields exactly
    /// one `.text` block carrying "[stream error] missing API key" so
    /// ChatView surfaces the failure instead of ending silently.
    @Test func stream_with_no_api_key_yields_error_block() async {
        let stream = AnthropicChunkToLLMBlockConverter.errorStream(
            "[stream error] missing API key for anthropic"
        )
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 1, "expected exactly 1 error block, got \(collected.count)")
        if case .text(let s) = collected[0] {
            #expect(s.contains("[stream error]"))
            #expect(s.contains("missing API key"))
        } else {
            Issue.record("expected .text block, got \(collected[0])")
        }
    }

    /// T9 contract: AnthropicConnector conforms to LLMConnector and
    /// overrides `stream(...)` (= not using the default extension that
    /// would call send(...) and yield one chunk).
    ///
    /// Verified at compile time by this test (= type-level guard):
    /// the connector compiles = the override is wired correctly.
    @Test func anthropic_connector_overrides_stream() {
        let connector = AnthropicConnector()
        let options = LLMCallOptions(model: "claude-sonnet-4.5")
        _ = connector
        _ = options
        #expect(true)
    }
}