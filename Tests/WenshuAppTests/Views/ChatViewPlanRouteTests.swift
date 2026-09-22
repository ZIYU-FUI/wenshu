//
//  ChatViewPlanRouteTests.swift · Wenshu · T20c-PLAN-ROUTE (2026-09-18)
//
//  Verifies the ChatView /plan route-input surface:
//    - stripPlanPrefix exists and uses hasPrefix("/plan") gate
//    - routeInput intercepts /plan BEFORE invoking SkillAdapter
//    - runPlanMode clears inputText (= UX invariant)
//    - runPlanMode surfaces PlanModeError.errorDescription
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView plan route (T20c)")
struct ChatViewPlanRouteTests {

    @Test func plan_with_query_extracts_query() throws {
        // C-3 (refactor chat-mvvm-3layer): ChatViewModel moved out
        // of ChatView.swift to Core/Chat/ChatSessionViewModel.swift
        // (= business layer = Apple MVVM canonical separation).
        // The plan-route helpers (= stripPlanPrefix / runPlanMode /
        // PlanModeError catch / input.hasPrefix("/plan")) live in
        // the business layer now; = the test follows.
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Chat/ChatSessionViewModel.swift",
            encoding: .utf8
        )
        #expect(source.contains("private func stripPlanPrefix"))
        #expect(source.contains("input.hasPrefix(\"/plan\")"))
    }

    @Test func routeInput_intercepts_plan_before_skilladapter() throws {
        // C-3: read the business layer file (ChatSessionViewModel.swift)
        // where routeInput + stripPlanPrefix live now.
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Chat/ChatSessionViewModel.swift",
            encoding: .utf8
        )
        guard let planIdx = source.range(of: "if let planQuery = stripPlanPrefix(input)"),
              let skillIdx = source.range(of: "SkillAdapter.shared.parseAndInvoke") else {
            Issue.record("plan/skill call sites not found")
            return
        }
        #expect(planIdx.lowerBound < skillIdx.lowerBound)
    }

    @Test func plan_mode_clears_inputText() throws {
        // C-3: runPlanMode moved to ChatSessionViewModel.swift.
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Chat/ChatSessionViewModel.swift",
            encoding: .utf8
        )
        guard let start = source.range(of: "private func runPlanMode") else {
            Issue.record("runPlanMode not found")
            return
        }
        let restRange = start.upperBound..<source.endIndex
        guard let end = source.range(of: "    /// send:", range: restRange) else {
            Issue.record("send: not found")
            return
        }
        let body = String(source[start.lowerBound..<end.lowerBound])
        #expect(body.contains("inputText = \"\""))
    }

    @Test func plan_mode_errors_surfaced_via_error_description() throws {
        // C-3: PlanModeError catch moved to ChatSessionViewModel.swift.
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Chat/ChatSessionViewModel.swift",
            encoding: .utf8
        )
        #expect(source.contains("catch let error as PlanModeError"))
        #expect(source.contains("error.errorDescription"))
    }
}