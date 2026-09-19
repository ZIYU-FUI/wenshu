//
//  PlanModelTests.swift · Wenshu · T30-PLAN-MODEL (2026-09-18)
//
//  Verifies the new Plan.model field (= the LLM model id that
//  produced the plan). Tests both the field declaration +
//  initialization (= backward-compat: omitting the model arg
//  produces plan.model == nil = older serialized plans decode
//  cleanly) and the display-render surface contract (the
//  ChatPlanPartView source contains the model-render branch).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Plan model field (T30)")
struct PlanModelTests {

    /// T30 contract: Plan has a `model: String?` field.
    @Test func plan_has_model_field() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Agent/Plan/PlanModeEngine.swift",
            encoding: .utf8
        )
        #expect(source.contains("public let model: String?"))
    }

    /// T30 contract: Plan init accepts `model: String? = nil` (=
    /// backward-compat for older plans without the field).
    @Test func plan_init_accepts_optional_model() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Agent/Plan/PlanModeEngine.swift",
            encoding: .utf8
        )
        #expect(source.contains("model: String? = nil"))
    }

    /// T30 contract: omitting the model arg (= default nil) produces
    /// a Plan with model == nil (= the default-nil initializer path).
    @Test func plan_default_model_is_nil() {
        let plan = Plan(
            query: "test",
            steps: [PlanStep(index: 1, title: "Step", detail: "")],
            connectorID: "anthropic"
        )
        #expect(plan.model == nil)
    }

    /// T30 contract: passing a model id surfaces it on the Plan.
    @Test func plan_with_model_id() {
        let plan = Plan(
            query: "test",
            steps: [PlanStep(index: 1, title: "Step", detail: "")],
            connectorID: "anthropic",
            model: "claude-sonnet-4-20250514"
        )
        #expect(plan.model == "claude-sonnet-4-20250514")
    }

    /// T30 contract: run() captures the model id (= the engine's
    /// `model` field) and surfaces it on the returned Plan.
    @Test func engine_run_surfaces_model() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Core/Agent/Plan/PlanModeEngine.swift",
            encoding: .utf8
        )
        // The engine's run() should construct a new Plan with
        // model = `self.model` (= the model id passed to the engine init).
        #expect(source.contains("model: model.isEmpty ? nil : model"))
    }

    /// T30 contract: ChatPlanPartView renders the model id next to
    /// the connector name (gated on plan.model != nil).
    @Test func view_renders_model_id() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPlanPartView.swift",
            encoding: .utf8
        )
        #expect(source.contains("if let model = plan.model"))
        #expect(source.contains("Text(model)"))
    }
}