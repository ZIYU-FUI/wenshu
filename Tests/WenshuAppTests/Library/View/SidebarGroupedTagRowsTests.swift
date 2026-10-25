//
//  SidebarGroupedTagRowsTests.swift · wenshu
//
//  The reference library's browse surface is a two-level tree: one row
//  per library category, and under each, the tags that belong to it.
//
//  A tag belongs to exactly one category. Where the references that
//  carry a tag disagree about the category, the category more of them
//  give wins; a tie goes to the category that comes first in the
//  library's own category order.
//
//  Coverage:
//    1. A tag lands under the category most of its references give.
//    2. A tie goes to the category that comes first in the library's
//       category order.
//    3. The same tag string never appears under two categories.
//    4. A reference with no category lands under the catch-all row, and
//       the catch-all row comes last.
//    5. A category row carries the enum's display name and semantic icon.
//    6. A category with no tags is not drawn.
//

import XCTest
@testable import WenshuApp

@MainActor
final class SidebarGroupedTagRowsTests: XCTestCase {

    // MARK: - The helpers

    /// The tag rows under the row whose routing key is `key`.
    private func tags(
        under key: String,
        in rows: [SidebarNode]
    ) -> [String] {
        guard let row = rows.first(where: { $0.routingKey == key }) else { return [] }
        return (row.children ?? []).map(\.title)
    }

    /// A reference with a category and a tag set.
    private func reference(
        category: EntityCategory?,
        tags: Set<String>,
        title: String = "a reference"
    ) -> Reference {
        Reference(
            title: title,
            category: category,
            tags: tags
        )
    }

    // MARK: - The projection

    func testATagLandsUnderTheCategoryMostOfItsReferencesGive() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["poet"]),
            reference(category: .i, tags: ["poet"]),
            reference(category: .k, tags: ["poet"])
        ])
        XCTAssertEqual(
            tags(under: EntityCategory.i.directoryName, in: rows),
            ["poet"],
            "The tag belongs to the category more of its references give."
        )
        XCTAssertEqual(
            tags(under: EntityCategory.k.directoryName, in: rows),
            [],
            "The losing category must not hold the tag."
        )
    }

    func testATieGoesToTheCategoryThatComesFirstInTheLibrarysOrder() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .k, tags: ["place"]),
            reference(category: .i, tags: ["place"])
        ])
        // I comes before K in the library's own category order, so the
        // tie goes to I.
        XCTAssertEqual(
            tags(under: EntityCategory.i.directoryName, in: rows),
            ["place"]
        )
        XCTAssertEqual(
            tags(under: EntityCategory.k.directoryName, in: rows),
            []
        )
    }

    func testTheSameTagStringNeverAppearsUnderTwoCategories() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["poet"]),
            reference(category: .k, tags: ["poet"]),
            reference(category: .a, tags: ["poet"])
        ])
        let carrying = rows.filter { row in
            (row.children ?? []).contains { $0.title == "poet" }
        }
        XCTAssertEqual(
            carrying.count,
            1,
            "A tag belongs to exactly one category, so exactly one row holds it."
        )
    }

    func testAReferenceWithNoCategoryLandsUnderTheCatchAllRow() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: nil, tags: ["mystery"])
        ])
        XCTAssertEqual(
            tags(under: SidebarService.unclassifiedRoutingKey, in: rows),
            ["mystery"],
            "A reference no category claims stays browsable under the catch-all."
        )
    }

    func testTheCatchAllRowComesLast() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: nil, tags: ["mystery"]),
            reference(category: .a, tags: ["classic"])
        ])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(
            rows.last?.routingKey,
            SidebarService.unclassifiedRoutingKey,
            "The catch-all row is the last row."
        )
        XCTAssertEqual(
            rows.first?.routingKey,
            EntityCategory.a.directoryName,
            "The real categories come first, in the library's own order."
        )
    }

    func testACategoryRowCarriesTheEnumsDisplayNameAndSemanticIcon() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["poet"])
        ])
        let row = rows.first
        XCTAssertEqual(row?.title, EntityCategory.i.displayName)
        XCTAssertEqual(row?.systemImage, EntityCategory.i.icon)
        XCTAssertEqual(row?.kind, .referenceCategory)
    }

    func testACategoryWithNoTagsIsNotDrawn() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["poet"])
        ])
        XCTAssertEqual(
            rows.count,
            1,
            "A category with no tags is not drawn at all."
        )
        XCTAssertFalse(
            rows.contains { $0.routingKey == EntityCategory.k.directoryName }
        )
    }

    func testTheEntityDocumentsAreNotDrawn() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["poet"], title: "Li Bai")
        ])
        for row in rows {
            XCTAssertEqual(row.kind, .referenceCategory)
            for child in row.children ?? [] {
                XCTAssertEqual(
                    child.kind,
                    .tag,
                    "Only the categories and the tags are drawn."
                )
            }
        }
    }

    func testTheCategoryRowsCarryTheMostCarriedTagFirst() {
        let rows = SidebarService.groupedTagRows(for: [
            reference(category: .i, tags: ["common"]),
            reference(category: .i, tags: ["common"]),
            reference(category: .i, tags: ["rare"])
        ])
        XCTAssertEqual(
            tags(under: EntityCategory.i.directoryName, in: rows),
            ["common", "rare"],
            "The most carried tag comes first."
        )
    }
}
