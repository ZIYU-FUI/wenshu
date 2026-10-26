//
//  ImportTagPolicyTests.swift · Wenshu
//
//  Behavior tests for `ImportTagPolicy` (= the one rule about the tags
//  an imported entity keeps).
//
//  Why it exists: the rule lived in the old import path only (= the
//  boss 2026-10-09): = the title is not a tag, = at most three tags,
//  = at least one. The paths that came after it wrote the tags as the
//  model gave them, = so an imported entity could carry four tags, =
//  a tag that repeated its own title, = or none at all (= the boss
//  2026-10-26).
//
//  Coverage (= 8 tests):
//   1. `theTitleIsNeverATag`
//   2. `aTagRepeatsNoOtherTag`
//   3. `atMostThreeTagsSurvive`
//   4. `aTagNeverNamesASiblingDocument`
//   5. `theFallbackFillsAnEmptySet`
//   6. `theFallbackNeverIsTheTitle`
//   7. `theSiblingNamesCoverBothSpellings`
//   8. `aTagCarriesNoPunctuation`
//

import Foundation
import Testing

@testable import WenshuApp

@Suite("ImportTagPolicy — the tags an imported entity keeps")
struct ImportTagPolicyTests {

    @Test("the title is never a tag")
    func theTitleIsNeverATag() {
        let tags = ImportTagPolicy.tags(
            ["the entity", "the title", "a field"],
            title: "the title"
        )

        #expect(tags.contains("the entity"))
        #expect(tags.contains("a field"))
        #expect(!tags.contains("the title"))
    }

    @Test("a tag repeats no other tag")
    func aTagRepeatsNoOtherTag() {
        let tags = ImportTagPolicy.tags(
            ["a field", "a field", "A FIELD"],
            title: "the title"
        )

        #expect(tags == ["a field"])
    }

    @Test("at most three tags survive")
    func atMostThreeTagsSurvive() {
        let tags = ImportTagPolicy.tags(
            ["one", "two", "three", "four", "five"],
            title: "the title"
        )

        #expect(tags.count == 3)
        #expect(tags == ["one", "two", "three"])
    }

    @Test("a tag never names a sibling document")
    func aTagNeverNamesASiblingDocument() {
        let tags = ImportTagPolicy.tags(
            ["the sibling", "a field"],
            title: "the title",
            siblingNames: ["the sibling", "the sibling.md"]
        )

        #expect(tags == ["a field"])
    }

    @Test("the fallback fills an empty set")
    func theFallbackFillsAnEmptySet() {
        let tags = ImportTagPolicy.tags(
            ["the title"],
            title: "the title",
            fallback: ["a field"]
        )

        #expect(tags == ["a field"])
    }

    @Test("the fallback never is the title")
    func theFallbackNeverIsTheTitle() {
        let tags = ImportTagPolicy.tags(
            [],
            title: "the title",
            fallback: ["the title", "a field"]
        )

        #expect(tags == ["a field"])
    }

    @Test("the sibling names cover both spellings")
    func theSiblingNamesCoverBothSpellings() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wenshu-tags-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "# one".write(
            to: folder.appendingPathComponent("one.md"),
            atomically: true,
            encoding: .utf8
        )

        let names = ImportTagPolicy.siblingNames(inFolderAt: folder)

        #expect(names.contains("one.md"))
        #expect(names.contains("one"))
    }

    @Test("a tag carries no punctuation")
    func aTagCarriesNoPunctuation() {
        let tags = ImportTagPolicy.tags(
            ["a field", "one, two", "three."],
            title: "the title"
        )

        #expect(tags == ["a field"])
    }
}
