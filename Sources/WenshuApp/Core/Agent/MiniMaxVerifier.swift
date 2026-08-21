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

public struct MiniMaxContent: Codable, Sendable {
    public let text: String
    public let type: String
    public init(text: String, type: String = "text") {
        self.text = text
        self.type = type
    }
}

// v0.21 ticket 34: real LLM API usage (Apple Anthropic protocol)
// { "usage": { "input_tokens": N, "output_tokens": N } } — total_tokens derived
public struct MiniMaxUsage: Codable, Sendable, Equatable {
    public let input_tokens: Int
    public let output_tokens: Int
    public var total_tokens: Int { input_tokens + output_tokens }

    public init(input_tokens: Int, output_tokens: Int) {
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens
    }
}

public struct MiniMaxResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let role: String
    public let content: [MiniMaxContent]
    public let stop_reason: String?
    public let usage: MiniMaxUsage?    // v0.21 ticket 34: real token count from LLM API

    public init(id: String, model: String, role: String, content: [MiniMaxContent], stop_reason: String? = nil, usage: MiniMaxUsage? = nil) {
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
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw MiniMaxError.httpError(statusCode: statusCode, body: body)
        }
        let decoder = JSONDecoder()
        return try decoder.decode(MiniMaxResponse.self, from: data)
    }
}

public enum MiniMaxError: Error {
    case missingAPIKey
    case invalidBaseURL(url: String)
    case httpError(statusCode: Int, body: String)
}