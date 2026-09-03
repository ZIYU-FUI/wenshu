//
//  MockLLMConnector.swift · Wenshu · v0.36 ship packet
//
//  Shared mock LLMConnector for unit tests (= LLMConnectorTests +
//  ConversationLoopTests + ContextEngineTests etc).
//
//  v0.36 fix (= per 老板 cadence 'fix pre-existing test files'):
//  MockLLMConnector was defined as private in LLMConnectorTests.swift,
//  breaking 6+ call sites in ConversationLoopTests.swift + ContextEngine*.
//  Promoted to a shared test helper file in WenshuAppTests target.
//
//  Usage:
//    let mock = MockLLMConnector(response: "echo: hi")
//    let response = try await mock.send(messages: [...], options: ...)
//

import Foundation
@testable import WenshuApp

/// Echo-style mock connector for tests. Returns the configured response
/// text (= echoes the last user message by default).
public actor MockLLMConnector: LLMConnector {
    nonisolated public let connectorID: String = "mock"

    public var responseText: String
    public var receivedMessages: [LLMMessage] = []
    public var receivedOptions: LLMCallOptions?

    public init(response: String = "ok") {
        self.responseText = response
    }

    public func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        receivedMessages = messages
        receivedOptions = options

        // Echo the last user message if it looks like one
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