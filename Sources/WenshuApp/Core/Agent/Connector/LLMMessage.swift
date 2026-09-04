//
//  LLMMessage.swift · Wenshu · v0.35 ticket 001 sub-step 3
//
//  Cross-connector message type (= LLMConnector protocol surface).
//  Maps 1:1 to hermes' `api_messages` list (= see hermes
//  conversation_loop.py L523-L546 for the canonical shape).
//
//  3 roles:
//    - .user: human input
//    - .assistant: model output (= text / thinking / tool_use blocks)
//    - .tool: tool execution result (= tool_result blocks)
//
//  Message body is `blocks: [LLMBlock]` (= shared cross-connector block
//  type defined in LLMResponse.swift). Each connector (= OpenAICompatible,
//  Anthropic, Gemini, etc.) maps the block list to its wire format on send,
//  and reverse-maps on receive.
//
//  v0.35 sub-step 3 of 8 for ticket 001 (= TB-B tracer-bullet).
//

import Foundation

public struct LLMMessage: Sendable, Equatable {
    public let role: Role
    public let blocks: [LLMBlock]
    public var cacheControl: [String: String]?

    public init(role: Role, blocks: [LLMBlock], cacheControl: [String: String]? = nil) {
        self.role = role
        self.blocks = blocks
        self.cacheControl = cacheControl
    }

    public enum Role: String, Sendable, Codable, Equatable {
        case user
        case assistant
        case tool
    }

    // MARK: - Convenience initializers

    /// Build a single-text user message.
    public static func user(_ text: String) -> LLMMessage {
        LLMMessage(role: .user, blocks: [.text(text)])
    }

    /// Build a single-text assistant message.
    public static func assistant(_ text: String) -> LLMMessage {
        LLMMessage(role: .assistant, blocks: [.text(text)])
    }

    /// Build a tool result message.
    public static func toolResult(toolUseID: String, output: String) -> LLMMessage {
        LLMMessage(role: .tool, blocks: [.toolResult(toolUseID: toolUseID, output: output)])
    }

    /// Extract plain text from message blocks (= convenience for callers
    /// that don't need to inspect thinking / tool_use separately).
    public var plainText: String {
        blocks.compactMap { block in
            if case .text(let s) = block { return s } else { return nil }
        }.joined(separator: "")
    }
}