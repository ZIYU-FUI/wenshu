//
//  FallbackChain.swift
//
//  Ordered provider fallback chain executor. Ported from
//  hermes-agent `hermes_cli/fallback_chain.py` + `auth.py` fallback config.
//
//  Design (= hermes FallbackChain pattern):
//    - A `FallbackChain` is an ordered list of provider slugs (= "anthropic",
//      "openai", "minimax-cn", ...). Index 0 = primary, index 1+ = fallbacks.
//    - `FallbackChainExecutor.execute(request:chain:)` walks the chain,
//      trying each provider until one succeeds (= via `AuthPool.pickBestKey`
//      to select the actual key for that provider).
//    - On per-provider failure (= 429 / 503 / auth), the executor advances
//      to the next provider. After every provider fails, it throws
//      `FallbackChainError.allFailed` with the last error per provider.
//    - `executeOrThrow` is the strict variant that re-throws the first
//      per-provider error (= hermes' "fallback or fail" semantics).
//    - Per-provider timeout (= default 30s) is enforced via `Task.sleep` +
//      `Task.cancel` when the chain's slot deadline elapses.
//
//  Public API is `Sendable` (= Swift 6 strict concurrency safe).
//  Stateful logic (= executor's internal counters, request snapshot) lives
//  inside the actor.
//
// dispatch layer 2 of 4. Refs: the (see OOB.md) 'A' 2026-09-04.
//

import Foundation
import WenshuAgent
import os

private let wenshuFallbackLogger = Logger(subsystem: "org.wenshu.auth", category: "fallback")

// MARK: - Chain model

/// Ordered list of providers to try (= hermes `FallbackChain`).
struct FallbackChain: Sendable, Codable, Equatable {
    /// `providers[0]` = primary; `providers[1...]` = fallbacks in order.
    let providers: [String]

    init(providers: [String]) {
        self.providers = providers
    }

    /// True when there are no providers in the chain (= invalid).
    var isEmpty: Bool { providers.isEmpty }

    /// Look up the position of a provider in the chain. Returns nil if absent.
    func index(of provider: String) -> Int? {
        providers.firstIndex(of: provider)
    }
}

// MARK: - Request / response shapes

/// A minimal request envelope (= hermes' `api_messages`).
/// Sufficient for the executor's purposes; the connector does the rest.
///
/// Naming note: `LLMRequest` already exists in `ShellHookChain.swift`
/// (= the hook-side placeholder type). This dispatch-side type is named
/// `DispatchRequest` to avoid the public-API collision (= AGENTS.md
/// hard rule: don't remove existing public surface).
struct DispatchRequest: Sendable {
    let messages: [LLMMessage]
    let options: LLMCallOptions

    init(messages: [LLMMessage], options: LLMCallOptions) {
        self.messages = messages
        self.options = options
    }

    /// Convenience: build a single-text user request.
    static func user(
        _ text: String,
        model: String,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) -> DispatchRequest {
        DispatchRequest(
            messages: [LLMMessage.user(text)],
            options: LLMCallOptions(
                model: model,
                maxTokens: maxTokens,
                systemPrompt: systemPrompt,
                temperature: temperature
            )
        )
    }
}

// MARK: - Resolver abstraction

/// Resolved bundle (= connector + api key string for the active key).
/// `apiKey` is "" for no-auth providers (= Ollama).
struct ResolvedConnector: Sendable {
    let connector: any LLMConnector
    let apiKey: String
    let keyId: UUID?       // optional AuthKey id (= for markOk / markFailed)
    init(connector: any LLMConnector, apiKey: String, keyId: UUID? = nil) {
        self.connector = connector
        self.apiKey = apiKey
        self.keyId = keyId
    }
}

/// Pluggable resolver from `(provider, request)` -> `(connector, credentials)`.
/// The executor doesn't need to know about ProviderKeychain / ConnectorCredentials
/// internals — it just asks the resolver for the connector + creds to send.
///
/// This is the seam that lets FallbackChain work with wenshu's existing
/// connector layer (= `LLMConnector` protocol from `LLMConnector.swift`)
/// without re-implementing any auth logic. The resolver is the place
/// where production wiring threads the per-provider apiKey through.
protocol FallbackConnectorResolver: Sendable {
    /// Resolve the connector + credentials for a provider slug.
    /// Returns nil if the provider is not registered (= caller should skip
    /// or fail depending on the executor variant).
    func resolve(
        provider: String,
        request: DispatchRequest
    ) async -> ResolvedConnector?
}
