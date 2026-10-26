//
//  MarkdownBlocksTests.swift · wenshu
//
//  A text split into its markdown blocks.
//
//  The blocks are what hermes renders (= a paragraph, = a list, = a
//  heading, = a code block). The reader sees the structure, = and the
//  model's syntax never reaches the screen.
//
//  The boss's own complaint (= measured on the import sheet): the
//  thinking content showed a staircase of four different left edges,
//  and the list markers sat there as literal characters.
//

import XCTest
@testable import WenshuApp

final class MarkdownBlocksTests: XCTestCase {

    // MARK: - The blocks

    func testAListIsAList() {
        let blocks = MarkdownBlocks.parse(
            """
            - one
            - two
            """
        )
        XCTAssertEqual(blocks.count, 1)
        guard case .list(let items) = blocks[0] else {
            return XCTFail("the two bullets are one list, not two paragraphs")
        }
        XCTAssertEqual(items.map(\.text), ["one", "two"])
        XCTAssertEqual(items.map(\.depth), [0, 0])
    }

    func testTheNestedItemsCarryTheirDepth() {
        let blocks = MarkdownBlocks.parse(
            """
            - one
                - nested
            - two
            """
        )
        guard case .list(let items) = blocks.first else {
            return XCTFail("expected a list")
        }
        XCTAssertEqual(items.map(\.text), ["one", "nested", "two"])
        XCTAssertEqual(items.map(\.depth), [0, 1, 0])
    }

    func testAHeadingIsAHeading() {
        let blocks = MarkdownBlocks.parse("### The title")
        XCTAssertEqual(blocks, [.heading(level: 3, text: "The title")])
    }

    func testAParagraphIsOneParagraph() {
        let blocks = MarkdownBlocks.parse(
            """
            first line
            second line
            """
        )
        XCTAssertEqual(blocks, [.paragraph("first line second line")])
    }

    func testAFencedRunIsCode() {
        let blocks = MarkdownBlocks.parse(
            """
            ```swift
            let x = 1
            ```
            """
        )
        XCTAssertEqual(blocks, [.code("let x = 1")])
    }

    func testABlankLineEndsTheBlock() {
        let blocks = MarkdownBlocks.parse(
            """
            one

            two
            """
        )
        XCTAssertEqual(blocks.count, 2)
    }

    // MARK: - The indentation goes

    func testTheIndentationDoesNotReachTheReader() {
        // The shape of the sample measured on the import sheet (= the
        // model's own scratch indentation; = the words are the agent's
        // own, = the shape is what the parser reads): = the bullets
        // become a list, = and no line carries a leading space.
        let blocks = MarkdownBlocks.parse(
            """
            , not by map
            - the modern layer
                - the twelve volumes
            **the folk geography**: south
            """
        )
        guard case .paragraph(let first) = blocks[0] else {
            return XCTFail("the prose line is a paragraph")
        }
        XCTAssertEqual(first, ", not by map")
        XCTAssertFalse(first.hasPrefix(" "))
        // The two bullets are one list, = and the nested one carries its
        // depth (= the structure replaced the indentation).
        guard case .list(let items) = blocks[1] else {
            return XCTFail("the bullets are one list")
        }
        XCTAssertEqual(items.map(\.depth), [0, 1])
        XCTAssertFalse(items.contains { $0.text.hasPrefix(" ") })
    }

    func testAnOrderedItemIsAListItem() {
        let blocks = MarkdownBlocks.parse("1. first\n2. second")
        guard case .list(let items) = blocks.first else {
            return XCTFail("the ordered items are one list")
        }
        XCTAssertEqual(items.map(\.text), ["first", "second"])
    }

    func testTheTextSurvivesWhenItIsNotMarkdown() {
        XCTAssertEqual(
            MarkdownBlocks.parse("just a line"),
            [.paragraph("just a line")]
        )
    }
}
