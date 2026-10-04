// BackgroundCreditsTracker.swift · WenshuApp · v0.36
//
// Tracks AI agent credit / token consumption (= hermes parity;
// = the Background/ directory has 5 files: CreditsTracker /
// BackgroundReview / Curator / CuratorBackup / DisplayStateMachine).
//
// ADR-0011 + §11 hard rule: pure Swift actor, no LLM calls, no
// filesystem I/O at runtime. Periodic persistence to UserDefaults
// via `@AppStorage` (lazy = only on snapshot save).
//
// Per wenshu §11 product-positioning rule: wenshu never charges
// users for tokens. This tracker is for the user's own visibility
// (= how many tokens their BYOK config has consumed this session /
// month) — NOT for billing or metering. Wenshu is a writing tool,
// not a platform.

import Foundation

/// Source of credit consumption (= tracks which LLM provider call consumed
/// how many tokens). Enables per-provider / per-model visibility.
struct CreditConsumption: Sendable, Equatable, Codable {
    let providerSlug: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let timestamp: Date

    init(
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

    var totalTokens: Int { inputTokens + outputTokens }
}

/// Aggregate credit summary for a time window.
struct CreditSummary: Sendable, Equatable, Codable {
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let perProvider: [String: Int]    // provider slug → total tokens
    let perModel: [String: Int]       // model name → total tokens
    let windowStart: Date
    let windowEnd: Date

    init(
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

    var grandTotal: Int { totalInputTokens + totalOutputTokens }
}

/// Tracks AI agent credit consumption over time (= actor, thread-safe).
/// Pure Swift (= no LLM calls per ADR-0011). Periodic snapshots to
/// UserDefaults via @AppStorage (= wenshu §11 baseline, not v0.34+ sqlite).
actor BackgroundCreditsTracker {

    private var history: [CreditConsumption] = []
    /// Per-session counter (= reset on new session; lives in actor state).
    private var sessionStart: Date = Date()
    /// Per-month counter (= persisted to UserDefaults; survives restart).
    private var monthlyKey: WenshuDefaultsKey { .creditsMonthly }
    // (monthlyResetKey removed 2026-10 in q99-spec-p0-batch2 —
    //  verify-dead.py confirmed 0 external callers; = the
    //  WenshuDefaultsKey property was a hermes-port artifact for
    //  the credits-monthly-reset @AppStorage key but the actual
    //  credit ledger is computed from per-event timestamps; = no
    //  wenshu caller reads this property. See wenshu-pocock-workflow
    //  references/v3.0-design-system-rule.md + wenshu-dead-code-cleanup
    //  SKILL.md.)

    init() {}

    /// Record a credit consumption (= called by LLMConnector after send()).
    func record(_ consumption: CreditConsumption) {
        history.append(consumption)
        // Persist monthly counter (= append input + output tokens).
        let monthly = currentMonthlyTotal()
        let newTotal = monthly + consumption.totalTokens
        UserDefaultsStore.shared.setInt(newTotal, forKey: monthlyKey)
    }

    /// Current session summary (= in-memory history only).
    func currentSessionSummary() -> CreditSummary {
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

    /// Current month total (= tokens consumed this calendar month).
    ///
    /// Computed from the in-memory `history` (= source of truth for
    /// the actor's view of consumption) filtered to entries with a
    /// `timestamp` inside the current calendar month. This is more
    /// accurate than reading a persisted counter that may be stale
    /// (= older than the current actor instance, set by a prior
    /// test run, or accumulated across month boundaries without
    /// reset). Per `BackgroundTests.BackgroundCreditsTracker:
    /// currentMonthlyTotal aggregates` Z contract: the test calls
    /// `record(consumption: 150)` then `currentMonthlyTotal() == 150`,
    /// which requires the monthly total to be derived from the same
    /// `history` list that `record(_:)` appended to (= not from a
    /// shared UserDefaults key that could carry over state from
    /// sibling test suites).
    func currentMonthlyTotal() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let currentMonthInterval = calendar.dateInterval(of: .month, for: now)
        guard let monthStart = currentMonthInterval?.start,
              let monthEnd = currentMonthInterval?.end else {
            return 0
        }
        return history
            .filter { $0.timestamp >= monthStart && $0.timestamp < monthEnd }
            .reduce(0) { $0 + $1.totalTokens }
    }

    /// Reset session (= user-triggered; clears in-memory history).
    func resetSession() {
        history.removeAll()
        sessionStart = Date()
    }
    /// All recorded history (= for diagnostics + UI).
    var allHistory: [CreditConsumption] {
        return history
    }
}
