//
//  ChatPlanPartViewTests.swift · Wenshu · T20b-PLAN-UI (2026-09-18)
//
//  Verifies the ChatPlanPartView source contract (= the pure
//  view primitive; = ChatView wiring is T20c). Strategy: assert
//  the source contains the right modifiers / events (= can't
//  introspect @State / SwiftUI Value-typed views at runtime).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPlanPartView (T20b)")
struct ChatPlanPartViewTests {

    /// T20b contract: ChatPlanPartView renders the plan as a
    /// numbered step list.
    @Test func source_contains_plan_card_structure() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        // Header: list.bullet.rectangle icon + 'Plan: <query>'.
        #expect(source.contains("list.bullet.rectangle"))
        #expect(source.contains("Plan: \\(plan.query)"))
        // Connector ID label (= plan.connectorID displayed as
        // .tertiary caption2 = the canonical secondary metadata tone).
        #expect(source.contains("plan.connectorID"))
    }

    /// T20b contract: step row uses monospaced font for the
    /// index + title (= canonical code-block "step list" pattern).
    @Test func step_row_uses_monospaced() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        // The step row Text views use .monospaced.
        let monospacedCount = source.components(separatedBy: "design: .monospaced").count - 1
        #expect(monospacedCount >= 2, "expected >= 2 monospaced Text views, got \(monospacedCount)")
    }

    /// T20b contract: Approve & Run button present (= the user
    /// action that re-invokes the conductor with the plan).
    @Test func approve_button_present() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        #expect(source.contains("Approve & Run"))
        #expect(source.contains("onApprove(plan)"))
    }

    /// T20b contract: DisclosureGroup collapse/expand for the
    /// step list (= standard macOS expand/collapse pattern).
    @Test func disclosure_group_present() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        #expect(source.contains("DisclosureGroup(isExpanded:"))
    }
}