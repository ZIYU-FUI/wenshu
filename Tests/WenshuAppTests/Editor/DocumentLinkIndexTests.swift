//
//  DocumentLinkIndexTests.swift · Wenshu
//
//  Behavior tests for `DocumentLinkIndex` (= the reader that finds the
//  documents a document points at).
//
//  Why it exists: the boss (2026-10-26) wanted an index's link list
//  shown as the app's document cards. The cards come from the links,
//  = and the reader sees the body without the link lines, = so the two
//  halves have to agree on what a link line is.
//
//  Coverage (= 6 tests):
//   1. `linkedNamesReadsEveryLink`
//   2. `linkedNamesIgnoresTheSameNameTwice`
//   3. `linkNameReadsAListItem`
//   4. `linkNameReadsAnOrderedListItem`
//   5. `theBodyWithoutItsLinkSectionsKeepsTheRest`
//   6. `theBodyWithoutItsLinkSectionsDropsTheHeadingItReplaced`
//

import Foundation
import Testing

@testable import WenshuApp

@Suite("DocumentLinkIndex — the documents a document points at")
struct DocumentLinkIndexTests {

    private let index = """
    # the charter

    > the book · world/

    ## 元数据

    - **类型**: a world setting

    ## required children

    - [[core.md]]
    - [[places.md]]
    - [[rules.md]]

    ## custom children

    - [[the book图谱.md]]
    """

    @Test("every link is read")
    func linkedNamesReadsEveryLink() {
        let names = DocumentLinkIndex.linkedNames(in: index)

        #expect(names.count == 4)
        #expect(names.first == "core.md")
        #expect(names.last == "the book图谱.md")
    }

    @Test("the same name is read once")
    func linkedNamesIgnoresTheSameNameTwice() {
        let names = DocumentLinkIndex.linkedNames(
            in: "- [[core.md]]\n- [[core.md]]\n"
        )

        #expect(names == ["core.md"])
    }

    @Test("a list item is a link line")
    func linkNameReadsAListItem() {
        #expect(DocumentLinkIndex.linkName(inLine: "- [[core.md]]") == "core.md")
        #expect(DocumentLinkIndex.linkName(inLine: "  * [[core.md]]  ") == "core.md")
    }

    @Test("an ordered list item is a link line")
    func linkNameReadsAnOrderedListItem() {
        #expect(DocumentLinkIndex.linkName(inLine: "1. [[core.md]]") == "core.md")
    }

    @Test("the rest of the body stays")
    func theBodyWithoutItsLinkSectionsKeepsTheRest() {
        let body = DocumentLinkIndex.bodyWithoutLinkSections(index)

        #expect(body.contains("# the charter"))
        #expect(body.contains("**类型**: a world setting"))
        #expect(body.contains("> the book · world/"))
        #expect(!body.contains("core.md"))
        #expect(!body.contains("the book图谱.md"))
    }

    @Test("the heading the cards replace goes with it")
    func theBodyWithoutItsLinkSectionsDropsTheHeadingItReplaced() {
        let body = DocumentLinkIndex.bodyWithoutLinkSections(index)

        #expect(!body.contains("required children"))
        #expect(!body.contains("custom children"))
    }
}
