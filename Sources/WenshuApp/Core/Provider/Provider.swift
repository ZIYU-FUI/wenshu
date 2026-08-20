//
//  Provider.swift · v0.21 ticket 01
//

import Foundation

public enum ProviderAuthMode: String, Sendable {
    case bearer
    case xApiKey
}

public struct Provider: Identifiable, Hashable, Sendable {
    public let slug: String
    public let name: String
    public let defaultBaseURL: String
    public let apiMode: String
    public let authHeader: ProviderAuthMode
    public let requiresOAuth: Bool
    public let defaultModels: [String]

    public var id: String { slug }

    public init(
        slug: String,
        name: String,
        defaultBaseURL: String,
        apiMode: String,
        authHeader: ProviderAuthMode,
        requiresOAuth: Bool = false,
        defaultModels: [String] = []
    ) {
        self.slug = slug
        self.name = name
        self.defaultBaseURL = defaultBaseURL
        self.apiMode = apiMode
        self.authHeader = authHeader
        self.requiresOAuth = requiresOAuth
        self.defaultModels = defaultModels
    }

    public static let openrouter = Provider(
        slug: "openrouter",
        name: "OpenRouter",
        defaultBaseURL: "https://openrouter.ai/api/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["anthropic/claude-opus-4.8", "deepseek/deepseek-v4-pro"]
    )

    public static let nous = Provider(
        slug: "nous",
        name: "Nous Portal",
        defaultBaseURL: "https://inference-api.nousresearch.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["deepseek/deepseek-v4-pro"]
    )

    public static let minimax = Provider(
        slug: "minimax",
        name: "MiniMax",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    )

    public static let minimaxCn = Provider(
        slug: "minimax-cn",
        name: "MiniMax (China)",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    )

    public static let openaiCodex = Provider(
        slug: "openai-codex",
        name: "OpenAI Codex",
        defaultBaseURL: "https://api.openai.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-5", "gpt-5-mini", "o4-mini"]
    )

    public static let copilot = Provider(
        slug: "copilot",
        name: "GitHub Copilot",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"]
    )

    public static let copilotAcp = Provider(
        slug: "copilot-acp",
        name: "GitHub Copilot (ACP)",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"]
    )

    public static let xaiOauth = Provider(
        slug: "xai-oauth",
        name: "xAI (OAuth)",
        defaultBaseURL: "https://api.x.ai/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["grok-3", "grok-3-mini"]
    )

    public static let stepfun = Provider(
        slug: "stepfun",
        name: "StepFun",
        defaultBaseURL: "https://api.stepfun.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["step-3.7-flash"]
    )

    public static let anthropic = Provider(
        slug: "anthropic",
        name: "Anthropic",
        defaultBaseURL: "https://api.anthropic.com",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["claude-opus-4-20250514", "claude-sonnet-4-20250514"]
    )

    public static let custom = Provider(
        slug: "custom",
        name: "自定义",
        defaultBaseURL: "",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: []
    )

    public static let all: [Provider] = [
        .openrouter, .nous, .minimax, .minimaxCn,
        .openaiCodex, .copilot, .copilotAcp, .xaiOauth,
        .stepfun, .anthropic, .custom
    ]

    public static func by(slug: String) -> Provider? {
        all.first { $0.slug == slug }
    }
}
