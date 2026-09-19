//
//  ChatViewCompressionRowFormatterTests.swift · Wenshu · T31-CONTEXT-PERCENTAGE (2026-09-18)
//
//  Verifies the context-usage formatter that powers the
//  compression-row warning text (= "💡 1.5k / 30k tokens (5%)").
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatViewCompressionRowFormatter (T31)")
struct ChatViewCompressionRowFormatterTests {

    /// T31 contract: small counts (< 1k) format as plain integers.
    @Test func format_small_count() {
        #expect(ChatViewCompressionRowFormatter.formatContextUsage(
            100, threshold: 30_000
        ) == "100 / 30k tokens (0%)")
    }

    /// T31 contract: 1.5k / 30k = 5% (= 1500/30000 = 0.05 = 5%).
    @Test func format_5_percent() {
        #expect(ChatViewCompressionRowFormatter.formatContextUsage(
            1_500, threshold: 30_000
        ) == "1.5k / 30k tokens (5%)")
    }

    /// T31 contract: 15k / 30k = 50%.
    @Test func format_50_percent() {
        #expect(ChatViewCompressionRowFormatter.formatContextUsage(
            15_000, threshold: 30_000
        ) == "15k / 30k tokens (50%)")
    }

    /// T31 contract: 30k / 30k = 100% (= at threshold).
    @Test func format_100_percent() {
        #expect(ChatViewCompressionRowFormatter.formatContextUsage(
            30_000, threshold: 30_000
        ) == "30k / 30k tokens (100%)")
    }

    /// T31 contract: oversized count (> threshold) caps the percent
    /// at 100+ (= we don't show 150% = visual noise; = just shows
    /// "33k / 30k tokens (110%)" = the user sees they're over).
    @Test func format_oversized_count() {
        let result = ChatViewCompressionRowFormatter.formatContextUsage(
            33_000, threshold: 30_000
        )
        #expect(result == "33k / 30k tokens (110%)")
    }

    /// T31 contract: zero threshold (= defensive) doesn't crash
    /// (= divides by 1 instead = percent = count).
    @Test func format_zero_threshold_no_crash() {
        // Zero threshold (= defensive): doesn't crash (= guard
        // `max(threshold, 1)` saves us from divide-by-zero). The
        // exact percent value isn't meaningful when threshold = 0
        // (= the budget is unconstrained); = the test only checks
        // that the function returns without throwing.
        let result = ChatViewCompressionRowFormatter.formatContextUsage(
            100, threshold: 0
        )
        #expect(result.contains("100 / 0 tokens"))
        #expect(result.contains("%"))
    }
}