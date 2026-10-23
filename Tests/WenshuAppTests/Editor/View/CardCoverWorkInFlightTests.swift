import Foundation
import Testing
@testable import WenshuApp

/// The card's own statement about whether cover work is running.
///
/// The picture and the clip both take time, and the user asked for
/// both, so the card must say so while either one is running: a card
/// that sits there looking finished is lying.
@Suite("Card cover work in flight")
struct CardCoverWorkInFlightTests {
    /// A card with nothing running on it.
    private func aCard() -> Card {
        Card(
            source: .bookDoc(aBookDoc()),
            onDoubleClick: { _ in },
            onRename: {},
            onDelete: {}
        )
    }

    /// A book document to hang the card on.
    private func aBookDoc() -> BookDoc {
        BookDoc(
            id: UUID(),
            bookId: UUID(),
            folderName: "world",
            fileName: "a.md",
            modifiedAt: .now,
            createdAt: .now,
            tags: [],
            body: ""
        )
    }

    @Test("A card with no cover work says nothing is running")
    func anIdleCardIsNotBusy() {
        #expect(aCard().isCoverWorkInFlight == false)
    }

    @Test("A picture being drawn is cover work")
    func aDrawingPictureIsCoverWork() {
        var card = aCard()
        card.isGeneratingCover = true
        #expect(card.isCoverWorkInFlight == true)
    }

    @Test("A clip being made is cover work too")
    func aMakingClipIsCoverWork() {
        var card = aCard()
        card.isMakingVideo = true
        #expect(card.isCoverWorkInFlight == true)
    }

    @Test("Both at once is still cover work")
    func bothAtOnceIsCoverWork() {
        var card = aCard()
        card.isGeneratingCover = true
        card.isMakingVideo = true
        #expect(card.isCoverWorkInFlight == true)
    }
}
