//
//  ChatMessagePartPlanTests.swift · Wenshu · T22-PLAN-PART (2026-09-18)
//
//  Verifies the new ChatMessagePart.Kind.plan case + the joinedPlan
//  helper. Strategy: pure-data tests on the enum (= no view
//  rendering; = the ChatPlanPartView render is exercised by
  // ChatPlanPartViewTests from T20b).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessagePart plan case (T22)")
struct ChatMessagePartPlanTests {

    /// T22 contract: ChatMessagePart.plan factory builds a part with
    /// .plan kind carrying the given Plan.
    @Test func plan_factory_creates_plan_kind() {
        let plan = Plan(
            query: "test query",
            steps: [
                PlanStep(index: 1, title: "Step 1", detail: "Do thing 1.")
            ],
            connectorID: "anthropic"
        )
        let part = ChatMessagePart.plan(plan)
        if case .plan(let extracted) = part.kind {
            #expect(extracted.query == "test query")
            #expect(extracted.connectorID == "anthropic")
            #expect(extracted.steps.count == 1)
        } else {
            Issue.record("expected .plan kind, got \(part.kind)")
        }
    }

    /// T22 contract: joinedPlan extracts the first plan from a
    /// parts array (= the canonical extraction helper).
    @Test func joined_plan_extracts_first_plan() {
        let plan = Plan(
            query: "extract me",
            steps: [],
            connectorID: "openai"
        )
        let parts: [ChatMessagePart] = [
            .text("preamble"),
            ChatMessagePart.plan(plan),
            .text("trailing text")
        ]
        let extracted = ChatMessagePart.joinedPlan(parts)
        #expect(extracted != nil)
        #expect(extracted?.query == "extract me")
    }

    /// T22 contract: joinedPlan returns nil when no plan part.
    @Test func joined_plan_returns_nil_for_no_plan() {
        let parts: [ChatMessagePart] = [
            .text("just text"),
            .reasoning("just reasoning")
        ]
        #expect(ChatMessagePart.joinedPlan(parts) == nil)
    }

    /// T22 contract: joinedText ignores plan parts (= plan content
    /// is NOT surfaced as text; = it goes through the plan renderer).
    @Test func joined_text_skips_plan_parts() {
        let plan = Plan(
            query: "ignored",
            steps: [PlanStep(index: 1, title: "ignored title", detail: "ignored detail")],
            connectorID: "gemini"
        )
        let parts: [ChatMessagePart] = [
            .text("visible "),
            ChatMessagePart.plan(plan),
            .text("end")
        ]
        let joined = ChatMessagePart.joinedText(parts)
        #expect(joined == "visible end")
        #expect(!joined.contains("ignored"))
    }

    /// T22 contract: joinedReasoning ignores plan parts (= the plan
    /// title should not appear as a "thought" block).
    @Test func joined_reasoning_skips_plan_parts() {
        let plan = Plan(
            query: "plan query",
            steps: [PlanStep(index: 1, title: "Not a thought", detail: "")],
            connectorID: "openai"
        )
        let parts: [ChatMessagePart] = [
            .reasoning("real thought"),
            ChatMessagePart.plan(plan)
        ]
        let joined = ChatMessagePart.joinedReasoning(parts)
        #expect(joined == "real thought")
        #expect(joined != "Not a thought")
    }
}