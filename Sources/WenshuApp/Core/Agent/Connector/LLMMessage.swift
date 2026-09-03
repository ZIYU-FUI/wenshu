//
//  LLMMessage.swift · Wenshu · v0.35 ticket 001 sub-step 2
//
//  Cross-connector message type (= LLMConnector protocol surface).
//  Maps 1:1 to hermes' `api_messages` list (= see hermes
//  conversation_loop.py L523-L546 for the canonical shape).
//
//  3 roles:
//    - .user: human input
//    - .assistant: model output (= text / thinking / tool_use blocks)
//    - .tool: tool execution result
//
//  Content blocks (= Anthropic Messages API content blocks pattern):
//    - .text(String) — plain text
//    - .thinking(text:signature:) — extended thinking / CoT
//    - .toolUse(id:name:input:) — tool invocation request
//    - .toolResult(toolUseID:output:) — tool execution result (= maps to
//      Anthropic tool_result block)
//
//  This type is the canonical Swift representation. Each connector
//  (= OpenAICompatibleConnector / AnthropicConnector / etc.) maps this
//  to its wire format on send, and reverse-maps on receive.
//
//  v0.35 sub-step 2 of 8 for ticket 001.
//

import Foundation

public struct LLMMessage: Sendable, Equatable {
    public let role: Role
    public let content: Content

    public init(role: Role, content: Content) {
        self.role = role
        self.content = content
    }

    public enum Role: String, Sendable, Codable, Equatable {
        case user
        case assistant
        case tool
    }

    public enum Content: Sendable, Equatable {
        case text(String)
        case thinking(text: String, signature: String?)
        case toolUse(id: String, name: String, input: String)
        case toolResult(toolUseID: String, output: String)
        case blocks([Content])  // multi-block content (= Anthropic-style)
    }
}