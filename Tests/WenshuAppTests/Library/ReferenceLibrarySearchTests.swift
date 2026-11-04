//
//  ReferenceLibrarySearchTests.swift
//
//  The library's own search.
//
//  What is held here: that a search over the library finds the
//  document the user meant (= by a word in its title or in its body),
//  that it does NOT quietly become a list of everything (= an empty
//  query is not a search), that the order is the order the user
//  reads (= and does not shuffle between runs), and that a hit in the
//  raw layer says so (= because a raw-layer document is one the user
//  cannot see in the library's grid, = and a search that hid that
//  would be a lie).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Reference library search")
struct ReferenceLibrarySearchTests {
    // MARK: - Fixtures

    private func makeReference(
        title: String,
        layer: ReferenceLayer = .layerEntities
    ) -> Reference {
        Reference(title: title, layer: layer)
    }

    /// The bodies the corpus answers with (= the `.md` file of each
    /// document, = keyed by the document's title so a test can say
    /// "this document's body says this" without a disk).
    private func bodies(_ map: [String: String]) -> (Reference) -> String? {
        { reference in map[reference.title] }
    }

    // MARK: - A search finds the document

    @Test("A word in the title finds the document")
    func findsByTitle() {
        let hit = ReferenceLibrarySearch.search(
            query: "tax",
            references: [makeReference(title: "The Ming tax system"), makeReference(title: "Sea routes")],
            bodyOf: bodies([:])
        )
        #expect(hit.count == 1)
        #expect(hit.first?.reference.title == "The Ming tax system")
    }

    @Test("A word in the body finds the document")
    func findsByBody() {
        let hit = ReferenceLibrarySearch.search(
            query: "harbour",
            references: [makeReference(title: "The Ming tax system"), makeReference(title: "Sea routes")],
            bodyOf: bodies(["Sea routes": "The harbour at Quanzhou carried the tribute."])
        )
        #expect(hit.count == 1)
        #expect(hit.first?.reference.title == "Sea routes")
    }

    @Test("A word nowhere in the corpus finds nothing")
    func findsNothingWhenAbsent() {
        let hit = ReferenceLibrarySearch.search(
            query: "astrolabe",
            references: [makeReference(title: "The Ming tax system")],
            bodyOf: bodies(["The Ming tax system": "The tribute was weighed in silver."])
        )
        #expect(hit.isEmpty)
    }

    // MARK: - A search is not a list

    @Test("An empty query finds nothing, rather than everything")
    func emptyQueryFindsNothing() {
        let hit = ReferenceLibrarySearch.search(
            query: "   ",
            references: [makeReference(title: "One"), makeReference(title: "Two")],
            bodyOf: bodies([:])
        )
        #expect(hit.isEmpty)
    }

    @Test("A query of punctuation only finds nothing")
    func punctuationOnlyQueryFindsNothing() {
        let hit = ReferenceLibrarySearch.search(
            query: "***",
            references: [makeReference(title: "One")],
            bodyOf: bodies([:])
        )
        #expect(hit.isEmpty)
    }

    // MARK: - The order

    @Test("A title that holds the query comes before a body that holds it")
    func titleOutranksBody() {
        let hit = ReferenceLibrarySearch.search(
            query: "tribute",
            references: [makeReference(title: "A note on the sea"), makeReference(title: "Tribute roads")],
            bodyOf: bodies(["A note on the sea": "The tribute was heavy that year."])
        )
        #expect(hit.count == 2)
        #expect(hit.first?.reference.title == "Tribute roads")
    }

    @Test("Two documents of the same score keep the same order twice")
    func equalScoresKeepTheirOrder() {
        let references = [makeReference(title: "Zebra"), makeReference(title: "Alpha")]
        let hit = ReferenceLibrarySearch.search(
            query: "notes",
            references: references,
            bodyOf: bodies(["Zebra": "notes here", "Alpha": "notes here"])
        )
        #expect(hit.count == 2)
        #expect(hit.map(\.reference.title) == ["Alpha", "Zebra"])
    }

    // MARK: - The layers

    @Test("A document in the raw layer is found, and is marked as not visible")
    func rawLayerHitIsMarked() {
        let hit = ReferenceLibrarySearch.search(
            query: "tribute",
            references: [makeReference(title: "Imported tribute roll", layer: .layerRaw)],
            bodyOf: bodies([:])
        )
        #expect(hit.count == 1)
        #expect(hit.first?.isInAVisibleLayer == false)
    }

    @Test("A document in the visible layer is marked as visible")
    func visibleLayerHitIsMarked() {
        let hit = ReferenceLibrarySearch.search(
            query: "character",
            references: [makeReference(title: "A character", layer: .layerEntities)],
            bodyOf: bodies([:])
        )
        #expect(hit.count == 1)
        #expect(hit.first?.isInAVisibleLayer == true)
    }

    // MARK: - The snippet

    @Test("A body hit shows the body around the match")
    func bodyHitShowsTheBody() {
        let hit = ReferenceLibrarySearch.search(
            query: "quanzhou",
            references: [makeReference(title: "Sea routes")],
            bodyOf: bodies(["Sea routes": "The harbour at Quanzhou carried the tribute."])
        )
        #expect(hit.first?.snippet.contains("Quanzhou") == true)
    }

    @Test("A title hit shows the title, because there is no body to show")
    func titleHitShowsTheTitle() {
        let hit = ReferenceLibrarySearch.search(
            query: "tribute",
            references: [makeReference(title: "Tribute roads")],
            bodyOf: bodies([:])
        )
        #expect(hit.first?.snippet == "Tribute roads")
    }

    @Test("A document whose body cannot be read is still found by its title")
    func unreadableBodyStillMatchesOnTitle() {
        let hit = ReferenceLibrarySearch.search(
            query: "tribute",
            references: [makeReference(title: "Tribute roads")],
            bodyOf: { _ in nil }
        )
        #expect(hit.count == 1)
    }
}
