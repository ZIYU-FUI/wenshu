//
//  BookDocumentTagLineTests.swift · Wenshu
//
//  Behavior tests for `BookDocumentTagLine` (= the tag line of a book
//  document, = with the library's tag rule applied).
//
//  Why it exists: the agent writes the world's index, = and the
//  index's metadata carries a tag line. The library's rule (the boss
//  2026-10-26) says the title is not a tag, = a tag names no sibling
//  document, = and there are one to three of them. The agent writes
//  the body, = so the app holds the rule (= this type rewrites the
//  line before the file lands).
//
//  Coverage (= 6 tests):
//   1. `theTitleLeavesTheTagLine`
//   2. `aSiblingNameLeavesTheTagLine`
//   3. `atMostThreeTagsSurvive`
//   4. `theFallbackFillsTheLine`
//   5. `aBodyWithoutATagLineIsUnchanged`
//   6. `theRestOfTheBodyIsUnchanged`
//

import Foundation
import Testing

@testable import WenshuApp

@Suite("BookDocumentTagLine — the tag line of a book document")
struct BookDocumentTagLineTests {

    private let body = """
    # the charter

    ## metadata

    - **source**: a file
    - **type**: a setting
    - **tags**: the charter / a field / a sibling / another one
    - **summary**: one line

    ## overview

    The body goes on.
    """

    @Test("the title leaves the tag line")
    func theTitleLeavesTheTagLine() {
        let body = BookDocumentTagLine.normalized(
            in: body,
            title: "the charter",
            siblingNames: []
        )

        #expect(!body.contains("the charter /"))
        #expect(body.contains("a field"))
    }

    @Test("a sibling name leaves the tag line")
    func aSiblingNameLeavesTheTagLine() {
        let body = BookDocumentTagLine.normalized(
            in: body,
            title: "the charter",
            siblingNames: ["a sibling"]
        )

        #expect(!body.contains("a sibling"))
    }

    /// The tags of the body's tag line.
    private func tags(in body: String) -> [String] {
        let line = body.split(separator: "\n").first { $0.contains("tags") } ?? ""
        let value = line.split(separator: ":").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return value.split(separator: "/").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    @Test("at most three tags survive")
    func atMostThreeTagsSurvive() {
        let body = BookDocumentTagLine.normalized(
            in: body,
            title: "the charter",
            siblingNames: ["a sibling"]
        )

        let kept = tags(in: body)
        #expect(kept.count == 2)
        #expect(kept.contains("a field"))
        #expect(kept.contains("another one"))
    }

    @Test("the fallback fills the line")
    func theFallbackFillsTheLine() {
        let body = BookDocumentTagLine.normalized(
            in: """
            # the charter

            - **tags**: the charter
            """,
            title: "the charter",
            siblingNames: [],
            fallback: ["a setting"]
        )

        #expect(tags(in: body) == ["a setting"])
    }

    @Test("a body without a tag line is unchanged")
    func aBodyWithoutATagLineIsUnchanged() {
        let source = "# the charter\n\nThe body goes on.\n"

        #expect(BookDocumentTagLine.normalized(
            in: source,
            title: "the charter",
            siblingNames: []
        ) == source)
    }

    @Test("the rest of the body is unchanged")
    func theRestOfTheBodyIsUnchanged() {
        let body = BookDocumentTagLine.normalized(
            in: body,
            title: "the charter",
            siblingNames: ["a sibling"]
        )

        #expect(body.contains("# the charter"))
        #expect(body.contains("**source**: a file"))
        #expect(body.contains("**summary**: one line"))
        #expect(body.contains("The body goes on."))
    }
}
