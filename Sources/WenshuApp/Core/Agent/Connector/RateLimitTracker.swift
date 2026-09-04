//
//  RateLimitTracker.swift · Wenshu · v0.36 ticket 015 sub-step 3
//
//  Per-provider request rate tracking (= hermes RateLimitTracker pattern).
//
//  Tracks recent requests per Provider (= LLM connector profile) to
//  enable:
//  - early backoff when approaching rate limit (= before 429 hits)
//  - request queuing (= serialize high-volume agent flows)
//  - error classifier integration (= retryAfterSeconds hint)
//
//  Pure Swift (= no external deps; Apple Foundation only per wenshu
//  §11 hard rule + ADR-0011 no LLM calls in tracking path).
//
//  v0.36 sub-step 3 of 3 for ticket 015.
//

import Foundation

/// Per-provider rate limit configuration.
/// Used by RateLimitTracker to compute request budget.
public struct ProviderRateLimit: Sendable, Equatable, Codable {
    public let providerSlug: String
    /// Maximum requests per minute (= provider's documented limit).
    public let requestsPerMinute: Int
    /// Maximum tokens per minute (= some providers enforce token budgets).
    public let tokensPerMinute: Int?

    public init(
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
    public static let defaults: [String: ProviderRateLimit] = [
        "minimax-cn": ProviderRateLimit(providerSlug: "minimax-cn", requestsPerMinute: 60),
        "anthropic":  ProviderRateLimit(providerSlug: "anthropic",  requestsPerMinute: 60),
        "openai":     ProviderRateLimit(providerSlug: "openai",     requestsPerMinute: 60),
        "gemini":     ProviderRateLimit(providerSlug: "gemini",     requestsPerMinute: 60),
        "deep-seek":  ProviderRateLimit(providerSlug: "deep-seek",  requestsPerMinute: 60),
        "ollama":     ProviderRateLimit(providerSlug: "ollama",     requestsPerMinute: 1000),  // local = no real limit
        "open-router": ProviderRateLimit(providerSlug: "open-router", requestsPerMinute: 60)
    ]
}

/// Tracks recent requests per provider (= sliding 60-second window).
/// Actor (= thread-safe under Swift 6 strict concurrency).
public actor RateLimitTracker {

    private struct RequestRecord {
        let timestamp: Date
        let tokenCount: Int
    }

    private var records: [String: [RequestRecord]] = [:]
    private var providerLimits: [String: ProviderRateLimit] = ProviderRateLimit.defaults

    public init() {}

    /// Override default rate limit for a provider (= user-configured via Settings).
    public func setLimit(_ limit: ProviderRateLimit) {
        providerLimits[limit.providerSlug] = limit
    }

    /// Record a request (= call BEFORE sending LLM call).
    /// Returns remaining budget (= nil if no limit configured).
    public func recordRequest(
        providerSlug: String,
        tokenCount: Int = 0
    ) -> RateLimitBudget? {
        let now = Date()
        let limit = providerLimits[providerSlug]
        let windowStart = now.addingTimeInterval(-60)  // 60-second window

        var providerRecords = records[providerSlug] ?? []
        // Drop records outside the 60-second window.
        providerRecords = providerRecords.filter { $0.timestamp >= windowStart }

        let requestCount = providerRecords.count + 1  // count this request
        let tokensInWindow = providerRecords.reduce(0) { $0 + $1.tokenCount } + tokenCount

        // Add new record.
        providerRecords.append(RequestRecord(timestamp: now, tokenCount: tokenCount))
        records[providerSlug] = providerRecords

        guard let limit else { return nil }

        let remainingRequests = max(0, limit.requestsPerMinute - requestCount)
        let remainingTokens = limit.tokensPerMinute.map { max(0, $0 - tokensInWindow) }

        return RateLimitBudget(
            providerSlug: providerSlug,
            requestsRemaining: remainingRequests,
            tokensRemaining: remainingTokens,
            isExhausted: remainingRequests == 0
        )
    }

    /// Check current budget (= without recording a request).
    public func currentBudget(providerSlug: String) -> RateLimitBudget? {
        let now = Date()
        let windowStart = now.addingTimeInterval(-60)

        guard let limit = providerLimits[providerSlug] else { return nil }

        let providerRecords = (records[providerSlug] ?? [])
            .filter { $0.timestamp >= windowStart }

        let requestCount = providerRecords.count
        let tokensInWindow = providerRecords.reduce(0) { $0 + $1.tokenCount }

        let remainingRequests = max(0, limit.requestsPerMinute - requestCount)
        let remainingTokens = limit.tokensPerMinute.map { max(0, $0 - tokensInWindow) }

        return RateLimitBudget(
            providerSlug: providerSlug,
            requestsRemaining: remainingRequests,
            tokensRemaining: remainingTokens,
            isExhausted: remainingRequests == 0
        )
    }

    /// Clear history (= called on session reset).
    public func clear() {
        records.removeAll()
    }

    /// Clear history for a specific provider (= called after extended idle).
    public func clear(providerSlug: String) {
        records.removeValue(forKey: providerSlug)
    }
}

/// Current budget snapshot (= returned by RateLimitTracker).
public struct RateLimitBudget: Sendable, Equatable {
    public let providerSlug: String
    public let requestsRemaining: Int
    public let tokensRemaining: Int?
    public let isExhausted: Bool

    public init(
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