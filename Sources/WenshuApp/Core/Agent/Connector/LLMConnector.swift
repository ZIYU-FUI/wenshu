//
//  LLMConnector.swift · Wenshu · v0.35 ticket 001 sub-step 2
//
//  LLMConnector protocol = the public-facing façade for all 7 LLM
//  provider adapters (= AGENTS.md §11.2). The protocol abstracts the
//  cross-connector wire format so callers (= ConversationLoop, Tool
//  executor, WenshuVerifier) do not depend on any specific provider.
//
//  7 conformers (per spec §3.2 + ticket list):
//    - OpenAICompatibleConnector (= minimax cn, DeepSeek, Ollama, OpenRouter)
//    - AnthropicConnector (= ticket 004)
//    - OpenAIConnector (= ticket 005)
//    - GeminiNativeConnector (= ticket 007)
//    - 3 thin wrappers in tickets 007-008 (= DeepSeek / Ollama / OpenRouter)
//
//  Design invariants (= AGENTS.md §11.3 + §11 product-positioning):
//    1. Protocol is BYOK = ConnectorCredentials resolves keys via existing
//       ProviderKeychain (= wenshu-side wins, no parallel keychain).
//    2. No metering / billing / quota tracking in this layer
//       (= §11 product-positioning).
//    3. No default profile = caller must specify active profile.
//    4. send(messages:) is the only public method = minimum interface.
//       Streaming + use = out of scope for sub-step 2 (lands in
//       subsequent sub-steps via LLMStreamingConnector).
//
//  v0.35 sub-step 2 of 8 for ticket 001 (= TB-B tracer-bullet).
//  Refs: .scratch/2026-09-03-hermes-core-translation/spec.md §3.1, §3.2, §6.4
//

import Foundation

/// Public-facing protocol for all 7 LLM connector profiles.
///
/// Conformers (= OpenAICompatibleConnector / AnthropicConnector / OpenAIConnector
/// / GeminiNativeConnector / etc.) implement the cross-connector wire format
/// mapping. Callers (= ConversationLoop, ToolExecutor, WenshuVerifier) depend
/// only on this protocol.
public protocol LLMConnector: Sendable {
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
}

/// Per-call options for `LLMConnector.send`.
public struct LLMCallOptions: Sendable {
    public let model: String
    public let maxTokens: Int
    public let systemPrompt: String?
    public let temperature: Double?

    public init(
        model: String,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.temperature = temperature
    }
}

/// Errors thrown by `LLMConnector.send`.
public enum LLMConnectorError: Error, LocalizedError, Sendable {
    case missingAPIKey(provider: String)
    case transport(provider: String, statusCode: Int, body: String)
    case decode(provider: String, underlying: String)
    case unsupportedProvider(slug: String)
    case streamingFailed(provider: String)  // v0.36 ticket 004 sub-step 4

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):
            return "Missing API key for provider '\\(p)'."
        case .transport(let p, let s, _):
            return "Provider '\\(p)' returned HTTP \\(s)."
        case .decode(let p, let u):
            return "Provider '\\(p)' response decode failed: \\(u)"
        case .unsupportedProvider(let s):
                    return "Provider slug '\(s)' is not a recognized connector profile."
                case .streamingFailed(let p):
                    return "Anthropic streaming failed for \(p)."
                }
            }
        }