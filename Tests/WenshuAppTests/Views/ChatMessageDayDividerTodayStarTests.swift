//
//  ChatMessageDayDividerTodayStarTests.swift · Wenshu · T60-TODAY-STAR (2026-09-18)
//
//  Verifies the small yellow star SF Symbol overlay on the
//  today's day-divider (= Apple HIG "current day" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider today star (T60)")
struct ChatMessageDayDividerTodayStarTests {

    /// T60 contract: source uses ZStack(alignment: .topTrailing) to
    /// overlay the star on top of the calendar icon.
    @Test func source_uses_zstack_overlay() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("ZStack(alignment: .topTrailing) {"))
    }

    /// T60 contract: star.fill SF Symbol used.
    @Test func source_uses_star_fill() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"star.fill\")"))
    }

    /// T60 contract: star only renders when isTodayLabel.
    @Test func star_only_renders_when_today() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("if isTodayLabel {\n                    Image(systemName: \"star.fill\")"))
    }

    /// T60 contract: star uses .yellow foregroundStyle (= the
    /// Apple HIG "current day" star color).
    @Test func star_uses_yellow() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".foregroundStyle(.yellow)"))
    }

    /// T60 contract: T57 accent tint preserved.
    @Test func t57_accent_tint_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("isTodayLabel ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary)"))
    }

    /// T60 contract: T56 calendar icon preserved.
    @Test func t56_calendar_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"calendar\")"))
    }

    /// T60 contract: T39 .ultraThinMaterial Capsule preserved.
    @Test func t39_material_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fill(.ultraThinMaterial)"))
    }
}