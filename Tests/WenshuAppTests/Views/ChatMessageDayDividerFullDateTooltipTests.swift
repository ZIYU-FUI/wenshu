//
//  ChatMessageDayDividerFullDateTooltipTests.swift · Wenshu · T98-FULL-DATE-TOOLTIP (2026-09-18)
//
//  Verifies the fullDateTooltip static helper + the
//  .help() wiring on the day-divider label text.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider full date tooltip (T98)")
struct ChatMessageDayDividerFullDateTooltipTests {

    /// T98 contract: T98 marker comment exists.
    @Test func t98_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T98-FULL-DATE-TOOLTIP (2026-09-18)"))
    }

    /// T98 contract: fullDateTooltip static helper exists.
    @Test func full_date_tooltip_helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public static func fullDateTooltip(for timestamp: TimeInterval) -> String"))
        #expect(src.contains("Date(timeIntervalSince1970: timestamp)"))
        #expect(src.contains("Date.FormatStyle.dateTime"))
    }

    /// T98 contract: .help() wired on Text(label).
    @Test func help_wired_on_text_label() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let labelPos = src.range(of: "Text(label)")!
        let after = src[labelPos.upperBound...]
        #expect(after.contains(".help(Self.fullDateTooltip(for: timestamp))"))
    }

    /// T98 contract: T68 count divider preserved.
    @Test func t68_count_divider_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public static func countOnly(_ count: Int) -> ChatMessageDayDivider"))
        #expect(src.contains("messageCount"))
    }

    /// T98 contract: T36 i18n keys preserved.
    @Test func t36_i18n_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
    }

    /// T98 contract: T97 live dot preserved.
    @Test func t97_live_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T97-LIVE-DOT (2026-09-18)"))
        #expect(src.contains(".foregroundStyle(.green)"))
    }

    /// T98 contract: T81 DividerStyle preserved.
    @Test func t81_divider_style_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public enum DividerStyle: String, Equatable, Sendable"))
    }

    /// T98 contract: T56 calendar icon preserved.
    @Test func t56_calendar_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"calendar\")"))
    }
}