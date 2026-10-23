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

    @Test("The style text is byte-identical to the one that was checked")
    func styleIsTheVerifiedText() {
        let expected = """
            Create original bright whimsical hand-painted Chinese-style fantasy \
            scroll paintings with playful tavern-card-game energy; never imitate \
            an existing franchise, character, card frame, logo or official \
            illustration. Render the subject as one dimensional layered scroll \
            painting, softly embossed and built from a few clear planes of depth, \
            floating on a clean pale cream ground with generous empty space on \
            every side, so the picture breathes instead of filling the frame. \
            Place the subject in the middle of the picture, and leave the whole \
            lower third of the picture as bare empty paper, with no water, no \
            clouds, no rocks and no plants along the bottom edge, and nothing at \
            all in the lower left corner, because a title is read over that \
            space. Use soft ink-wash mountains and mist in the far distance, broad \
            painterly brushwork, saturated warm color masses, rich midtones, \
            tactile painted materials, a little gold, and a confident \
            illustrative finish. Poster tile framing in a 4:3 picture, the subject \
            centered and complete with air on every side. A small artist's \
            signature in one corner is welcome, but no other writing anywhere in \
            the picture.
            """

        #expect(CoverArtDirection.style == expected)
    }
}
