//
//  CoverFailureMarkTests.swift · Wenshu
//
//  Proves which failure puts the orange mark on the PICTURE.
//
//  A clip that failed does NOT mark the picture: the picture is there
//  and it is fine, and the menu says that the clip is the part that
//  gave up. Measured 2026-10-23: the mark sat on a card with a good
//  still cover, because the clip's failure had overwritten the one
//  error field.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Cover failure mark")
struct CoverFailureMarkTests {

    /// A card with the two failures the record can carry.
    private func card(stillError: String?, clipError: String?) -> Card {
        var card = Card(
            source: .reference(Reference(title: "A card")),
            onDoubleClick: { _ in },
            onRename: {},
            onDelete: {}
        )
        card.coverErrorMessage = stillError
        card.coverClipErrorMessage = clipError
        return card
    }

    @Test("A failed clip does not mark the picture")
    func aFailedClipDoesNotMarkThePicture() {
        #expect(card(stillError: nil, clipError: "no quota left").showsFailureMark == false)
    }

    @Test("A failed picture marks the picture")
    func aFailedPictureMarksThePicture() {
        #expect(card(stillError: "no image service", clipError: nil).showsFailureMark)
    }

    @Test("A card with no failure carries no mark")
    func aCardWithNoFailureCarriesNoMark() {
        #expect(card(stillError: nil, clipError: nil).showsFailureMark == false)
    }
}
