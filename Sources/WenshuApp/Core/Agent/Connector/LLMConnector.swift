// LLMConnector.swift
//
// `LLMConnector` protocol = the public-facing façade for all 7 LLM
// provider adapters (= AGENTS.md §11.2). The protocol abstracts the
// cross-connector wire format so callers (= `ConversationLoop`, tool
// executor, `WenshuVerifier`) do not depend on any specific provider.
//
// 7 conformers:
//   - `OpenAICompatibleConnector` (= minimax cn, DeepSeek, Ollama,
//     OpenRouter)
//   - `AnthropicConnector`
//   - `OpenAIConnector`
//   - `GeminiNativeConnector`
//   - 3 thin wrappers for DeepSeek / Ollama / OpenRouter
//
// Design invariants (= AGENTS.md §11.3 + §11 product-positioning):
//   1. Protocol is BYOK = `ConnectorCredentials` resolves keys via
//      the existing `ProviderKeychain` (= wenshu-side wins, no
//      parallel keychain).
//   2. No metering / billing / quota tracking in this layer (= §11
//      product-positioning).
//   3. No default profile = caller must specify active profile.
//   4. `send(messages:)` is the only public method = minimum
//      interface. Streaming + use live in subsequent
//      `LLMStreamingConnector` work.

import Foundation

/// Public-facing protocol for all 7 LLM connector profiles.
///
/// Conformers (= OpenAICompatibleConnector / AnthropicConnector / OpenAIConnector
/// / GeminiNativeConnector / etc.) implement the cross-connector wire format
/// mapping. Callers (= ConversationLoop, ToolExecutor, WenshuVerifier) depend
/// only on this protocol.
protocol LLMConnector: Sendable {
    /// Identifier for the active connector (= e.g. "anthropic", "openai-codex",
    /// "minimax-cn", "gemini", "deepseek", "ollama", "openrouter").
    var connectorID: String { get }

    /// Send messages to the active connector's LLM, return the response.
    ///
    /// - Parameters:
    ///   - messages: Cross-connector message list (= user / assistant / tool).
    ///   - options: Per-call overrides (= model selection, max tokens, system).
    /// - Returns: Cross-connector response (= text / thinking / tool_use blocks
    ///   + usage + stop reason).
    /// - Throws: `LLMConnectorError` on transport / auth / provider failure.
    func send(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) async throws -> LLMResponse

    /// Stream blocks from the LLM (= token-by-token + tool dispatch).
    ///
    /// T7-STREAM-DEFAULT (2026-09-18): default implementation calls
    /// send(...) and yields each block in the response as a single
    /// chunk (= the "fake streaming" path). Connectors with native
    /// SSE support can override this to yield per-token chunks.
    func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock>
}

extension LLMConnector {
    /// Default stream implementation: calls send(...), then yields
    /// each block from the response. Connectors with native streaming
    /// override this.
    func stream(
        messages: [LLMMessage],
        options: LLMCallOptions
    ) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            Task {
                do {
                    let response = try await self.send(
                        messages: messages,
                        options: options
                    )
                    for block in response.blocks {
                        continuation.yield(block)
                    }
                } catch {
                    // Emit a synthetic error block so ChatView shows it.
                    continuation.yield(.text("[stream error] \(error)"))
                }
                continuation.finish()
            }
        }
    }
}

/// Per-call options for `LLMConnector.send`.
struct LLMCallOptions: Sendable {
    let model: String
    let maxTokens: Int
    let systemPrompt: String?
    let temperature: Double?
    /// Reasoning effort level from `wenshu.llm.reasoningEffort` (= user setting).
    /// Values: "low" / "medium" / "high" / "xhigh" / "max". nil = connector uses provider default.
    /// wired from SettingView picker through to connector adapters
    /// (= Anthropic thinking budget_tokens, OpenAI reasoning_effort, Gemini thinkingBudget).
    let reasoningEffort: String?
    /// Tool schemas made available to the model for this call.
    /// When non-empty, the connector serializes them into the provider's
    /// `tools` parameter so the model can issue `tool_use` blocks.
    /// Empty (= default) preserves the prior behavior of omitting the
    /// `tools` field from the request body.
    let tools: [ToolRegistrySchema]

    init(
            model: String,
            maxTokens: Int = 1024,
            systemPrompt: String? = nil,
            temperature: Double? = nil,
            reasoningEffort: String? = nil,
            tools: [ToolRegistrySchema] = []
        ) {
        self.model = model
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.reasoningEffort = reasoningEffort
        self.tools = tools
    }
}

/// Errors thrown by `LLMConnector.send`.
enum LLMConnectorError: Error, LocalizedError, Sendable {
    case missingAPIKey(provider: String)
    case transport(provider: String, statusCode: Int, body: String)
    case decode(provider: String, underlying: String)
    case unsupportedProvider(slug: String)
    case streamingFailed(provider: String)  // sub-step 4

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):
            return "Missing API key for provider '\(p)'."
        case .transport(let p, let s, _):
            return "Provider '\(p)' returned HTTP \(s)."
        case .decode(let p, let u):
            return "Provider '\(p)' response decode failed: \(u)"
        case .unsupportedProvider(let s):
            return "Provider slug '\(s)' is not a recognized connector profile."
        case .streamingFailed(let p):
            return "Anthropic streaming failed for \(p)."
        }
    }
}
