//
//  CoverArtDirectionTests.swift · Wenshu
//
//  Proves the art direction is ONE constant, applied in ONE order.
//
//  The point of this test is the last one: the art-direction text is
//  asserted BYTE-IDENTICAL to the text the cover pipeline was
//  verified against on 2026-10-22. If someone edits the style in
//  place, the whole material zone's visual language changes, and
//  this test is what says no.
//
//  The first two tests are the order tests: the style comes before
//  the subject, so the model reads the look before it reads what to
//  draw.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover art direction")
struct CoverArtDirectionTests {

    @Test("The art direction comes first and the subject last")
    func joinsStyleBeforeSubject() {
        let prompt = CoverArtDirection.prompt(subject: "A lighthouse on a cliff at dusk")

        #expect(prompt.hasPrefix(CoverArtDirection.style))
        #expect(prompt.hasSuffix("A lighthouse on a cliff at dusk"))
        #expect(prompt.count > CoverArtDirection.style.count)
    }

    @Test("An empty subject still yields the art direction")
    func emptySubjectKeepsTheStyle() {
        let prompt = CoverArtDirection.prompt(subject: "   ")

        #expect(prompt == CoverArtDirection.style)
    }

    @Test("The style text is byte-identical to the verified one")
    func styleIsTheVerifiedText() {
        let expected = """
            Create original bright whimsical hand-painted fantasy trading-card key \
            art with playful tavern-card-game energy; never imitate an existing \
            franchise, character, card frame, logo or official illustration. Use \
            broad painterly brushwork, saturated warm color masses, rich \
            midtones, tactile painted materials, lively fantasy worldbuilding \
            and a confident illustrative finish. Wide cinematic banner framing, \
            the subject centered with generous headroom on both sides, designed \
            to be cropped to a wide strip without losing the subject.
            """

        #expect(CoverArtDirection.style == expected)
    }
}
