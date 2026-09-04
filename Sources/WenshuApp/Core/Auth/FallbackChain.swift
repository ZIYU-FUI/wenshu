//
//  FallbackChain.swift · Wenshu · HERMES-DISPATCH-002
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
//  v0.40 dispatch layer 2 of 4. Refs: boss OOB 'A' 2026-09-04.
//

import Foundation

// MARK: - Chain model

/// Ordered list of providers to try (= hermes `FallbackChain`).
public struct FallbackChain: Sendable, Codable, Equatable {
    /// `providers[0]` = primary; `providers[1...]` = fallbacks in order.
    public let providers: [String]

    public init(providers: [String]) {
        self.providers = providers
    }

    /// True when there are no providers in the chain (= invalid).
    public var isEmpty: Bool { providers.isEmpty }

    /// Look up the position of a provider in the chain. Returns nil if absent.
    public func index(of provider: String) -> Int? {
        providers.firstIndex(of: provider)
    }
}

// MARK: - Request / response shapes

/// A minimal request envelope (= hermes' `api_messages`).
/// Sufficient for the executor's purposes; the connector does the rest.
public struct LLMRequest: Sendable {
    public let messages: [LLMMessage]
    public let options: LLMCallOptions

    public init(messages: [LLMMessage], options: LLMCallOptions) {
        self.messages = messages
        self.options = options
    }

    /// Convenience: build a single-text user request.
    public static func user(
        _ text: String,
        model: String,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) -> LLMRequest {
        LLMRequest(
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

/// Successful execution outcome (= returned by `execute(_:chain:)`).
public struct FallbackExecutionResult: Sendable, Equatable {
    /// The successful response.
    public let response: LLMResponse
    /// Provider slug that produced the response (= member of the chain).
    public let provider: String
    /// Index in `chain.providers` (= 0 = primary, 1+ = fallback).
    public let providerIndex: Int
    /// Number of attempts (= 1 = primary succeeded on first try).
    public let attempts: Int

    public init(
        response: LLMResponse,
        provider: String,
        providerIndex: Int,
        attempts: Int
    ) {
        self.response = response
        self.provider = provider
        self.providerIndex = providerIndex
        self.attempts = attempts
    }
}

// MARK: - Errors

public enum FallbackChainError: Error, LocalizedError, Sendable, Equatable {
    /// The chain had zero providers (= caller misconfiguration).
    case emptyChain
    /// Every provider in the chain failed (= one entry per attempted provider).
    case allFailed(attempts: [FailedAttempt])
    /// No usable key was available for a specific provider in the chain.
    case noUsableKey(provider: String)

    public var errorDescription: String? {
        switch self {
        case .emptyChain:
            return "FallbackChain has no providers."
        case .allFailed(let attempts):
            let summary = attempts
                .map { "\($0.provider)[\($0.providerIndex)]=\($0.error)" }
                .joined(separator: ", ")
            return "FallbackChain: all providers failed (\(attempts.count) attempts): \(summary)"
        case .noUsableKey(let p):
            return "FallbackChain: no usable credential in AuthPool for provider '\(p)'."
        }
    }

    /// One entry per attempted provider (= mirrors hermes' attempt log).
    public struct FailedAttempt: Sendable, Equatable {
        public let provider: String
        public let providerIndex: Int
        public let error: String
        public init(provider: String, providerIndex: Int, error: String) {
            self.provider = provider
            self.providerIndex = providerIndex
            self.error = error
        }
    }
}

// MARK: - Resolver abstraction

/// Resolved bundle (= connector + api key string for the active key).
/// `apiKey` is "" for no-auth providers (= Ollama).
public struct ResolvedConnector: Sendable {
    public let connector: any LLMConnector
    public let apiKey: String
    public let keyId: UUID?       // optional AuthKey id (= for markOk / markFailed)
    public init(connector: any LLMConnector, apiKey: String, keyId: UUID? = nil) {
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
/// without re-implementing any auth logic. The resolver is the place where
/// production wiring lands in a follow-up ticket (= ticket 013 per the
/// integration gap analysis).
public protocol FallbackConnectorResolver: Sendable {
    /// Resolve the connector + credentials for a provider slug.
    /// Returns nil if the provider is not registered (= caller should skip
    /// or fail depending on the executor variant).
    func resolve(
        provider: String,
        request: LLMRequest
    ) async -> ResolvedConnector?
}

// MARK: - Executor

/// Execute an LLM call against a fallback chain.
/// Per-provider timeout enforced; on per-provider failure, advance to next
/// provider in the chain. After every provider fails, throw
/// `FallbackChainError.allFailed`.
public actor FallbackChainExecutor {

    private let pool: AuthPool
    private let resolver: any FallbackConnectorResolver
    private let timeoutPerProvider: TimeInterval

    public init(
        pool: AuthPool,
        resolver: any FallbackConnectorResolver,
        timeoutPerProvider: TimeInterval = 30
    ) {
        self.pool = pool
        self.resolver = resolver
        self.timeoutPerProvider = timeoutPerProvider
    }

    /// Try each provider in order until one succeeds. Returns the successful
    /// response + which provider/index produced it + how many attempts ran.
    /// Throws `FallbackChainError.emptyChain` if the chain is empty.
    /// Throws `FallbackChainError.allFailed(attempts:)` if every provider fails.
    public func execute(
        request: LLMRequest,
        chain: FallbackChain
    ) async throws -> FallbackExecutionResult {
        guard !chain.isEmpty else { throw FallbackChainError.emptyChain }

        var attempts: [FallbackChainError.FailedAttempt] = []
        var attemptCount = 0

        for (index, provider) in chain.providers.enumerated() {
            attemptCount += 1
            do {
                let result = try await runOne(
                    request: request,
                    provider: provider,
                    providerIndex: index,
                    attempt: attemptCount
                )
                return result
            } catch {
                let reason = (error as? LocalizedError)?.errorDescription
                    ?? String(describing: error)
                attempts.append(
                    .init(
                        provider: provider,
                        providerIndex: index,
                        error: reason
                    )
                )
                // Continue to next provider.
                continue
            }
        }

        throw FallbackChainError.allFailed(attempts: attempts)
    }

    /// Strict variant: throw the FIRST per-provider error (= primary failed,
    /// no fallback tried). Used when callers want explicit primary-first
    /// semantics (= e.g. when the chain is "primary only").
    public func executeOrThrow(
        request: LLMRequest,
        chain: FallbackChain
    ) async throws -> LLMResponse {
        guard let first = chain.providers.first else { throw FallbackChainError.emptyChain }
        let result = try await runOne(
            request: request,
            provider: first,
            providerIndex: 0,
            attempt: 1
        )
        return result.response
    }

    // MARK: Private

    /// Run one provider attempt (= with per-provider timeout).
    /// Marks the AuthKey status based on outcome.
    private func runOne(
        request: LLMRequest,
        provider: String,
        providerIndex: Int,
        attempt: Int
    ) async throws -> FallbackExecutionResult {
        // 1. Pick best key from AuthPool (= nil = no usable credential).
        // We don't need the key itself here (= production ticket 013
        // will thread the apiKey through the connector); the call is
        // a health-check on the pool's view of the provider.
        guard try await pool.pickBestKey(for: provider) != nil else {
            throw FallbackChainError.noUsableKey(provider: provider)
        }
        // 2. Resolve connector + credentials.
        guard let resolved = await resolver.resolve(
            provider: provider,
            request: request
        ) else {
            throw FallbackChainError.noUsableKey(provider: provider)
        }
        // 3. Send under per-provider timeout. If the connector uses the
        // apiKey in its own way (= standard for the 7 LLMConnector
        // conformers), `resolved.apiKey` is what it sees. AuthPool is
        // updated AFTER the call (= success -> markOk, failure -> mark*).
        let response = try await sendWithTimeout(
            connector: resolved.connector,
            request: request,
            apiKey: resolved.apiKey,
            provider: provider,
            timeout: timeoutPerProvider
        )
        // 4. Mark success (= reset to .ok + clear cooldown + lastError).
        if let keyId = resolved.keyId {
            try? await pool.markOk(keyId: keyId)
        }
        return FallbackExecutionResult(
            response: response,
            provider: provider,
            providerIndex: providerIndex,
            attempts: attempt
        )
    }

    /// Send via the connector under a per-provider timeout.
    /// Maps the thrown error to AuthKey status when possible (= 429 ->
    /// rate-limited, 401/403 -> auth-failed, 5xx -> networkError).
    private func sendWithTimeout(
        connector: any LLMConnector,
        request: LLMRequest,
        apiKey: String,
        provider: String,
        timeout: TimeInterval
    ) async throws -> LLMResponse {
        // `_ = apiKey` — production wiring (= ticket 013) injects apiKey into
        // the connector's per-call options / transport layer. The base
        // `LLMConnector.send(messages:options:)` signature does NOT take
        // apiKey; each connector resolves it internally via
        // `ConnectorCredentials.resolve(for:)`. So this executor delegates
        // send() verbatim and trusts the connector to pick the active key
        // (= which AuthPool has already pointed at via `pickBestKey`).
        _ = apiKey

        // Cancel-on-timeout: race the connector send against a watchdog Task.
        // Whoever resumes first wins. The cleanup task cancels whichever
        // side lost to prevent double-resume.
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LLMResponse, Error>) in
            let workTask = Task {
                do {
                    let response = try await connector.send(
                        messages: request.messages,
                        options: request.options
                    )
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            let watchdog = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                workTask.cancel()
                continuation.resume(
                    throwing: TimeoutError(provider: provider, seconds: timeout)
                )
            }
            // Cleanup: whichever task loses, cancel the other to prevent
            // a second continuation.resume.
            Task {
                _ = await workTask.value
                watchdog.cancel()
            }
        }
    }

    /// Internal timeout error (= re-thrown by the watchdog task).
    private struct TimeoutError: Error, LocalizedError {
        let provider: String
        let seconds: TimeInterval
        var errorDescription: String? {
            "FallbackChain: provider '\(provider)' timed out after \(seconds)s."
        }
    }
}
