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
    // Per boss 2026-10-16 OOB "maxmini 的上下文是 1mb,
    // 我们的每个模型的上下文限制, 有没有根据不用的提供
    // 商进行配置": the canonical context window (= total
    // input + output tokens) for this provider's default
    // models. Sourced from the provider's published docs
    // (= the conservative published number; = the user's
    // Settings can override per (provider × model) via
    // `ContextWindowOverride`).
    //
    // Why a single `Int` not a per-model dictionary: the
    // model selection happens AFTER the provider is fixed
    // (= the chat UI asks for one provider at a time); =
    // the per-(provider × model) overrides live in
    // UserDefaults keyed by "<provider-slug>::<model-slug>".
    // The per-model default can be looked up via
    // `ContextWindowCatalog.defaultTokens(forModel:provider:)`
    // when the override is missing.
    let defaultContextWindowTokens: Int

    var id: String { slug }

    init(
        slug: String,
        name: String,
        defaultBaseURL: String,
        apiMode: String,
        authHeader: ProviderAuthMode,
        requiresOAuth: Bool = false,
        defaultModels: [String] = [],
        defaultContextWindowTokens: Int = 32_000
    ) {
        self.slug = slug
        self.name = name
        self.defaultBaseURL = defaultBaseURL
        self.apiMode = apiMode
        self.authHeader = authHeader
        self.requiresOAuth = requiresOAuth
        self.defaultModels = defaultModels
        self.defaultContextWindowTokens = defaultContextWindowTokens
    }

    static let openrouter = Provider(
        slug: "openrouter",
        name: "OpenRouter",
        defaultBaseURL: "https://openrouter.ai/api/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["anthropic/claude-opus-4.8", "deepseek/deepseek-v4-pro"],
        // OpenRouter is an aggregator; = the real
        // context window is the underlying model's. The
        // user can override per (provider × model) in
        // Settings. Conservative default = the most
        // common public value (200K) for the default
        // model list.
        defaultContextWindowTokens: 200_000
    )

    static let nous = Provider(
        slug: "nous",
        name: "Nous Portal",
        defaultBaseURL: "https://inference-api.nousresearch.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["deepseek/deepseek-v4-pro"],
        // Nous Portal is also an aggregator; = conservative
        // 32K default (= updated per Settings override).
        defaultContextWindowTokens: 32_000
    )

    static let minimax = Provider(
        slug: "minimax",
        name: "MiniMax",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        // Sourced from platform.minimax.io docs
        // (= 2026-10-16 read of the official
        // anthropic-compatible API table). MiniMax-M3
        // supports a 1,000,000-token context window
        // (= 1M); = the user-reported "1mb" =
        // MiniMax-M3 at the international endpoint.
        // The per-model override via Settings
        // (= Settings → Providers → 上下文管理) can
        // narrow to 204,800 for MiniMax-M2.x models.
        //
        // The `MiniMax-Reasoning` alias (= an
        // older model id) is kept for backward
        // compatibility (= the live `/models`
        // endpoint will surface the canonical
        // 1.0+ id; = the picker replaces this list
        // with the live list when the endpoint
        // answers).
        defaultModels: ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.5", "MiniMax-M2", "MiniMax-Reasoning"],
        defaultContextWindowTokens: 1_000_000
    )

    static let minimaxCn = Provider(
        slug: "minimax-cn",
        name: "MiniMax (China)",
        defaultBaseURL: "https://api.minimaxi.com/anthropic",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        // Per platform.minimaxi.com (China endpoint),
        // the supported models + context windows are
        // identical to the international endpoint (= see
        // `minimax` above; = the API contract is the
        // same on both domains; = the per-model
        // defaults can be overridden in Settings).
        defaultModels: ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.5", "MiniMax-M2", "MiniMax-Reasoning"],
        defaultContextWindowTokens: 1_000_000
    )

    static let openaiCodex = Provider(
        slug: "openai-codex",
        name: "OpenAI Codex",
        defaultBaseURL: "https://api.openai.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-5", "gpt-5-mini", "o4-mini"],
        // OpenAI gpt-5: 400,000 tokens per the official
        // OpenAI docs (platform.openai.com/docs/models).
        defaultContextWindowTokens: 400_000
    )

    static let copilot = Provider(
        slug: "copilot",
        name: "GitHub Copilot",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"],
        // Copilot routes to OpenAI / Anthropic under
        // the hood; = 128K (= gpt-4o default) is the
        // safe fallback (= the user can override per
        // model in Settings).
        defaultContextWindowTokens: 128_000
    )

    static let copilotAcp = Provider(
        slug: "copilot-acp",
        name: "GitHub Copilot (ACP)",
        defaultBaseURL: "https://api.githubcopilot.com",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["gpt-4o", "claude-3.5-sonnet"],
        defaultContextWindowTokens: 128_000
    )

    static let xaiOauth = Provider(
        slug: "xai-oauth",
        name: "xAI (OAuth)",
        defaultBaseURL: "https://api.x.ai/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        requiresOAuth: true,
        defaultModels: ["grok-3", "grok-3-mini"],
        // xAI Grok-3: 131,072 tokens per the official
        // x.ai API docs.
        defaultContextWindowTokens: 131_072
    )

    static let stepfun = Provider(
        slug: "stepfun",
        name: "StepFun",
        defaultBaseURL: "https://api.stepfun.com/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["step-3.7-flash"],
        // StepFun's published context window is not
        // authoritative (= the docs page does not
        // state a single number for the default
        // model); = the conservative 32K default
        // is safe (= the user can override in
        // Settings once the actual number is
        // confirmed).
        defaultContextWindowTokens: 32_000
    )

    static let anthropic = Provider(
        slug: "anthropic",
        name: "Anthropic",
        defaultBaseURL: "https://api.anthropic.com",
        apiMode: "anthropic_messages",
        authHeader: .xApiKey,
        defaultModels: ["claude-opus-4-20250514", "claude-sonnet-4-20250514", "claude-3-5-sonnet-20241022"],
        // Anthropic Claude Opus 4 / Sonnet 4: 200,000
        // tokens per docs.anthropic.com.
        defaultContextWindowTokens: 200_000
    )

    static let custom = Provider(
        slug: "custom",
        name: "自定义",
        defaultBaseURL: "",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: [],
        // The user sets the base URL + model = the
        // user is responsible for the context window.
        // 32K is the safe conservative default.
        defaultContextWindowTokens: 32_000
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
        defaultModels: ["gemini-2.5-pro", "gemini-2.5-flash"],
        // Google Gemini 2.5 Pro: 1,000,000 tokens per
        // ai.google.dev docs. Flash is the same.
        defaultContextWindowTokens: 1_000_000
    )

    static let deepseek = Provider(
        slug: "deepseek",
        name: "DeepSeek",
        defaultBaseURL: "https://api.deepseek.com/v1",
        apiMode: "anthropic_messages",
        authHeader: .bearer,
        defaultModels: ["deepseek-chat", "deepseek-reasoner"],
        // DeepSeek V3 / chat / reasoner: 64,000
        // tokens per api-docs.deepseek.com.
        defaultContextWindowTokens: 64_000
    )

    static let ollama = Provider(
        slug: "ollama",
        name: "Ollama (local)",
        defaultBaseURL: "http://localhost:11434/v1",
        apiMode: "openai_chat",
        authHeader: .bearer,
        defaultModels: ["llama3.3", "mistral"],
        // Ollama is local (= the model is whatever the
        // user pulled); = no published canonical
        // number. 8K is the safe conservative default
        // for older local models; the user can
        // override per model in Settings once the
        // pulled model's actual context is known.
        defaultContextWindowTokens: 8_000
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
