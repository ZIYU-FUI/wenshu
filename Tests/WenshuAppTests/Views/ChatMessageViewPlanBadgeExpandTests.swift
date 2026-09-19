//
//  ChatMessageViewPlanBadgeExpandTests.swift · Wenshu · T28-PLAN-BADGE-EXPAND (2026-09-18)
//
//  Verifies the PLAN badge hover-expand affordance:
//  - @State isPlanBadgeHovered exists at struct level
//  - badge text uses isPlanBadgeHovered ternary
//  - planStepCountLabel helper extracts step count from the first
//    .plan part (= returns "N steps" or "1 step" for singular)
//  - .onHover wires the badge to update the @State
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView plan badge expand (T28)")
struct ChatMessageViewPlanBadgeExpandTests {

    /// T28 contract: @State isPlanBadgeHovered exists.
    @Test func state_exists() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("@State private var isPlanBadgeHovered: Bool = false"))
    }

    /// T28 contract: badge text uses the hover-state ternary
    /// (= "PLAN" when not hovered, "PLAN · N steps" when hovered).
    @Test func badge_text_uses_hover_state() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("Text(isPlanBadgeHovered\n                                 ? \"PLAN · \\(planStepCountLabel)\"\n                                 : \"PLAN\")"))
    }

    /// T28 contract: .onHover modifier wired on the badge.
    @Test func on_hover_wired_on_badge() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".onHover { hovering in\n                                    isPlanBadgeHovered = hovering\n                                }"))
    }

    /// T28 contract: planStepCountLabel extracts the .plan part's
    /// step count (= "N steps" plural, "1 step" singular).
    @Test func planStepCountLabel_helper() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("private var planStepCountLabel: String"))
        #expect(source.contains("p.steps.count"))
        #expect(source.contains("\"\\(n) step\\(n == 1 ? \"\" : \"s\")\""))
    }
}