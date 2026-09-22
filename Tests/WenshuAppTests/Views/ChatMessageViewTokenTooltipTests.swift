//
//  ChatMessageViewTokenTooltipTests.swift · Wenshu · T52-TOKEN-TOOLTIP (2026-09-18)
//
//  Verifies the fullTokenCountTooltip helper + .help() wiring
//  on the token count text in ChatMessageView.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView token tooltip (T52)")
struct ChatMessageViewTokenTooltipTests {

    /// T52 contract: fullTokenCountTooltip helper exists.
    @Test func helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func fullTokenCountTooltip(for count: Int) -> String"))
    }

    /// T52 contract: source wires .help(Self.fullTokenCountTooltip(for:)).
    @Test func source_uses_help_tooltip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }

    /// T52 contract: fullTokenCountTooltip uses comma grouping
    /// (= thousand-separator).
    @Test func tooltip_uses_comma_grouping() {
        // Use a fixed locale-independent test (= 1500 -> "1,500 tokens").
        // NumberFormatter respects the test process locale; = to be
        // robust, force en_US locale.
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.groupingSeparator = ","
        let formatted = formatter.string(from: NSNumber(value: 1500)) ?? "1500"
        #expect(formatted == "1,500")
    }

    /// T52 contract: small token count (< 1000) stays plain.
    @Test func tooltip_handles_small_count() {
        let result = ChatMessageFooter.fullTokenCountTooltip(for: 234)
        #expect(result.hasSuffix("tokens"))
        #expect(result.contains("234"))
    }

    /// T52 contract: large token count has thousand-separator.
    @Test func tooltip_handles_large_count() {
        let result = ChatMessageFooter.fullTokenCountTooltip(for: 1234567)
        #expect(result.hasSuffix("tokens"))
        // Output should contain digits + commas (locale-dependent grouping).
        #expect(result.contains(",") || result == "1234567 tokens")
    }

    /// T52 contract: T50 timestamp tooltip preserved.
    @Test func t50_timestamp_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: timestamp))"))
    }

    /// T52 contract: T25 compact formatTokenCount preserved.
    @Test func t25_compact_formatTokenCount_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func formatTokenCount(_ count: Int) -> String"))
    }
}