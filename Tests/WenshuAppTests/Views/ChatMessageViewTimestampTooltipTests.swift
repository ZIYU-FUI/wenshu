//
//  ChatMessageViewTimestampTooltipTests.swift · Wenshu · T50-TIMESTAMP-TOOLTIP (2026-09-18)
//
//  Verifies the fullTimestampTooltip helper + the .help() tooltip
//  wiring on the timestamp text in ChatMessageView.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView timestamp tooltip (T50)")
struct ChatMessageViewTimestampTooltipTests {

    /// T50 contract: source uses .help(Self.fullTimestampTooltip(for:))
    @Test func source_uses_help_tooltip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: message.timestamp))"))
    }

    /// T50 contract: fullTimestampTooltip function exists + nonisolated.
    @Test func fullTimestampTooltip_helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func fullTimestampTooltip(for date: Date) -> String"))
    }

    /// T50 contract: fullTimestampTooltip returns ISO-style date.
    @Test func fullTimestampTooltip_returns_iso_format() {
        // Build a fixed date: 2026-09-18 14:32:05 UTC
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 18
        components.hour = 14
        components.minute = 32
        components.second = 5
        components.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            Issue.record("failed to build date")
            return
        }
        let tooltip = ChatMessageView.fullTimestampTooltip(for: date)
        // The exact output depends on the system time zone; = we just
        // verify the format shape (= yyyy-MM-dd HH:mm:ss = 19 chars).
        #expect(tooltip.count == 19)
        #expect(tooltip.contains("-"))
        #expect(tooltip.contains(":"))
    }

    /// T50 contract: T26 hover timestamp logic preserved.
    @Test func t26_hover_timestamp_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var timestampDisplayFormat: Date.FormatStyle"))
        // T65 wrapped the timestamp Text inside an HStack = .onHover
        // is now nested deeper.
        #expect(src.contains(".onHover { hovering in") && src.contains("isTimestampHovered = hovering"))
    }

    /// T50 contract: T25 token footer preserved.
    @Test func t25_token_footer_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCount(tokens)"))
    }
}