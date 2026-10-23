//
//  CoverMotionPlannerTests.swift · Wenshu
//
//  Proves the motion plan and the prompt it produces, WITHOUT a
//  network call.
//
//  The plan is what makes the clip the same picture rather than a
//  guess: it says which of the picture's objects a breeze may move
//  and which must hold still. So the tests read the plan the model
//  gives, and read the prompt that plan produces.
//
//  The answers the tests use are the ones the live endpoint gave on
//  2026-10-23, on the nine covers in the real library.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp

/// A connector that answers with whatever the test hands it.
private final class StubPlannerConnector: LLMConnector, @unchecked Sendable {

    let response: LLMResponse

    init(response: LLMResponse) {
        self.response = response
    }

    /// A response that answered.
    static func answered(text: String) -> LLMResponse {
        LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.thinking(text: "short reasoning", signature: nil), .text(text)],
            stopReason: .endTurn,
            usage: LLMUsage(inputTokens: 700, outputTokens: 1600)
        )
    }

    /// A response whose budget ran out before it answered.
    static func truncated() -> LLMResponse {
        LLMResponse(
            id: "stub",
            model: "stub",
            blocks: [.thinking(text: "reasoning that never ended", signature: nil)],
            stopReason: .maxTokens,
            usage: LLMUsage(inputTokens: 700, outputTokens: 2000)
        )
    }

    var connectorID: String { "stub" }
    var contextWindow: Int { 200_000 }

    func send(messages: [LLMMessage], options: LLMCallOptions) async throws -> LLMResponse {
        response
    }

    nonisolated func stream(messages: [LLMMessage], options: LLMCallOptions) -> AsyncStream<LLMBlock> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@Suite("Cover motion plan")
struct CoverMotionPlannerTests {

    /// The answer the live endpoint gave for the Rain Water cover.
    private let rainWaterAnswer = """
        {"picture":"a Chinese ink-and-colour still life of Rain Water objects on a pale ground",\
        "items":[\
        {"motif":"closed umbrella","thing":"the closed oil-paper umbrella in the centre","moves":false,"kind":"solid"},\
        {"motif":"sprout branch","thing":"the budding branch on the left","moves":true,"kind":"plant"},\
        {"motif":"clay doll","thing":"the coloured clay figurine on the right","moves":false,"kind":"solid"},\
        {"motif":"silk knot","thing":"the red silk knot on the right","moves":true,"kind":"light"}],\
        "wind":"A light breeze comes from the left and passes rightward, stirring the budding branch and red silk knot while the umbrella and clay figurine remain still."}
        """

    /// A planner over a stub connector.
    private func planner(_ connector: StubPlannerConnector) -> CoverMotionPlanner {
        CoverMotionPlanner(
            providerSlug: { "minimax-cn" },
            modelSlug: { "MiniMax-M3.1-Flash" },
            connectorFor: { _ in connector }
        )
    }

    /// The motifs of the Rain Water cover.
    private func rainWaterMotifs() -> CoverMotifs {
        CoverMotifs(
            register: "中式",
            style: "雨水节气民俗陈设",
            brush: "工笔重彩笔触",
            motifs: ["闭合油纸伞", "新芽枝", "彩泥偶", "红绸结"],
            arrangement: "闭合油纸伞居中，新芽枝在左，彩泥偶与红绸结置右。",
            palette: ["嫩绿", "朱红", "靛青"],
            mood: ["润泽", "祈福"]
        )
    }

    // MARK: - Reading the plan

    @Test("The plan is read from the model's answer")
    func thePlanIsReadFromTheAnswer() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        #expect(plan.items.count == 4)
        #expect(plan.moving.count == 2)
        #expect(plan.holding.count == 2)
        #expect(plan.moving.map(\.thing) == [
            "the budding branch on the left",
            "the red silk knot on the right"
        ])
        #expect(plan.holding.map(\.thing) == [
            "the closed oil-paper umbrella in the centre",
            "the coloured clay figurine on the right"
        ])
        #expect(plan.picture.contains("still life"))
        #expect(plan.wind.contains("light breeze"))
    }

    @Test("An answer with no JSON is unreadable")
    func anAnswerWithNoJSONIsUnreadable() {
        #expect(throws: CoverMotionError.self) {
            try CoverMotionPlanner.parse("there is nothing here")
        }
    }

    @Test("An answer with no items is unreadable")
    func anAnswerWithNoItemsIsUnreadable() {
        #expect(throws: CoverMotionError.self) {
            try CoverMotionPlanner.parse(#"{"picture":"a still life","items":[],"wind":"a breeze"}"#)
        }
    }

    @Test("An answer with no wind is unreadable")
    func anAnswerWithNoWindIsUnreadable() {
        #expect(throws: CoverMotionError.self) {
            try CoverMotionPlanner.parse(#"{"picture":"a still life","items":[{"motif":"a","thing":"a bowl","moves":true}],"wind":""}"#)
        }
    }

    @Test("An answer wrapped in prose is still read")
    func anAnswerWrappedInProseIsStillRead() throws {
        let wrapped = "Here you go:\n\(rainWaterAnswer)\nHope that helps."

        let plan = try CoverMotionPlanner.parse(wrapped)

        #expect(plan.items.count == 4)
    }

    // MARK: - Planning over the chat model

    @Test("A cut-off answer is reported as cut off")
    func aCutOffAnswerIsReportedAsCutOff() async {
        let subject = planner(StubPlannerConnector(response: StubPlannerConnector.truncated()))

        do {
            _ = try await subject.plan(motifs: rainWaterMotifs())
            Issue.record("The planning answered when the model ran out of budget")
        } catch let error as CoverMotionError {
            // The gap: before the fix this was an unreadable answer
            // with an EMPTY string, which reads like the model wrote
            // nonsense.
            guard case .answerTruncated = error else {
                Issue.record("Expected a truncated answer, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected a CoverMotionError, got \(error)")
        }
    }

    @Test("The planning asks for a budget the thinking fits in")
    func thePlanningAsksForABudgetTheThinkingFitsIn() {
        // Measured 2026-10-23: at 2000 the whole budget went to the
        // thinking and the answer never arrived.
        #expect(CoverMotionPlanner.answerTokenBudget >= 8000)
    }

    @Test("The question carries the card's own motifs")
    func theQuestionCarriesTheMotifs() {
        let question = CoverMotionPlanner.question(for: rainWaterMotifs())

        #expect(question.contains("闭合油纸伞"))
        #expect(question.contains("新芽枝"))
        #expect(question.contains("雨水节气民俗陈设"))
    }

    // MARK: - The prompt the plan produces

    @Test("The prompt names the moving things and the holding things")
    func thePromptNamesBothLists() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan)

        #expect(prompt.contains("the budding branch on the left"))
        #expect(prompt.contains("the red silk knot on the right"))
        #expect(prompt.contains("the closed oil-paper umbrella in the centre"))
        #expect(prompt.contains("the coloured clay figurine on the right"))
        #expect(prompt.contains("These move, and only these move:"))
        #expect(prompt.contains("These do not move at all:"))
    }

    @Test("The prompt locks the camera")
    func thePromptLocksTheCamera() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan)

        #expect(prompt.hasPrefix(CoverMotionPrompt.fixedCameraInstruction))
        #expect(prompt.lowercased().contains("camera is completely locked"))
    }

    @Test("The prompt carries the picture's own description")
    func thePromptCarriesThePictureDescription() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan)

        // The art direction draws in three cultures, so the prompt
        // must not hardcode one.
        #expect(prompt.contains(plan.picture))
    }

    @Test("A plan where nothing moves keeps the wind and drops the list")
    func aPlanWhereNothingMovesDropsTheList() throws {
        let plan = try CoverMotionPlanner.parse("""
            {"picture":"a Chinese ink-and-colour still life of scholar's objects on a pale ground",\
            "items":[\
            {"motif":"a","thing":"the dark inkstone on the left","moves":false,"kind":"solid"},\
            {"motif":"b","thing":"the celadon brush pot on the right","moves":false}],\
            "wind":"A faint breeze crosses the desk as the light drifts slowly across the paper."}
            """)

        let prompt = CoverMotionPrompt.make(plan: plan)

        #expect(!prompt.contains("These move, and only these move:"))
        #expect(prompt.contains("These do not move at all:"))
        // The wind carries the movement when nothing can move.
        #expect(prompt.contains("the light drifts slowly across the paper"))
    }

    @Test("A plan where everything moves drops the holding list")
    func aPlanWhereEverythingMovesDropsTheHoldingList() throws {
        let plan = try CoverMotionPlanner.parse("""
            {"picture":"a still life of leaves",\
            "items":[{"motif":"a","thing":"the leafy branch on the left","moves":true,"kind":"plant"}],\
            "wind":"A light breeze stirs the leaves."}
            """)

        let prompt = CoverMotionPrompt.make(plan: plan)

        #expect(prompt.contains("These move, and only these move:"))
        #expect(!prompt.contains("These do not move at all:"))
    }

    @Test("The same plan always gives the same prompt")
    func theSamePlanAlwaysGivesTheSamePrompt() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        #expect(CoverMotionPrompt.make(plan: plan) == CoverMotionPrompt.make(plan: plan))
    }

    // MARK: - The strict constraints

    @Test("The light cannot change")
    func theLightCannotChange() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan).lowercased()

        // A measured draw turned the pale paper into a wall and a
        // table with a hard beam of window light, so the light
        // changed and the prompt did not stop it.
        #expect(prompt.contains("the light does not change"))
        #expect(prompt.contains("no new light"))
        #expect(prompt.contains("no shadow moves"))
        #expect(prompt.contains("no beam of sunlight"))
    }

    @Test("The colour temperature cannot change")
    func theColourTemperatureCannotChange() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan).lowercased()

        #expect(prompt.contains("the colour temperature does not change"))
        #expect(prompt.contains("nothing warms up"))
        #expect(prompt.contains("no hue shifts"))
    }

    @Test("The camera cannot roll or zoom either")
    func theCameraCannotRollOrZoom() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan).lowercased()

        // The measured move was a sideways pan and a push, and
        // neither word was in the list.
        #expect(prompt.contains("no roll"))
        #expect(prompt.contains("no zoom"))
    }

    @Test("The movement carries a magnitude, not a mood")
    func theMovementCarriesAMagnitude() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan).lowercased()

        #expect(prompt.contains("a few millimetres at most"))
        #expect(prompt.contains("barely perceptible"))
        #expect(prompt.contains("never a sweep"))
        #expect(prompt.contains("never a swing"))
    }

    @Test("Only the named things move")
    func onlyTheNamedThingsMove() throws {
        let plan = try CoverMotionPlanner.parse(rainWaterAnswer)

        let prompt = CoverMotionPrompt.make(plan: plan)

        #expect(prompt.contains("These move, and only these move:"))
        #expect(prompt.contains("These do not move at all:"))
    }

    @Test("The planner is told to use the small words and to leave the light alone")
    func thePlannerIsToldToUseTheSmallWords() {
        let prompt = CoverMotionPlanner.prompt.lowercased()

        // The wind sentence is the ACTION as far as the endpoint is
        // concerned, so a grand word in it asks for the camera move
        // the fixed part forbids.
        #expect(prompt.contains("small words"))
        #expect(prompt.contains("a few millimetres"))
        #expect(prompt.contains("never in the grand ones"))
        #expect(prompt.contains("must not mention the light"))
    }
}
