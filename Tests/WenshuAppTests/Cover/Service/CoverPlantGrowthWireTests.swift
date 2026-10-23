//
//  CoverPlantGrowthWireTests.swift · Wenshu
//
//  The plant rule, tested through the WIRE only.
//
//  This file deliberately uses NO new API (= no `movability:` argument,
//  no `mover`), so it still COMPILES against the production code that
//  predates the rule. That is what makes it a gate: restore the old
//  production files and this test FAILS on an ASSERTION (= the rule
//  is not there), rather than failing to build.
//
//  A test that cannot compile against the old code proves nothing.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover plant growth over the wire")
struct CoverPlantGrowthWireTests {

    /// A plan that says the picture has a plant in it.
    private let answerWithAPlant = """
        {"picture":"a Chinese ink-and-colour still life on a pale ground",\
        "items":[\
        {"motif":"sprout branch","thing":"the budding branch on the left","moves":true,"kind":"plant"},\
        {"motif":"silk knot","thing":"the red silk knot on the right","moves":true,"kind":"light"}],\
        "wind":"A light breeze comes from the left and passes rightward."}
        """

    @Test("A plan that says there is a plant gets a growth animation")
    func aPlanWithAPlantGetsAGrowthAnimation() throws {
        let plan = try CoverMotionPlanner.parse(answerWithAPlant)

        let prompt = CoverMotionPrompt.make(plan: plan)

        // The plant is the one that moves, and it GROWS.
        #expect(prompt.contains("These move, and only these move: the budding branch on the left"))
        #expect(prompt.contains("It GROWS"))
        // The other light thing holds still, so the clip has ONE
        // animation and not two.
        #expect(prompt.contains("These do not move at all: the red silk knot on the right"))
    }
}
