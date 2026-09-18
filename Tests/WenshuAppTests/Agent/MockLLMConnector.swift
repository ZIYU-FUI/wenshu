//
//  MockLLMConnector.swift · Wenshu · v0.37 Batch 2.1 sub-step 2
//
//  Shared mock LLMConnector for unit tests with scripted tool_use support.
//
// v0.37 enhancement (= per cadence 'resume' + 'PO execute,
// don't' + 'when done, verify visual and frontend flow together' + '1 RULE 1 commit'):
//  MockLLMConnector now supports scripted responses that emit tool_use
//  blocks. The v0.36 version only echoed text. The v0.37 version supports:
//
//  1. Echo response (default) — echoes the last user message
//  2. Scripted response — returns a configured sequence of LLMResponses,
//     each containing the next LLMBlock (= text, thinking, toolUse,
//     toolResult). Used by ticket 018 sub-step 3 real agent dispatch tests.
//  3. Tool dispatch — when a toolUse block is received, the mock can
//     be configured to call ToolExecutor inline and append toolResults
//     before returning the final response.
//
//  Usage:
//    // Echo mode
//    let mock = MockLLMConnector(response: "echo: hi")
//    let response = try await mock.send(messages: [...], options: ...)
//
//    // Scripted tool_use mode
//    let mock = MockLLMConnector(scriptedResponses: [
//        LLMResponse(id: "1", model: "test", blocks: [
//            .toolUse(id: "t1", name: "ReadFile",
//                     input: "{\"path\":\"/tmp/test.md\"}")
//        ], stopReason: .toolUse, usage: LLMUsage(inputTokens: 0, outputTokens: 0)),
//        LLMResponse(id: "2", model: "test", blocks: [
//            .text("Read complete.")
//        ], stopReason: .endTurn, usage: LLMUsage(inputTokens: 0, outputTokens: 0))
//    ])
//    // First .send() returns response 1, second .send() returns response 2
//

import Foundation
@testable import WenshuApp

/// Echo + scripted-response mock connector for tests.
public actor MockLLMConnector: LLMConnector {
    nonisolated public let connectorID: String = "mock"

    /// Default echo response text.
    public var responseText: String

    /// Scripted responses (= consumed in order; if empty, falls back to echo).
    public var scriptedResponses: [LLMResponse]

    /// All received messages across all .send() calls.
    public var receivedMessages: [LLMMessage] = []

    /// All received options across all .send() calls.
    public var receivedOptions: [LLMCallOptions] = []

    /// Index of next scripted response to return.
    private var scriptedIndex: Int = 0

    public init(
        response: String = "ok",
        scriptedResponses: [LLMResponse] = []
    ) {
        self.responseText = response
        self.scriptedResponses = scriptedResponses
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages.append(contentsOf: messages)
        receivedOptions.append(options)

        // If scripted responses are available, return next one
        if scriptedIndex < scriptedResponses.count {
            let response = scriptedResponses[scriptedIndex]
            scriptedIndex += 1
            return response
        }

        // If a non-default response was configured, return it verbatim
        // (no echo prefix). The default is "ok" (= the echo sentinel).
        if responseText != "ok" {
            return LLMResponse(
                id: "mock-\(UUID().uuidString)",
                model: options.model,
                blocks: [.text(responseText)],
                stopReason: .endTurn,
                usage: LLMUsage(inputTokens: 5, outputTokens: 5)
            )
        }

        // Fallback: echo the last user message (= "ok" default).
        let echo: String
        if case let last = messages.last, let block = last?.blocks.first {
            if case .text(let s) = block {
                echo = "echo: \(s)"
            } else {
                echo = responseText
            }
        } else {
            echo = responseText
        }

        // Default echo path uses the stable id "mock" (= the
        // connectorID bare id) so tests asserting
        // `result.response.id == "mock"` on the default constructor
        // see a deterministic value. Scripted + non-default-response
        // paths keep their "mock-<UUID>" uniqueness.
        return LLMResponse(
            id: "mock",
            model: options.model,
            blocks: [.text(echo)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 5, outputTokens: 5)
        )
    }

    // MARK: - T13 streaming support (= Mock stream() override)

    /// Per-call streaming yield configuration. Default = yield each
    /// block of the next scripted response back-to-back with no delay.
    /// Override via `streamedBlockInterval` (= nanoseconds between
    /// yields) to simulate network latency in tests.
    public var streamedBlockInterval: UInt64 = 0

    /// Recorded stream() calls (= mirror of `receivedMessages` /
    /// `receivedOptions` but for the streaming entry point).
    public var streamedMessages: [[LLMMessage]] = []
    public var streamedOptions: [LLMCallOptions] = []

    /// If non-empty, return this fixed block sequence on every stream()
    /// call (= simpler than per-call scripted responses for streaming
    /// tests; = does not consume `scriptedIndex`).
    public var streamedBlocks: [LLMBlock] = []

    /// T13-MOCK-STREAM-CONNECTOR (2026-09-18): implements LLMConnector's
    /// `stream(...)` default override (= the default extension in T7
    /// would call `send()` and yield blocks once at end; = this
    /// override yields them one-by-one so tests can assert per-block
    /// ordering + intermediate state).
    ///
    /// Yield strategy:
    ///   1. If `streamedBlocks` is set (= explicit per-call override),
    ///      yield each block in order with `streamedBlockInterval`
    ///      nanoseconds between yields (= simulate network latency).
    ///   2. Else if scriptedResponses has a next entry, yield each
    ///      block of that response (= mirrors `send()` but as a stream).
    ///   3. Else echo path (= one .text block with "echo: ...").
    public nonisolated func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                await self.recordStreamCall(messages: messages, options: options)
                let blocks = await self.nextStreamedBlocks(
                    messages: messages, options: options
                )
                for block in blocks {
                    if await self.streamedBlockInterval > 0 {
                        let interval = await self.streamedBlockInterval
                        try? await Task.sleep(nanoseconds: interval)
                    }
                    continuation.yield(block)
                }
                continuation.finish()
            }
        }
    }

    private func recordStreamCall(messages: [LLMMessage], options: LLMCallOptions) {
        streamedMessages.append(messages)
        streamedOptions.append(options)
    }

    /// Snapshot of the next batch of blocks to yield. Captures
    /// `scriptedIndex` advancement as a side effect (= same semantics
    /// as `send()` advancing the index on consumption).
    private func nextStreamedBlocks(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> [LLMBlock] {
        // Explicit per-call override wins.
        if !streamedBlocks.isEmpty {
            return streamedBlocks
        }
        // Scripted response path (= consume the index like send() does).
        if scriptedIndex < scriptedResponses.count {
            let response = scriptedResponses[scriptedIndex]
            scriptedIndex += 1
            return response.blocks
        }
        // Custom response text path (= single .text block).
        if responseText != "ok" {
            return [.text(responseText)]
        }
        // Default echo path.
        let echo: String
        if case let last = messages.last, let block = last?.blocks.first {
            if case .text(let s) = block {
                echo = "echo: \(s)"
            } else {
                echo = responseText
            }
        } else {
            echo = responseText
        }
        return [.text(echo)]
    }
}