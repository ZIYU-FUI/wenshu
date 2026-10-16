//
//  WenshuLLMTypes.swift · Wenshu · v0.35 ticket 001 (preserved types)
//
//  AUDIT.md §2.6 partial (2026-10-16 boss "清老代码必须
//  做完" arc): these 5 types (WenshuLLMMessage /
//  WenshuLLMRequest / WenshuLLMBlock / WenshuLLMUsage /
//  WenshuLLMResponse) were originally defined inline in
//  WenshuVerifier.swift. They are now extracted here
//  because the WenshuVerifier actor (= the legacy LLM
//  probe) is being deleted, but these types are still
//  consumed by:
//   - `AgentProtocol.handleMessageSend` (= the A2A
//     protocol adapter's verifier field; = uses
//     `WenshuLLMResponse` for the reply union).
//   - `WenshuVerifierTests` (= legacy tests; = slated
//     for deletion in this same arc).
// Future tickets: once AgentProtocol migrates to use
// `WenshuConductor` (= the canonical LLM entry point)
// instead of WenshuVerifier, these types can be deleted
// along with the AgentProtocol verifier field.
//

import Foundation

/// WenshuLLMMessage: a single chat message (= role + content)
/// in the Anthropic-compatible wire format (= the format
/// WenshuVerifier.send uses to talk to the minimax-cn
/// endpoint).
public struct WenshuLLMMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// WenshuLLMRequest: the request envelope for the
/// minimax-cn API (= model + max_tokens + messages).
public struct WenshuLLMRequest: Codable, Sendable {
    public let model: String
    public let max_tokens: Int
    public let messages: [WenshuLLMMessage]

    public init(model: String, max_tokens: Int, messages: [WenshuLLMMessage]) {
        self.model = model
        self.max_tokens = max_tokens
        self.messages = messages
    }
}

// union content block (Apple Codable enum ground truth)
// Anthropic-compatible content blocks include text / thinking (CoT) / tool_use variants

// minimax-cn M2.7 returns thinking blocks before text (chain-of-thought pattern)
// returns plain text blocks. JSONDecoder keyed container used to hardcode-require "text" key
// in content[0] → M2.7 thinking block throws DecodingError.keyNotFound.
public enum WenshuLLMBlock: Codable, Sendable, Equatable {
    case text(String)
    case thinking(text: String, signature: String?)
    case toolUse(id: String, name: String, input: String)
    case unknown(type: String, raw: String)

    /// Legacy accessor (= used by ConversationOps + AgentProtocol; =
    /// returns the human-readable text representation of the block).
    /// .text(s) → s; .thinking(s, _) → s; .toolUse / .unknown → "".
    public var displayText: String {
        switch self {
        case .text(let s): return s
        case .thinking(let s, _): return s
        case .toolUse: return ""
        case .unknown: return ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case thinking
        case signature
        case id
        case name
        case input
        case raw
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let s = try c.decode(String.self, forKey: .text)
            self = .text(s)
        case "thinking":
            let s = try c.decode(String.self, forKey: .thinking)
            let sig = try c.decodeIfPresent(String.self, forKey: .signature)
            self = .thinking(text: s, signature: sig)
        case "tool_use":
            let id = try c.decode(String.self, forKey: .id)
            let name = try c.decode(String.self, forKey: .name)
            let input = try c.decode(String.self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        default:
            let raw = try c.decodeIfPresent(String.self, forKey: .raw) ?? ""
            self = .unknown(type: type, raw: raw)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .text)
        case .thinking(let s, let sig):
            try c.encode("thinking", forKey: .type)
            try c.encode(s, forKey: .thinking)
            try c.encodeIfPresent(sig, forKey: .signature)
        case .toolUse(let id, let name, let input):
            try c.encode("tool_use", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(input, forKey: .input)
        case .unknown(let type, let raw):
            try c.encode(type, forKey: .type)
            try c.encodeIfPresent(raw, forKey: .raw)
        }
    }
}

public struct WenshuLLMUsage: Codable, Sendable, Equatable {
    public let input_tokens: Int
    public let output_tokens: Int
    public let cache_creation_input_tokens: Int?
    public let cache_read_input_tokens: Int?

    public init(input_tokens: Int, output_tokens: Int, cache_creation_input_tokens: Int? = nil, cache_read_input_tokens: Int? = nil) {
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens
        self.cache_creation_input_tokens = cache_creation_input_tokens
        self.cache_read_input_tokens = cache_read_input_tokens
    }
}

public struct WenshuLLMResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let role: String
    public let content: [WenshuLLMBlock]   // union decode (text / thinking / tool_use)
    public let stop_reason: String?
    public let usage: WenshuLLMUsage?

    public init(id: String, model: String, role: String, content: [WenshuLLMBlock], stop_reason: String? = nil, usage: WenshuLLMUsage? = nil) {
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stop_reason = stop_reason
        self.usage = usage
    }
}
