//
//  LLMResponse.swift · Wenshu · v0.35 ticket 001 sub-step 2
//
//  Cross-connector response type (= LLMConnector.send return value).
//  Mirrors hermes' `Dict[str, Any]` return shape from
//  conversation_loop.run_conversation (= final response + message history).
//
//  Shape:
//    - id: provider-assigned response id (= for tracing + retries)
//    - model: the model that produced the response (= for billing + cache log)
//    - blocks: list of content blocks (= text / thinking / tool_use)
//    - stopReason: why the model stopped (= end_turn / tool_use / max_tokens)
//    - usage: token counts (= input + output)
//
//  v0.35 sub-step 2 of 8 for ticket 001.
//

import Foundation

public struct LLMResponse: Sendable, Equatable {
    public let id: String
    public let model: String
    public let blocks: [Block]
    public let stopReason: StopReason
    public let usage: LLMUsage

    public init(
        id: String,
        model: String,
        blocks: [Block],
        stopReason: StopReason,
        usage: LLMUsage
    ) {
        self.id = id
        self.model = model
        self.blocks = blocks
        self.stopReason = stopReason
        self.usage = usage
    }

    public enum Block: Sendable, Equatable {
        case text(String)
        case thinking(text: String, signature: String?)
        case toolUse(id: String, name: String, input: String)
    }

    public enum StopReason: String, Sendable, Equatable, Codable {
        case endTurn = "end_turn"
        case toolUse = "tool_use"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case unknown
    }
}

public struct LLMUsage: Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int { inputTokens + outputTokens }
}