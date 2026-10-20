// CronPromptScanner.swift
//
// Prompts the user to confirm a cron schedule scan (= hermes
// `_scan_cron_prompt` parity). The scan detects invisible unicode /
// emoji ZWJ sequences in user-provided cron expressions; = the
// user is asked before the schedule is registered.

import Foundation
//    - _scan_cron_prompt detects invisible unicode / emoji ZWJ sequences in
//      cron prompts (LLM prompt injection vectors).
//    - _check_invisible_unicode blocks ZWJ, RLO, RTL, zero-width chars.
//    - _strip_legitimate_emoji_zwj allows known emoji but strips others.
//
//  wenshu impl: Swift port with conservative blocklist. Catches the most
//  common LLM-targeted injection vectors without breaking legitimate text.
//

import Foundation

/// Result of a cron prompt injection scan.
enum CronPromptScanResult: Sendable, Equatable {
    /// Prompt is clean — proceed.
    case clean
    /// Found injection characters — block and surface reason.
    case blocked(reason: String)
    /// Prompt is suspicious (e.g. unusual unicode density) — warn but allow.
    case suspicious(warning: String)
}
