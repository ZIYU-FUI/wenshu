//
//  CoverClipControlTests.swift · Wenshu
//
//  Proves what the cover's motion badge is.
//
//  The badge is a HINT and not a control: the clip plays when the
//  pointer arrives, and the badge says the card can do that. It is
//  the mark the Photos app puts on a picture that moves, and it is
//  the system's own symbol.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover clip badge")
struct CoverClipControlTests {

    @Test("The badge is the mark the Photos app uses")
    func theBadgeIsThePhotosMark() {
        // `livephoto` is the Photos app's mark for a picture that
        // moves. It is the system's symbol, not a picture of one.
        #expect(CoverClipControl.symbol == "livephoto")
    }

    @Test("The badge is a hint and not a control")
    func theBadgeIsSmall() {
        // A card whose picture IS the card must not have a button on
        // top of it, so the mark stays in the corner and stays small.
        #expect(CoverClipControl.badgeSize >= 12)
        #expect(CoverClipControl.badgeSize <= 16)
    }
}
