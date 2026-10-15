//
//  ChatMessageViewPlanApproveTests.swift · Wenshu · T24-PLAN-APPROVE (2026-09-18)
//
//  Verifies that ChatMessageView accepts and threads the
//  onApprovePlan closure down to ChatMessageBodyView (-> ChatPartRow
//  -> ChatPlanPartView). Strategy: source-inspection (= SwiftUI
//  value-typed views can't be introspected at runtime).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView plan approve closure (T24)")
struct ChatMessageViewPlanApproveTests {

    @Test func source_contains_onApprovePlan_property() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("let onApprovePlan: ((Plan) -> Void)?"))
    }

    @Test func init_accepts_onApprovePlan() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("onApprovePlan: ((Plan) -> Void)? = nil"))
    }

    @Test func bodyview_call_forwards_onApprovePlan() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("onApprovePlan: onApprovePlan"))
    }

    @Test func chatview_passes_real_closure() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(source.contains("onApprovePlan: { plan in"))
        #expect(source.contains("vm.inputText = plan.query"))
        #expect(source.contains("Task { await vm.send() }"))
    }
}