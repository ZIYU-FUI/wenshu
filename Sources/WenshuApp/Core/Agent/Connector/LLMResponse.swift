// LLMResponse.swift · WenshuApp · v0.35
//
// Cross-connector response type (= `LLMConnector.send` return value).
// Mirrors hermes' `Dict[str, Any]` return shape from
// `conversation_loop.run_conversation` (= final response + message
// history).
//
// Shape:
//   - `id`: provider-assigned response id (= for tracing + retries)
//   - `model`: the model that produced the response (= for billing
//     + cache log)
//   - `blocks`: list of content blocks (= text / thinking / tool_use)
//   - `stopReason`: why the model stopped (= end_turn / tool_use /
//     max_tokens)
//   - `usage`: token counts (= input + output)

import Foundation

struct LLMResponse: Sendable, Equatable {
    let id: String
    let model: String
    let blocks: [LLMBlock]
    let stopReason: StopReason
    let usage: LLMUsage

    init(
        id: String,
        model: String,
        blocks: [LLMBlock],
        stopReason: StopReason,
        usage: LLMUsage
    ) {
        self.id = id
        self.model = model
        self.blocks = blocks
        self.stopReason = stopReason
        self.usage = usage
    }

    enum StopReason: String, Sendable, Equatable, Codable {
        case endTurn = "end_turn"
        case toolUse = "tool_use"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case unknown
    }
}

struct LLMUsage: Sendable, Equatable {
    let inputTokens: Int
    let outputTokens: Int

    init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    var totalTokens: Int { inputTokens + outputTokens }
}

/// Cross-connector content block (= used by both LLMResponse.blocks and
/// LLMConnector streaming callbacks). 4 variants per Anthropic Messages
/// API content blocks pattern: text / thinking / tool_use / tool_result.
enum LLMBlock: Sendable, Equatable {
    case text(String)
    case thinking(text: String, signature: String?)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseID: String, output: String)

    /// Canonical JSON representation for each block case.
    /// Replaces the case .text / .toolUse / .toolResult switch repeated
    /// in 5+ connector / tool files (= Standards-axis S5 Repeated
    /// Switches smell). Polymorphic dispatch via Dictionary subscript.
    var asJSONObject: [String: Any] {
        switch self {
            case let .text(s):
                return ["type": "text", "text": s]
            case let .thinking(text, signature):
                var dict: [String: Any] = ["type": "thinking", "thinking": text]
                if let signature { dict["signature"] = signature }
                return dict
            case let .toolUse(id, name, input):
                return ["type": "tool_use", "id": id, "name": name, "input": input]
            case let .toolResult(toolUseID, output):
                return ["type": "tool_result", "tool_use_id": toolUseID, "output": output]
        }
    }

    /// Extract text content for display (= concatenation across text cases).
    /// Replaces case .text { $0 } / case .thinking { $0.text } etc. in
    /// 5+ files. Used by ChatMessageBridge.textContent + display paths.
    var textValue: String {
        switch self {
            case let .text(s): return s
            case let .thinking(text, _): return text
            case let .toolUse(_, _, input): return input
            case let .toolResult(_, output): return output
        }
    }
}
