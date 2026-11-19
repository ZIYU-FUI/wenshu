//
//  SidebarTagRowsTests.swift · wenshu
//
//  The reference library's browse surface is ONE flat list of tags: the
//  library root's children are the tags, and every tag is a leaf.
//
//  Coverage:
//    1. One row per distinct tag (= the same tag string is one row).
//    2. The most carried tag comes first (= the count orders the list).
//    3. Two tags that carry the SAME count are ordered by the tag itself
//       (= the tie-break, = the only shape that can measure a second
//       sort clause).
//    4. The count is of the documents the grid shows (= the entities layer).
//    5. A tag only raw documents carry puts no row on the tree.
//    6. A tag row is a leaf (= no row under it) and carries its own routing key.
//    7. A reference's own category is not a level of the tree.
//    8. The tree the service loads is the root over that flat list.
//
//  ⇒ ⇒ ⇒ Every case measures the PRODUCTION projection
//  (= `SidebarService.tagRows(for:)` and the service's own `reload()`),
//  = so the suite proves the shape the tree draws, = not a copy of it.
//

import Foundation
import Testing
@testable import WenshuApp

@MainActor
struct SidebarTagRowsTests {
    private static func document(
        title: String,
        layer: ReferenceLayer = .layerEntities,
        tags: Set<String> = []
    ) -> Reference {
        Reference(title: title, layer: layer, tags: tags)
    }

    @Test("One row per distinct tag")
    func oneRowPerDistinctTag() {
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "Li Bai", tags: ["poet"]),
            Self.document(title: "Du Fu", tags: ["poet"]),
            Self.document(title: "The border", tags: ["place"]),
        ])

        #expect(rows.map(\.title) == ["poet", "place"])
    }

    @Test("The most carried tag comes first")
    func theMostCarriedTagComesFirst() {
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "A", tags: ["common"]),
            Self.document(title: "B", tags: ["common"]),
            Self.document(title: "C", tags: ["rare"]),
        ])

        #expect(rows.map(\.title) == ["common", "rare"])
    }

    @Test("Two tags that carry the same count are ordered by the tag itself")
    func twoTagsWithTheSameCountAreOrderedByTheTagItself() {
        // ⇒ ⇒ ⇒ THE TIE-BREAK IS A CLAIM, = so it needs the shape only
        // a tie can test: = TWO tags, = the SAME count (= the count
        // decides nothing here), = asserted in the order the sort's
        // second clause names (= ascending by the tag string). = A
        // fixture whose tags all have DIFFERENT counts cannot tell
        // "ordered by the tag" from "reversed by the tag" from
        // "insertion order", = and that is how a tie-break shipped
        // unmeasured.
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "One", tags: ["zeta"]),
            Self.document(title: "Two", tags: ["zeta"]),
            Self.document(title: "Three", tags: ["alpha"]),
            Self.document(title: "Four", tags: ["alpha"]),
        ])

        #expect(rows.map(\.title) == ["alpha", "zeta"])
    }

    @Test("The count is of the documents the grid shows")
    func theCountIsOfTheVisibleDocuments() {
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "Cao Cao", layer: .layerEntities, tags: ["Three Kingdoms"]),
            Self.document(title: "The Ming tax roll", layer: .layerRaw, tags: ["Three Kingdoms"]),
        ])

        #expect(rows.count == 1)
        #expect(rows.first?.subtitle == "1 items")
    }

    @Test("A tag only raw documents carry puts no row on the tree")
    func aRawOnlyTagMakesNoRow() {
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "The Ming tax roll", layer: .layerRaw, tags: ["Taxes"]),
        ])

        #expect(rows.isEmpty)
    }

    @Test("A tag row is a leaf and carries its own routing key")
    func aTagRowIsALeaf() {
        let rows = SidebarService.tagRows(for: [
            Self.document(title: "Li Bai", tags: ["poet"]),
        ])
        let row = rows.first

        #expect(row?.kind == .tag)
        #expect(row?.children == nil)
        #expect(row?.routingKey == "poet")
        #expect(row?.systemImage == "tag")
    }

    @Test("A reference's own category is not a level of the tree")
    func theCategoryIsNotALevel() {
        let rows = SidebarService.tagRows(for: [
            Reference(title: "Li Bai", layer: .layerEntities, category: .i, tags: ["poet"]),
        ])

        #expect(rows.count == 1)
        #expect(rows.first?.kind == .tag)
        #expect(rows.first?.children == nil)
    }

    @Test("The tree the service loads is the root over that flat list")
    func theLoadedTreeIsTheRootOverTheFlatList() async throws {
        let references = [Self.document(title: "Li Bai", tags: ["poet"])]
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { [] },
            loadReferences: { references }
        )

        await service.reload()

        let root = try #require(service.libraryNodes.first)
        #expect(root.kind == .reference)
        #expect(root.children?.map(\.title) == ["poet"])
    }
}
