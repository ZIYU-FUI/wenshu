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
            Create original hand-painted Chinese-style fantasy scroll paintings; never \
            imitate an existing franchise, character, card frame, logo or official \
            illustration. Render the subject as one dimensional layered scroll \
            painting, softly embossed and built from a few clear planes of depth. The \
            whole painting is in bright daylight, and nothing in it is dark or \
            night-time. The painting sits in the middle of the frame and generous \
            empty space stays visible on all four sides, so the picture breathes \
            instead of filling the frame. Place the subject in the middle, and leave \
            the whole lower third empty, with no water, no clouds, no rocks and no \
            plants along the bottom edge, and nothing at all in the lower left corner, \
            because a title is read over that space. Use soft ink-wash mountains and \
            mist in the far distance, broad painterly brushwork, saturated warm color, \
            rich midtones, tactile materials, a little gold. A small artist's seal in \
            one corner is the only writing allowed. This is a painted picture, never a \
            document, a slide, a poster, a diagram, a screenshot or an interface, and \
            it contains no written words at all.
            """

        #expect(CoverArtDirection.style == expected)
    }

    @Test("A long subject is cut, and the art direction is not")
    func longSubjectIsCutToTheProviderLimit() {
        let subject = String(repeating: "a very long subject ", count: 400)

        let prompt = CoverArtDirection.prompt(subject: subject)

        #expect(prompt.count <= CoverArtDirection.providerPromptLimit)
        #expect(prompt.hasPrefix(CoverArtDirection.style))
        #expect(prompt.count > CoverArtDirection.style.count)
    }

    @Test("A short subject is left alone")
    func shortSubjectIsKept() {
        let prompt = CoverArtDirection.prompt(subject: "Qixi")

        #expect(prompt == CoverArtDirection.style + " Qixi")
    }
}
