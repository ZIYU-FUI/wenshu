//
//  ConversationLoopStreamingTests.swift · Wenshu · T14-CONVLOOP-STREAMING (2026-09-18)
//
//  Verifies that ConversationLoop.runConversation + runTurn actually
//  use connector.stream() (= not connector.send()). Strategy:
//  set MockLLMConnector.streamedBlocks to a scripted sequence and
//  assert that stream(...) is called (= streamedMessages recorded)
//  and that send(...) is NOT called (= receivedMessages empty).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ConversationLoop streaming (T14)")
struct ConversationLoopStreamingTests {

    /// Helper: build a ConversationLoop with a mock connector + the
    /// default RuntimeHelpers. Returns the loop + the mock so tests
    /// can inspect side effects.
    private func makeLoop() async throws -> (ConversationLoop, MockLLMConnector) {
        let mock = MockLLMConnector()
        let loop = await ConversationLoop(
            connection: mock,
            systemPrompt: nil,
            runtime: RuntimeHelpers(),
            shellHookChain: ShellHookChain(),
            conversationCompression: ConversationCompression(),
            progressTracker: .noop
        )
        return (loop, mock)
    }

    /// Build a `streamCallback` that writes yielded blocks into a
    /// thread-safe array (= the BlockCollector class below), and
    /// return a snapshot reader.
    private func makeCollector() -> (
        callback: @Sendable (LLMBlock) async -> Void,
        snapshot: @Sendable () async -> [LLMBlock]
    ) {
        let collector = BlockCollector()
        let callback: @Sendable (LLMBlock) async -> Void = { block in
            await collector.append(block)
        }
        let snapshot: @Sendable () async -> [LLMBlock] = {
            await collector.snapshot()
        }
        return (callback, snapshot)
    }

    @Test func runConversation_calls_stream_not_send() async throws {
        let (loop, mock) = try await makeLoop()
        await mock.setStreamedBlocksForTest([.text("hello from stream")])
        let (callback, snapshot) = makeCollector()
        _ = try? await loop.runConversation(
            userMessage: "hi",
            systemMessage: nil,
            conversationHistory: [],
            streamCallback: callback
        )
        let collected = await snapshot()
        // 1. stream() was called (= not send()).
        let streamedMessages = await mock.streamedMessages
        let sendMessages = await mock.receivedMessages
        #expect(streamedMessages.count == 1, "expected 1 stream call, got \(streamedMessages.count)")
        #expect(sendMessages.isEmpty, "expected 0 send calls, got \(sendMessages.count)")
        // 2. streamCallback was forwarded the .text block.
        #expect(collected.contains(where: { block in
            if case .text(let s) = block { return s == "hello from stream" }
            return false
        }), "expected 'hello from stream' in collected blocks")
    }

    @Test func runConversation_emits_each_streamed_block() async throws {
        let (loop, mock) = try await makeLoop()
        await mock.setStreamedBlocksForTest([
            .thinking(text: "let me think", signature: nil),
            .text("first "),
            .text("second "),
            .text("third")
        ])
        let (callback, snapshot) = makeCollector()
        _ = try? await loop.runConversation(
            userMessage: "test",
            systemMessage: nil,
            conversationHistory: [],
            streamCallback: callback
        )
        let collected = await snapshot()
        // All 4 blocks should appear in the collected output (= streamCallback
        // fires per-block, not after-the-fact like the old send() + for-loop).
        #expect(collected.count == 4)
        if case .thinking(let t, _) = collected[0] { #expect(t == "let me think") }
        if case .text(let s) = collected[1] { #expect(s == "first ") }
        if case .text(let s) = collected[2] { #expect(s == "second ") }
        if case .text(let s) = collected[3] { #expect(s == "third") }
    }

    @Test func runTurn_uses_stream_on_reprompt() async throws {
        let (loop, mock) = try await makeLoop()
        // Scripted responses:
        //   1st stream(): .toolUse -> triggers tool dispatch + re-prompt
        //   2nd stream(): .text("done")
        await mock.setScriptedResponsesForTest([
            LLMResponse(
                id: "r1", model: "m",
                blocks: [
                    .text("Calling tool..."),
                    .toolUse(id: "t1", name: "ReadFile", input: "{\"path\":\"/tmp/x\"}")
                ],
                stopReason: .toolUse,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            ),
            LLMResponse(
                id: "r2", model: "m",
                blocks: [.text("Read complete.")],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 0, outputTokens: 0)
            )
        ])
        // Provide a stub tool so executeSequential can find it.
        let stubTool = StubTool(name: "ReadFile", output: "file content")
        let tools: [String: any Tool] = ["ReadFile": stubTool]
        let (callback, snapshot) = makeCollector()
        _ = try? await loop.runTurn(
            userMessage: "read /tmp/x",
            systemMessage: nil,
            conversationHistory: [],
            tools: tools,
            streamCallback: callback
        )
        let collected = await snapshot()
        // stream() should have been called at least twice (1st LLM + re-prompt).
        let streamedMessages = await mock.streamedMessages
        #expect(streamedMessages.count >= 2, "expected >= 2 stream calls (= 1st + re-prompt), got \(streamedMessages.count)")
        // send() should NOT have been called at all.
        let sendMessages = await mock.receivedMessages
        #expect(sendMessages.isEmpty, "expected 0 send calls, got \(sendMessages.count)")
        // Final text block should appear.
        #expect(collected.contains(where: { block in
            if case .text(let s) = block { return s == "Read complete." }
            return false
        }), "expected 'Read complete.' in collected blocks")
    }
}

// MARK: - Helpers

/// Thread-safe block collector. Tests call `append(_:)` from the
/// streamCallback and `snapshot()` to read the array. Backed by an
/// actor so concurrent appends are serialized.
actor BlockCollector {
    private var blocks: [LLMBlock] = []
    func append(_ block: LLMBlock) {
        blocks.append(block)
    }
    func snapshot() -> [LLMBlock] {
        return blocks
    }
}

/// Minimal stub Tool (= the loop's tool dispatch path needs something
/// to call; = this stub always returns a fixed output string).
struct StubTool: Tool {
    let name: String
    let output: String
    func execute(input: String) async throws -> String {
        return output
    }
}

extension MockLLMConnector {
    func setScriptedResponsesForTest(_ responses: [LLMResponse]) {
        self.scriptedResponses = responses
    }
}