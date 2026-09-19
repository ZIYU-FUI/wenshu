//
//  ChatMessageViewPlanBadgeTests.swift · Wenshu · T23-PLAN-BADGE (2026-09-18)
//
//  Verifies the PLAN badge shown next to the source label when
//  the message has a .plan part. Strategy: source-inspection (=
//  SwiftUI value-typed views can't be introspected at runtime
//  without an NSHostingView).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView PLAN badge (T23)")
struct ChatMessageViewPlanBadgeTests {

    /// T23 contract: ChatMessageView source contains the PLAN
    /// badge Text (= with the T28 hover-expand ternary).
    @Test func source_contains_plan_badge_text() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // T28-PLAN-BADGE-EXPAND made the badge text a hover-state
        // ternary; = the literal "PLAN" still appears in the
        // non-hovered branch (= preserved from T23).
        #expect(source.contains("\"PLAN\""))
    }

    /// T23 contract: the badge appears ONLY when the message has
    /// a .plan part (= messageHasPlanPart guard).
    @Test func badge_gated_on_plan_part() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("messageHasPlanPart"))
        #expect(source.contains("if messageHasPlanPart"))
    }

    /// T23 contract: messageHasPlanPart checks for .plan case.
    @Test func message_has_plan_part_check() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("if case .plan = part.kind { return true }"))
    }

    /// T23 contract: PLAN badge uses Color.accentColor (= semantic
    /// Apple HIG accent = matches user's accent setting).
    @Test func badge_uses_accent_color() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Both .foregroundStyle + the overlay border use accent.
        let accentUses = source.components(separatedBy: "Color.accentColor").count - 1
        #expect(accentUses >= 2, "expected >= 2 Color.accentColor uses (= foreground + border)")
    }
}