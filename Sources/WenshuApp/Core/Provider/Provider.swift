// Provider.swift

import Foundation

enum ProviderAuthMode: String, Sendable {
    case bearer
    case xApiKey
}

struct Provider: Identifiable, Hashable, Sendable {
    let slug: String
    let name: String
    let defaultBaseURL: String
    let apiMode: String
    let authHeader: ProviderAuthMode
    let requiresOAuth: Bool
    let defaultModels: [String]

    var id: String { slug }

    init(
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

    static let openrouter = Provider(
        slug: "openrouter",
        name: "OpenRouter",
        defaultBaseURL: "https://openrouter.ai/api/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["anthropic/claude-opus-4.8", "deepseek/deepseek-v4-pro"]
    )

    static let nous = Provider(
        slug: "nous",
        name: "Nous Portal",
        defaultBaseURL: "https://inference-api.nousresearch.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["deepseek/deepseek-v4-pro"]
    )

    static let minimax = Provider(
        slug: "minimax",
        name: "MiniMax",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    )

    static let minimaxCn = Provider(
        slug: "minimax-cn",
        name: "MiniMax (China)",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["MiniMax-M3", "MiniMax-M2", "MiniMax-Reasoning"]
    )

    static let openaiCodex = Provider(
        slug: "openai-codex",
        name: "OpenAI Codex",
        defaultBaseURL: "https://api.openai.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-5", "gpt-5-mini", "o4-mini"]
    )

    static let copilot = Provider(
        slug: "copilot",
        name: "GitHub Copilot",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"]
    )

    static let copilotAcp = Provider(
        slug: "copilot-acp",
        name: "GitHub Copilot (ACP)",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"]
    )

    static let xaiOauth = Provider(
        slug: "xai-oauth",
        name: "xAI (OAuth)",
        defaultBaseURL: "https://api.x.ai/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["grok-3", "grok-3-mini"]
    )

    static let stepfun = Provider(
        slug: "stepfun",
        name: "StepFun",
        defaultBaseURL: "https://api.stepfun.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["step-3.7-flash"]
    )

    static let anthropic = Provider(
        slug: "anthropic",
        name: "Anthropic",
        defaultBaseURL: "https://api.anthropic.com",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["claude-opus-4-20250514", "claude-sonnet-4-20250514", "claude-3-5-sonnet-20241022"]
    )

    static let custom = Provider(
        slug: "custom",
        name: "自定义",
        defaultBaseURL: "",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: []
    )

    // sub-step 2 (= hermes-core-translation spec §3.2):
    // 3 new connector profiles added per AGENTS.md §11.2 (P1/P1/P1).
    // Other 4 (= Anthropic / OpenAI / minimax cn / OpenRouter) were
    // already present in the existing wenshu `Provider` enum.

    static let gemini = Provider(
        slug: "gemini",
        name: "Gemini",
        defaultBaseURL: "https://generativelanguage.googleapis.com/v1beta",
        apiMode: "google_genai",
        authHeader: .bearer,
        defaultModels: ["gemini-2.5-pro", "gemini-2.5-flash"]
    )

    static let deepseek = Provider(
        slug: "deepseek",
        name: "DeepSeek",
        defaultBaseURL: "https://api.deepseek.com/v1",
        apiMode: "anthropic_messages",
        authHeader: .bearer,
        defaultModels: ["deepseek-chat", "deepseek-reasoner"]
    )

    static let ollama = Provider(
        slug: "ollama",
        name: "Ollama (local)",
        defaultBaseURL: "http://localhost:11434/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["llama3.3", "mistral"]
    )

    static let all: [Provider] = [
        .openrouter, .nous, .minimax, .minimaxCn,
        .openaiCodex, .copilot, .copilotAcp, .xaiOauth,
        .stepfun, .anthropic, .custom,
        // sub-step 2 additions
        .gemini, .deepseek, .ollama
    ]

    static func by(slug: String) -> Provider? {
        all.first { $0.slug == slug }
    }
}
