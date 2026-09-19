//
//  ChatMessageDayDividerDayIconTests.swift · Wenshu · T56-DAY-ICON (2026-09-18)
//
//  Verifies the small SF Symbol "calendar" prefix on the
//  day-divider label (= "📅 Today" / "📅 Mon 9/14").
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider day icon (T56)")
struct ChatMessageDayDividerDayIconTests {

    /// T56 contract: source uses Image(systemName: "calendar").
    @Test func source_uses_calendar_sf_symbol() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"calendar\")"))
    }

    /// T56 contract: calendar icon uses .caption2 + .secondary tone.
    @Test func calendar_icon_uses_caption2_secondary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let iconBlockStart = src.range(of: "Image(systemName: \"calendar\")")!
        let iconBlockEnd = src.range(of: ".foregroundStyle(.secondary)",
                                     range: iconBlockStart.upperBound..<src.endIndex)!.lowerBound
        let iconBlock = src[iconBlockStart.lowerBound..<iconBlockEnd]
        #expect(iconBlock.contains(".font(.caption2)"))
    }

    /// T56 contract: HStack now has spacing 6 (= the calendar
    /// icon and the label have a small gap between them).
    @Test func hstack_uses_spacing_6() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("HStack(spacing: 6) {"))
    }

    /// T56 contract: existing T36 label logic preserved.
    @Test func t36_label_logic_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
    }

    /// T56 contract: T39 .ultraThinMaterial background preserved.
    @Test func t39_material_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fill(.ultraThinMaterial)"))
    }

    /// T56 contract: shouldShowDayDivider ChatView logic still works
    /// (= the ChatView caller passes timestamp + the divider
    /// computes the label via WenshuI18n.t).
    @Test func chatview_caller_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains("ChatMessageDayDivider(timestamp: msg.timestamp.timeIntervalSince1970)"))
    }
}