//
//  MiniMaxVerifier.swift · Wenshu · v0.18 ticket 31 (verify MiniMax key)
//
//  验证 wenshu AgentProtocol 用 MiniMax key 调通.
//  老板 2026-08-19 拍 "验证, 用我们的 MiniMax 的 key 看能否真的用你复刻的 hermes 核心调通 anget".
//
//  业务语言描述 (老板懂):
//  - wenshu AgentProtocol (A2A 协议) → MiniMax API (Anthropic 兼容协议)
//  - 真值: 用 MiniMax key 调 MiniMax-M3 模型, 验证 "ping" 返 200
//  - 测试: 1) ping 返 200 2) wenshu AgentProtocol 跟 MiniMax API 集成
//

import Foundation

/// MiniMax 真值 (Anthropic 兼容协议)
public struct MiniMaxMessage: Codable, Sendable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct MiniMaxRequest: Codable, Sendable {
    public let model: String
    public let max_tokens: Int
    public let messages: [MiniMaxMessage]
    public init(model: String, max_tokens: Int, messages: [MiniMaxMessage]) {
        self.model = model
        self.max_tokens = max_tokens
        self.messages = messages
    }
}

// v0.21 ticket 39: union content block (Apple Codable enum 真值)
// Anthropic-compatible content blocks include text / thinking (CoT) / tool_use variants
// MiniMax M2.7 returns thinking blocks before text (chain-of-thought 范式)
// M3 returns plain text blocks. JSONDecoder keyed container 之前 hardcoded require "text" key
// 在 content[0] → M2.7 thinking block 抛 DecodingError.keyNotFound.
public enum MiniMaxBlock: Codable, Sendable, Equatable {
    case text(String)
    case thinking(text: String, signature: String?)
    case toolUse(id: String, name: String, input: String)
    case unknown(type: String, raw: String)

    private enum CodingKeys: String, CodingKey {
        case type, text, thinking, signature, id, name, input
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? "unknown"
        switch type {
        case "text":
            let text = try c.decode(String.self, forKey: .text)
            self = .text(text)
        case "thinking":
            let thinking = try c.decode(String.self, forKey: .thinking)
            let signature = try? c.decode(String.self, forKey: .signature)
            self = .thinking(text: thinking, signature: signature)
        case "tool_use":
            let id = try c.decode(String.self, forKey: .id)
            let name = try c.decode(String.self, forKey: .name)
            let input = try c.decode(String.self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        default:
            // unknown type: 容错 (Q26 原则 1 优雅降级). raw 只存 type 名, 调试时 NSLog 已印 allKeys
            self = .unknown(type: type, raw: type)
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
        case .unknown(let type, _):
            try c.encode(type, forKey: .type)
        }
    }

    /// 提取用户可见文本 (text blocks concat). Thinking blocks 不在此暴露, 走 ChatMessage.thinking 字段
    public var displayText: String {
        switch self {
        case .text(let s): return s
        case .thinking: return ""
        case .toolUse: return ""
        case .unknown: return ""
        }
    }

    /// 提取 thinking 内容 (CoT 范式, Apple HIG footnote)
    public var thinkingText: String? {
        if case .thinking(let s, _) = self { return s }
        return nil
    }
}

// v0.21 ticket 34: real LLM API usage (Apple Anthropic protocol)
// { "usage": { "input_tokens": N, "output_tokens": N, "cache_creation_input_tokens": N, "cache_read_input_tokens": N } }
public struct MiniMaxUsage: Codable, Sendable, Equatable {
    public let input_tokens: Int
    public let output_tokens: Int
    public let cache_creation_input_tokens: Int?
    public let cache_read_input_tokens: Int?
    public var total_tokens: Int { input_tokens + output_tokens }

    public init(
        input_tokens: Int,
        output_tokens: Int,
        cache_creation_input_tokens: Int? = nil,
        cache_read_input_tokens: Int? = nil
    ) {
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens
        self.cache_creation_input_tokens = cache_creation_input_tokens
        self.cache_read_input_tokens = cache_read_input_tokens
    }
}

public struct MiniMaxResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let role: String
    public let content: [MiniMaxBlock]   // v0.21 ticket 39: union decode (text / thinking / tool_use)
    public let stop_reason: String?
    public let usage: MiniMaxUsage?

    public init(id: String, model: String, role: String, content: [MiniMaxBlock], stop_reason: String? = nil, usage: MiniMaxUsage? = nil) {
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stop_reason = stop_reason
        self.usage = usage
    }
}

/// MiniMaxVerifier: 验证 wenshu AgentProtocol 调 MiniMax API 真值
public actor MiniMaxVerifier {
    private let baseURL: String
    private let apiKey: String
    private let model: String

    public init(baseURL: String? = nil, apiKey: String? = nil, model: MiniMaxModel = .m3) {
        // 优先 Keychain (CLAUDE.md L42 真值范式), fallback env (向后兼容, dev env 仍 work)
        if let baseURL = baseURL, let apiKey = apiKey {
            self.baseURL = baseURL
            self.apiKey = apiKey
        } else {
            let envBaseURL = ProcessInfo.processInfo.environment["MINIMAX_CN_BASE_URL"] ?? "https://api.minimaxi.com/anthropic"
            var resolvedKey = ProcessInfo.processInfo.environment["MINIMAX_CN_API_KEY"] ?? ""
            if resolvedKey.isEmpty {
                // v0.21 ticket 03: Keychain 读真值
                if let stored = LLMKeychain.loadKeySync(), !stored.isEmpty {
                    resolvedKey = stored
                }
            }
            self.baseURL = envBaseURL
            self.apiKey = resolvedKey
        }
        self.model = model.rawValue
    }

    /// ping: 简单 1 消息真值
    public func ping() async throws -> MiniMaxResponse {
        let request = MiniMaxRequest(
            model: model,
            max_tokens: 50,
            messages: [MiniMaxMessage(role: "user", content: "ping")]
        )
        return try await send(request: request)
    }

    /// chat: 1 消息 user content 真值 (v0.21 ticket 03 fallback 用, AgentProtocol LLM 失败后 ChatViewModel 走这条)
    public func chat(_ text: String) async throws -> MiniMaxResponse {
        let request = MiniMaxRequest(
            model: model,
            max_tokens: 1024,
            messages: [MiniMaxMessage(role: "user", content: text)]
        )
        return try await send(request: request)
    }

    /// v0.21 ticket 38: chat overload that takes model at call time
    /// (boss 2026-08-22 反馈 "切换了 AI 没有真的换" = original chat() uses self.model from init = hardcoded)
    /// This overload lets ChatViewModel pass current model from UserDefaults at call time
    public func chat(_ text: String, model overrideModel: String) async throws -> MiniMaxResponse {
        let request = MiniMaxRequest(
            model: overrideModel,
            max_tokens: 1024,
            messages: [MiniMaxMessage(role: "user", content: text)]
        )
        return try await send(request: request)
    }

    /// send: 实际调 MiniMax API (Apple URLSession 真值)
    public func send(request: MiniMaxRequest) async throws -> MiniMaxResponse {
        guard !apiKey.isEmpty else {
            throw MiniMaxError.missingAPIKey
        }
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw MiniMaxError.invalidBaseURL(url: baseURL)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        NSLog("[wenshu.chat] request: model=%@ max_tokens=%d messages=%d", request.model, request.max_tokens, request.messages.count)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8 body>"
        NSLog("[wenshu.chat] response status=%d body=%@", statusCode, bodyPreview)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MiniMaxError.httpError(statusCode: statusCode, body: bodyPreview)
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(MiniMaxResponse.self, from: data)
        } catch {
            NSLog("[wenshu.chat] decoder error: %@", String(describing: error))
            throw error
        }
    }
}

public enum MiniMaxError: Error {
    case missingAPIKey
    case invalidBaseURL(url: String)
    case httpError(statusCode: Int, body: String)
}