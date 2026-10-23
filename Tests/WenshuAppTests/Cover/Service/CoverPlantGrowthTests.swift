//
//  CoverPlantGrowthTests.swift · Wenshu
//
//  Proves the rule the user asked for: a picture with a plant gets a
//  plant-GROWTH animation, and only a picture with no plant lets
//  something else move.
//
//  The user's words, in English: it is not "the plant moves first",
//  it is "when the picture has a plant, make a plant-GROWTH
//  animation". The animation is the plant's growth, not a plant that
//  sways.
//
//  The growth has to stay a CYCLE, because the clip ends on the
//  picture it started from: the endpoint is given the same still as
//  the first and the last frame, so the model has to come back. A
//  growth that unwound would be a rewind, and a rewind is worse than
//  a seam.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover plant growth")
struct CoverPlantGrowthTests {

    /// A plan with a branch and a knot.
    private func planWithAPlant() -> CoverMotionPlan {
        CoverMotionPlan(
            picture: "a Chinese ink-and-colour still life on a pale ground",
            items: [
                CoverMotionPlan.Item(
                    motif: "sprout branch",
                    thing: "the budding branch on the left",
                    moves: true,
                    movability: .plant
                ),
                CoverMotionPlan.Item(
                    motif: "silk knot",
                    thing: "the red silk knot on the right",
                    moves: true,
                    movability: .light
                ),
                CoverMotionPlan.Item(
                    motif: "clay doll",
                    thing: "the coloured clay figurine on the right",
                    moves: false,
                    movability: .solid
                )
            ],
            wind: "A light breeze comes from the left and passes rightward."
        )
    }

    /// A plan with nothing living in it.
    private func planWithoutAPlant() -> CoverMotionPlan {
        CoverMotionPlan(
            picture: "a Shang bronze still life on a pale ground",
            items: [
                CoverMotionPlan.Item(
                    motif: "bronze pig",
                    thing: "the bronze pig-shaped vessel on the left",
                    moves: false,
                    movability: .solid
                ),
                CoverMotionPlan.Item(
                    motif: "silk cord",
                    thing: "the hanging silk cord in the centre",
                    moves: true,
                    movability: .light
                )
            ],
            wind: "A light breeze enters from the left."
        )
    }

    @Test("A picture with a plant moves the plant")
    func aPictureWithAPlantMovesThePlant() {
        let plan = planWithAPlant()

        #expect(plan.mover?.thing == "the budding branch on the left")
    }

    @Test("A picture without a plant moves the lightest thing")
    func aPictureWithoutAPlantMovesTheLightestThing() {
        let plan = planWithoutAPlant()

        #expect(plan.mover?.thing == "the hanging silk cord in the centre")
    }

    @Test("A picture with nothing movable moves nothing")
    func aPictureWithNothingMovableMovesNothing() {
        let plan = CoverMotionPlan(
            picture: "a Shang bronze still life on a pale ground",
            items: [
                CoverMotionPlan.Item(
                    motif: "bronze pig",
                    thing: "the bronze pig-shaped vessel on the left",
                    moves: false,
                    movability: .solid
                )
            ],
            wind: "A light breeze enters from the left and crosses the ground."
        )

        #expect(plan.mover == nil)
    }

    @Test("A plan written before the classification moves nothing")
    func aPlanWrittenBeforeTheClassificationMovesNothing() {
        // The safe default is `solid`: a plan that does not say must
        // never invent a mover.
        let plan = CoverMotionPlan(
            picture: "a still life on a pale ground",
            items: [
                CoverMotionPlan.Item(
                    motif: "branch",
                    thing: "the branch on the left",
                    moves: true
                )
            ],
            wind: "A light breeze comes from the left."
        )

        #expect(plan.items[0].movability == .solid)
        #expect(plan.mover == nil)
    }

    @Test("The prompt says the plant grows")
    func thePromptSaysThePlantGrows() {
        let prompt = CoverMotionPrompt.make(plan: planWithAPlant())

        #expect(prompt.contains("These move, and only these move: the budding branch on the left"))
        #expect(prompt.contains("It GROWS"))
        #expect(prompt.contains("settles back to where it started"))
        // And the growth is NOT a sway: the sway wording would
        // contradict it.
        #expect(!prompt.contains("barely perceptible sway that drifts"))
    }

    @Test("The prompt holds everything that is not the mover")
    func thePromptHoldsEverythingElse() {
        let prompt = CoverMotionPrompt.make(plan: planWithAPlant())

        #expect(prompt.contains("the red silk knot on the right"))
        #expect(prompt.contains("the coloured clay figurine on the right"))
        // The knot held still, so it is not in the moving line.
        #expect(!prompt.contains("These move, and only these move: the budding branch on the left; the red silk knot"))
    }

    @Test("A picture without a plant gets the movement wording, not the growth one")
    func aPictureWithoutAPlantGetsTheMovementWording() {
        let prompt = CoverMotionPrompt.make(plan: planWithoutAPlant())

        #expect(prompt.contains("These move, and only these move: the hanging silk cord in the centre"))
        #expect(!prompt.contains("It GROWS"))
        #expect(prompt.contains("barely perceptible sway"))
    }

    @Test("The planner asks for the plant growth")
    func thePlannerAsksForThePlantGrowth() {
        let prompt = CoverMotionPlanner.prompt

        #expect(prompt.contains("\"plant\""))
        #expect(prompt.contains("THE PLANT IS THE ONE THAT MOVES"))
        #expect(prompt.contains("it GROWS"))
    }

    @Test("A plan reads the classification off the wire")
    func aPlanReadsTheClassificationOffTheWire() throws {
        let answer = """
            {"picture":"a still life on a pale ground",\
            "items":[\
            {"motif":"branch","thing":"the budding branch on the left","moves":true,"kind":"plant"},\
            {"motif":"censer","thing":"the rear censer","moves":true,"kind":"air"},\
            {"motif":"book","thing":"the closed book","moves":false,"kind":"solid"}],\
            "wind":"A light breeze comes from the left."}
            """

        let plan = try CoverMotionPlanner.parse(answer)

        #expect(plan.items.map(\.movability) == [.plant, .air, .solid])
        #expect(plan.mover?.thing == "the budding branch on the left")
    }
}
