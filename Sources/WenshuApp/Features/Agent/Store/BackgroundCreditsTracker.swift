// BackgroundCreditsTracker.swift
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
