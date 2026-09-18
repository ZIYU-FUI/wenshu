//
//  MockLLMConnectorStreamTests.swift · Wenshu · T13-MOCK-STREAM-CONNECTOR (2026-09-18)
//
//  Verifies the new stream() override on MockLLMConnector:
//    - explicit streamedBlocks path
//    - scriptedResponses path (= same index advancement as send())
//    - recording side effects (streamedMessages / streamedOptions)
//    - per-call interval delay
//    - default echo path
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MockLLMConnector stream override (T13)")
struct MockLLMConnectorStreamTests {

    @Test func explicit_streamed_blocks_path() async {
        let mock = MockLLMConnector()
        await mock.setStreamedBlocksForTest([
            .text("hello"),
            .thinking(text: "let me think...", signature: nil),
            .toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/x\"}")
        ])
        let stream = mock.stream(
            messages: [.init(role: .user, blocks: [.text("read /tmp/x")])],
            options: LLMCallOptions(model: "test-model")
        )
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 3)
        if case .text(let s) = collected[0] { #expect(s == "hello") }
        else { Issue.record("expected .text first") }
        if case .thinking(let t, _) = collected[1] { #expect(t == "let me think...") }
        else { Issue.record("expected .thinking second") }
        if case .toolUse(let id, let name, let input) = collected[2] {
            #expect(id == "t1")
            #expect(name == "ReadFile")
            #expect(input == "{\"path\":\"/tmp/x\"}")
        } else { Issue.record("expected .toolUse third") }
    }

    @Test func scripted_responses_path_yields_each_block() async {
        let mock = MockLLMConnector(
            scriptedResponses: [
                LLMResponse(
                    id: "r1",
                    model: "test",
                    blocks: [.text("first"), .text(" second")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 0, outputTokens: 0)
                ),
                LLMResponse(
                    id: "r2",
                    model: "test",
                    blocks: [.text("done")],
                    stopReason: .endTurn,
                    usage: LLMUsage(inputTokens: 0, outputTokens: 0)
                )
            ]
        )
        // First stream() yields blocks of scriptedResponses[0].
        var collected: [LLMBlock] = []
        for await block in mock.stream(messages: [], options: .init(model: "m")) {
            collected.append(block)
        }
        #expect(collected.count == 2)
        if case .text(let s) = collected[0] { #expect(s == "first") }
        if case .text(let s) = collected[1] { #expect(s == " second") }
        // Second stream() advances to scriptedResponses[1].
        var collected2: [LLMBlock] = []
        for await block in mock.stream(messages: [], options: .init(model: "m")) {
            collected2.append(block)
        }
        #expect(collected2.count == 1)
        if case .text(let s) = collected2[0] { #expect(s == "done") }
    }

    @Test func stream_records_call_metadata() async {
        let mock = MockLLMConnector()
        await mock.setStreamedBlocksForTest([.text("ok")])
        let messages: [LLMMessage] = [
            .init(role: .user, blocks: [.text("hi")])
        ]
        let options = LLMCallOptions(model: "test-model")
        for await _ in mock.stream(messages: messages, options: options) { }
        let recordedMessages = await mock.streamedMessages
        let recordedOptions = await mock.streamedOptions
        #expect(recordedMessages.count == 1)
        #expect(recordedMessages[0].count == 1)
        #expect(recordedOptions.count == 1)
        #expect(recordedOptions[0].model == "test-model")
    }

    @Test func per_call_interval_inserts_delay() async {
        let mock = MockLLMConnector()
        await mock.setStreamedBlocksForTest([.text("a"), .text("b"), .text("c")])
        await mock.setStreamedBlockIntervalForTest(10_000_000)  // 10ms
        let start = Date()
        var collected: [LLMBlock] = []
        for await block in mock.stream(messages: [], options: .init(model: "m")) {
            collected.append(block)
        }
        let elapsed = Date().timeIntervalSince(start)
        #expect(collected.count == 3)
        // 2 inter-block gaps × 10ms = 20ms minimum
        #expect(elapsed >= 0.015, "elapsed=\(elapsed)s, expected >= 15ms with 2x10ms gaps")
    }

    @Test func default_echo_path_yields_one_text_block() async {
        let mock = MockLLMConnector()  // default = response "ok" = echo path
        let stream = mock.stream(
            messages: [.init(role: .user, blocks: [.text("hello world")])],
            options: .init(model: "m")
        )
        var collected: [LLMBlock] = []
        for await block in stream {
            collected.append(block)
        }
        #expect(collected.count == 1)
        if case .text(let s) = collected[0] {
            #expect(s == "echo: hello world")
        } else { Issue.record("expected .text") }
    }
}

// MARK: - Async setters for actor-isolated properties
//
// MockLLMConnector is an actor (= its mutable properties are isolated).
// Tests below the @Suite need a way to set streamedBlocks /
// streamedBlockInterval across the actor boundary.
//
// Direct assignment from outside the actor requires `await` (= these
// helpers wrap the assignment in `await` so the test code stays
// straight-line).

extension MockLLMConnector {
    func setStreamedBlocksForTest(_ blocks: [LLMBlock]) {
        self.streamedBlocks = blocks
    }
    func setStreamedBlockIntervalForTest(_ interval: UInt64) {
        self.streamedBlockInterval = interval
    }
}