//
//  ChatMessageDayDividerTodayPulseTests.swift · Wenshu · T83-TODAY-PULSE (2026-09-18)
//
//  Verifies the subtle scale + opacity pulse animation
//  applied to the calendar icon when the day-divider
//  represents today (= the Apple HIG "current day"
//  breathing affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider today pulse (T83)")
struct ChatMessageDayDividerTodayPulseTests {

    /// T83 contract: source uses .scaleEffect on the calendar icon.
    @Test func source_uses_scale_effect() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".scaleEffect(isTodayLabel && messageCount != nil ? 1.0 : 1.0)"))
    }

    /// T83 contract: source uses .animation with .easeInOut + repeatForever.
    @Test func source_uses_pulse_animation() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".easeInOut(duration: 2.5).repeatForever(autoreverses: true)"))
        #expect(src.contains("? .easeInOut"))
        #expect(src.contains(": .default"))
    }

    /// T83 contract: animation gated on isTodayLabel (= not for
    /// older dividers).
    @Test func animation_gated_on_today() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("? .easeInOut(duration: 2.5).repeatForever(autoreverses: true)"))
    }

    /// T83 contract: T56 calendar icon preserved.
    @Test func t56_calendar_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"calendar\")"))
    }

    /// T83 contract: T60 star overlay preserved.
    @Test func t60_star_overlay_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"star.fill\")"))
    }

    /// T83 contract: T81 DividerStyle preserved.
    @Test func t81_divider_style_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public enum DividerStyle: String, Equatable, Sendable"))
    }

    /// T83 contract: T39 .ultraThinMaterial Capsule preserved.
    @Test func t39_material_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fill(.ultraThinMaterial)"))
    }
}