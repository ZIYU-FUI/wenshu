// RateLimitTracker.swift
//
// Per-provider request rate tracking (= hermes `RateLimitTracker`
// pattern). Tracks recent requests per `Provider` (= LLM connector
// profile) to enable:
//   - early backoff when approaching rate limit (= before 429 hits)
//   - request queuing (= serialize high-volume agent flows)
//   - error classifier integration (= `retryAfterSeconds` hint)
//
// Pure Swift (= no external deps; Apple Foundation only per wenshu
// §11 hard rule + ADR-0011 no LLM calls in tracking path).

import Foundation

/// Per-provider rate limit configuration.
/// Used by RateLimitTracker to compute request budget.
struct ProviderRateLimit: Sendable, Equatable, Codable {
    let providerSlug: String
    /// Maximum requests per minute (= provider's documented limit).
    let requestsPerMinute: Int
    /// Maximum tokens per minute (= some providers enforce token budgets).
    let tokensPerMinute: Int?

    init(
        providerSlug: String,
        requestsPerMinute: Int,
        tokensPerMinute: Int? = nil
    ) {
        self.providerSlug = providerSlug
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
    }

    /// Default rate limits per provider (= from §11.2 LLM connector profiles).
    /// Conservative values; user can override via Settings if provider
    /// allows higher quota.
    static let defaults: [String: ProviderRateLimit] = [
        "minimax-cn": ProviderRateLimit(providerSlug: "minimax-cn", requestsPerMinute: 60),
        "anthropic":  ProviderRateLimit(providerSlug: "anthropic",  requestsPerMinute: 60),
        "openai":     ProviderRateLimit(providerSlug: "openai",     requestsPerMinute: 60),
        "gemini":     ProviderRateLimit(providerSlug: "gemini",     requestsPerMinute: 60),
        "deep-seek":  ProviderRateLimit(providerSlug: "deep-seek",  requestsPerMinute: 60),
        "ollama":     ProviderRateLimit(providerSlug: "ollama",     requestsPerMinute: 1000),  // local = no real limit
        "open-router": ProviderRateLimit(providerSlug: "open-router", requestsPerMinute: 60)
    ]
}

/// Current budget snapshot (= returned by RateLimitTracker).
struct RateLimitBudget: Sendable, Equatable {
    let providerSlug: String
    let requestsRemaining: Int
    let tokensRemaining: Int?
    let isExhausted: Bool

    init(
        providerSlug: String,
        requestsRemaining: Int,
        tokensRemaining: Int?,
        isExhausted: Bool
    ) {
        self.providerSlug = providerSlug
        self.requestsRemaining = requestsRemaining
        self.tokensRemaining = tokensRemaining
        self.isExhausted = isExhausted
    }
}
