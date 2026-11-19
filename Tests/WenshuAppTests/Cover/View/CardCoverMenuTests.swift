//
//  CardCoverMenuTests.swift · Wenshu
//
//  Proves what the card's right-click menu offers about the cover.
//
//  The menu is a rule and not a pile of `if`s in a view, so it is
//  asked here without a window: the facts go in, and the items come
//  out.
//
//  The two rules the menu follows:
//
//  - an item that MAKES a cover appears only while the automatic
//    cover switch is on, because the switch is the user's answer to
//    "make covers for me";
//  - an item that REMOVES a cover appears whenever there is something
//    to remove, because the switch governs what the app may create
//    and never what the user may delete.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Card cover menu")
struct CardCoverMenuTests {
    /// A card with a reference on it.
    private func aCard() -> Card {
        Card(
            source: .reference(Reference(title: "A card")),
            onDoubleClick: { _ in },
            onRename: {},
            onDelete: {}
        )
    }

    /// A card whose cover facts are all in place.
    ///
    /// - Parameters:
    ///   - switchOn: whether the automatic cover switch is on.
    ///   - hasCover: whether the card carries a picture.
    ///   - hasClip: whether the card carries a moving cover.
    private func aCoveredCard(switchOn: Bool, hasCover: Bool, hasClip: Bool) -> Card {
        var card = aCard()
        card.isCoverGenerationEnabled = { switchOn }
        card.hasCover = hasCover
        card.coverVideoURL = hasClip
            ? URL(fileURLWithPath: "/tmp/wenshu-cover-menu-test.mp4")
            : nil
        card.onGenerateCover = {}
        card.onMakeDynamicCover = {}
        card.onRemoveCover = {}
        card.onRemoveDynamicCover = {}
        return card
    }

    @Test("The switch off hides every generation item")
    func theSwitchOffHidesEveryGenerationItem() {
        let card = aCoveredCard(switchOn: false, hasCover: true, hasClip: false)
        #expect(!card.coverMenu.actions.contains(.generateCover))
        #expect(!card.coverMenu.actions.contains(.regenerateCover))
        #expect(!card.coverMenu.actions.contains(.makeDynamicCover))
        // The removal is not a generation, so it stays.
        #expect(card.coverMenu.actions == [.removeCover])
    }

    @Test("The switch on offers a picture on a card that has none")
    func theSwitchOnOffersAPicture() {
        let card = aCoveredCard(switchOn: true, hasCover: false, hasClip: false)
        #expect(card.coverMenu.actions == [.generateCover])
    }

    @Test("The switch on offers a new picture on a card that has one")
    func theSwitchOnOffersANewPicture() {
        let card = aCoveredCard(switchOn: true, hasCover: true, hasClip: false)
        #expect(card.coverMenu.actions == [.regenerateCover, .makeDynamicCover, .removeCover])
    }

    @Test("A card that already moves offers the removal, not a second clip")
    func aCardThatMovesOffersTheRemoval() {
        let card = aCoveredCard(switchOn: true, hasCover: true, hasClip: true)
        #expect(card.coverMenu.actions == [.regenerateCover, .removeCover, .removeDynamicCover])
    }

    @Test("The removals survive the switch being off")
    func theRemovalsSurviveTheSwitchBeingOff() {
        let card = aCoveredCard(switchOn: false, hasCover: true, hasClip: true)
        #expect(card.coverMenu.actions == [.removeCover, .removeDynamicCover])
    }

    @Test("A removal appears only when there is something to remove")
    func aRemovalNeedsSomethingToRemove() {
        let card = aCoveredCard(switchOn: true, hasCover: false, hasClip: false)
        #expect(!card.coverMenu.actions.contains(.removeCover))
        #expect(!card.coverMenu.actions.contains(.removeDynamicCover))
    }

    @Test("A card with no cover service wired says nothing")
    func aCardWithNoWiringSaysNothing() {
        var card = aCard()
        card.isCoverGenerationEnabled = { true }
        card.hasCover = true
        #expect(card.coverMenu.isEmpty)
    }

    @Test("A failure is reported with its reason")
    func aFailureIsReportedWithItsReason() {
        var card = aCoveredCard(switchOn: true, hasCover: true, hasClip: false)
        card.coverErrorMessage = "no image service"
        #expect(card.coverMenu.failures == [.still("no image service")])
    }

    @Test("The clip's failure is its own report")
    func theClipsFailureIsItsOwnReport() {
        var card = aCoveredCard(switchOn: true, hasCover: true, hasClip: false)
        card.coverClipErrorMessage = "no video service"
        #expect(card.coverMenu.failures == [.clip("no video service")])
    }
}
