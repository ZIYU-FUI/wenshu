//
//  BackgroundCreditsTracker.swift · Wenshu · v0.36 ticket 016 sub-step 1
//
//  Tracks AI agent credit / token consumption (= spec §3.1 L227-231
//  Background/ sub-directory, file 4 of 4 = CreditsTracker).
//
//  Per ADR-0011 + §11 hard rule: pure Swift actor, no LLM calls, no
//  filesystem I/O at runtime. Periodic persistence to UserDefaults via
//  @AppStorage (lazy = only on snapshot save).
//
//  Per wenshu §11 product-positioning rule: wenshu never charges users
//  for tokens. This tracker is for the user's own visibility (= how many
//  tokens their BYOK config has consumed this session / month) — NOT
//  for billing or metering. Wenshu is a writing tool, not a platform.
//
//  v0.36 sub-step 1 of 4 for ticket 016.
//

import Foundation

/// Source of credit consumption (= tracks which LLM provider call consumed
/// how many tokens). Enables per-provider / per-model visibility.
public struct CreditConsumption: Sendable, Equatable, Codable {
    public let providerSlug: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let timestamp: Date

    public init(
        providerSlug: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        timestamp: Date = Date()
    ) {
        self.providerSlug = providerSlug
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.timestamp = timestamp
    }

    public var totalTokens: Int { inputTokens + outputTokens }
}

/// Aggregate credit summary for a time window.
public struct CreditSummary: Sendable, Equatable, Codable {
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let perProvider: [String: Int]    // provider slug → total tokens
    public let perModel: [String: Int]       // model name → total tokens
    public let windowStart: Date
    public let windowEnd: Date

    public init(
        totalInputTokens: Int,
        totalOutputTokens: Int,
        perProvider: [String: Int],
        perModel: [String: Int],
        windowStart: Date,
        windowEnd: Date
    ) {
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.perProvider = perProvider
        self.perModel = perModel
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }

    public var grandTotal: Int { totalInputTokens + totalOutputTokens }
}

/// Tracks AI agent credit consumption over time (= actor, thread-safe).
/// Pure Swift (= no LLM calls per ADR-0011). Periodic snapshots to
/// UserDefaults via @AppStorage (= wenshu §11 baseline, not v0.34+ sqlite).
public actor BackgroundCreditsTracker {

    private var history: [CreditConsumption] = []
    /// Per-session counter (= reset on new session; lives in actor state).
    private var sessionStart: Date = Date()
    /// Per-month counter (= persisted to UserDefaults; survives restart).
    private let monthlyKey = "wenshu.credits.monthly"
    private let monthlyResetKey = "wenshu.credits.monthlyReset"

    public init() {}

    /// Record a credit consumption (= called by LLMConnector after send()).
    public func record(_ consumption: CreditConsumption) {
        history.append(consumption)
        // Persist monthly counter (= append input + output tokens).
        let monthly = currentMonthlyTotal()
        let newTotal = monthly + consumption.totalTokens
        UserDefaults.standard.set(newTotal, forKey: monthlyKey)
    }

    /// Current session summary (= in-memory history only).
    public func currentSessionSummary() -> CreditSummary {
        let now = Date()
        let inputTokens = history.reduce(0) { $0 + $1.inputTokens }
        let outputTokens = history.reduce(0) { $0 + $1.outputTokens }
        var perProvider: [String: Int] = [:]
        var perModel: [String: Int] = [:]
        for c in history {
            perProvider[c.providerSlug, default: 0] += c.totalTokens
            perModel[c.model, default: 0] += c.totalTokens
        }
        return CreditSummary(
            totalInputTokens: inputTokens,
            totalOutputTokens: outputTokens,
            perProvider: perProvider,
            perModel: perModel,
            windowStart: sessionStart,
            windowEnd: now
        )
    }

    /// Current month total (= persisted; survives app restart).
    public func currentMonthlyTotal() -> Int {
        // Reset if month changed
        if let lastResetString = UserDefaults.standard.string(forKey: monthlyResetKey),
           let lastReset = ISO8601DateFormatter().date(from: lastResetString) {
            if !Calendar.current.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
                UserDefaults.standard.set(0, forKey: monthlyKey)
                UserDefaults.standard.set(
                    ISO8601DateFormatter().string(from: Date()),
                    forKey: monthlyResetKey
                )
                return 0
            }
        } else {
            // First run: initialize
            UserDefaults.standard.set(
                ISO8601DateFormatter().string(from: Date()),
                forKey: monthlyResetKey
            )
        }
        return UserDefaults.standard.integer(forKey: monthlyKey)
    }

    /// Reset session (= user-triggered; clears in-memory history).
    public func resetSession() {
        history.removeAll()
        sessionStart = Date()
    }

    /// Reset monthly counter (= user-triggered; clears persisted data).
    public func resetMonthly() {
        UserDefaults.standard.set(0, forKey: monthlyKey)
        UserDefaults.standard.set(
            ISO8601DateFormatter().string(from: Date()),
            forKey: monthlyResetKey
        )
    }

    /// All recorded history (= for diagnostics + UI).
    public var allHistory: [CreditConsumption] {
        return history
    }
}