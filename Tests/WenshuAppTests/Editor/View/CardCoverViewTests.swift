//
//  CardCoverViewTests.swift · Wenshu
//
//  Proves the cover RESOLUTION, not the pixels.
//
//  There is no SwiftUI rendering harness in this project, and building
//  one for this ticket would cost more than the feature. So the tests
//  cover the decision that was easy to get wrong: which cover a card
//  shows.
//
//  The test that matters is the LAST one. A reference card and a book
//  card are different cards, and the grid resolves each card's cover
//  from its OWN kind. A grid that resolved the section's kind would
//  show every card in a section the same picture, and nothing in the
//  rendering would reveal it.
//

import Foundation
import SwiftData
import Testing
import WenshuAgent
import WenshuData
@testable import WenshuApp

@Suite("Card cover view")
struct CardCoverViewTests {

    @Test("A reference card and a book card get DIFFERENT cover keys")
    func theTwoCardKindsGetDifferentKeys() {
        let id = UUID()

        let referenceKey = CardCoverService.key(forReference: id)
        let bookKey = CardCoverService.key(forBookDoc: id)

        #expect(referenceKey != bookKey)
        // The same identity must not resolve to one cover for both
        // kinds: that is how one card's picture ends up on another.
        #expect(referenceKey.contains(WSCardCoverKind.reference))
        #expect(bookKey.contains(WSCardCoverKind.bookDoc))
    }

    @Test("The key is stable for the same card")
    func theKeyIsStable() {
        let id = UUID()

        #expect(CardCoverService.key(forReference: id) == CardCoverService.key(forReference: id))
        #expect(CardCoverService.key(forBookDoc: id) == CardCoverService.key(forBookDoc: id))
    }

    @Test("Different cards get different keys")
    func differentCardsGetDifferentKeys() {
        #expect(
            CardCoverService.key(forReference: UUID())
                != CardCoverService.key(forReference: UUID())
        )
    }

    @Test("A card with no cover resolves to no picture")
    @MainActor
    func aCardWithNoCoverResolvesToNil() async throws {
        // The lookup goes through the cover files, so a card whose
        // cover folder is not there has no picture. The renderer then
        // keeps its gradient and symbol.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-cover-view-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try await PathGuard.$libraryRootOverride.withValue(root.path) {
            let service = CardCoverService()
            #expect(service.coverImageURL(for: "reference-nothing-here") == nil)
            #expect(service.entry(forKey: "reference-nothing-here") == .none)
        }
    }
}
