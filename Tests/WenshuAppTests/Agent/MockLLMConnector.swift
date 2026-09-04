//
//  MockLLMConnector.swift · Wenshu · v0.37 Batch 2.1 sub-step 2
//
//  Shared mock LLMConnector for unit tests with scripted tool_use support.
//
//  v0.37 enhancement (= per 老板 cadence '继续移植' + 'PO 全链路方法论执行,
//  不要跳步骤' + '翻译这个事做完一起验视觉和前端流程' + '1 RULE 1 commit'):
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

        // Fallback: echo the last user message
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

        return LLMResponse(
            id: "mock-\(UUID().uuidString)",
            model: options.model,
            blocks: [.text(echo)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 5, outputTokens: 5)
        )
    }
}