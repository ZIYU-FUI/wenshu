//
//  ChatMessageDayDividerTodayAccentTests.swift · Wenshu · T57-TODAY-ACCENT (2026-09-18)
//
//  Verifies the calendar icon's accent-color tint when the
//  label is "Today" (= visual emphasis for the current day).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider today accent (T57)")
struct ChatMessageDayDividerTodayAccentTests {

    /// T57 contract: source uses isTodayLabel to drive icon tint.
    @Test func source_uses_isTodayLabel_for_tint() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("isTodayLabel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary)"))
    }

    /// T57 contract: isTodayLabel computed property exists.
    @Test func isTodayLabel_property_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var isTodayLabel: Bool {"))
    }

    /// T57 contract: isTodayLabel compares label to the resolved
    /// "Today" i18n key (= locale-safe comparison).
    @Test func isTodayLabel_compares_to_localized_today() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("let todayKey = WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("return label == todayKey"))
    }

    /// T57 contract: T56 calendar icon preserved.
    @Test func t56_calendar_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"calendar\")"))
    }

    /// T57 contract: T36 label logic preserved (= all 5 branches).
    @Test func t36_label_branches_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
        #expect(src.contains("setLocalizedDateFormatFromTemplate(\"E\")"))
        #expect(src.contains("setLocalizedDateFormatFromTemplate(isSameYear ? \"MMMd\" : \"yMMMd\")"))
    }

    /// T57 contract: T39 .ultraThinMaterial Capsule preserved.
    @Test func t39_material_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fill(.ultraThinMaterial)"))
    }
}