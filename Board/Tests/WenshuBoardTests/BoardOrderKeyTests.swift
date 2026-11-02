//
//  BoardOrderKeyTests.swift
//  WenshuBoardTests
//
//  The order key is the mechanism the reference contributes, so it is the one
//  thing in this slice that is tested against the measured behaviour rather
//  than against a wish.
//

import Foundation
import Testing
import WenshuData
@testable import WenshuBoardKit

@Suite("The board order key")
struct BoardOrderKeyTests {

    @Test("The step is the measured 65536")
    func stepIsMeasured() {
        #expect(BoardOrderKey.step == 65_536)
    }

    @Test("The key of an ordinal is the ordinal times the step")
    func keyForIndex() {
        #expect(BoardOrderKey.key(forIndex: 0) == 0)
        #expect(BoardOrderKey.key(forIndex: 1) == 65_536)
        #expect(BoardOrderKey.key(forIndex: 4) == 262_144)
    }

    @Test("The first card of an empty list sits at the origin")
    func insertIntoEmptyList() {
        #expect(BoardOrderKey.insertKey(at: 0, among: []) == 0)
    }

    @Test("An insert below the tail takes the next rung")
    func insertAtTail() {
        #expect(BoardOrderKey.insertKey(at: 3, among: [0, 65_536, 131_072]) == 196_608)
    }

    @Test("An insert above the head takes a negative rung")
    func insertAtHead() {
        // The reference's own head ladder: the head sits at 0 and an insert
        // above it takes the next negative multiple.
        #expect(BoardOrderKey.insertKey(at: 0, among: [0, 65_536]) == -65_536)
        #expect(BoardOrderKey.insertKey(at: 0, among: [-65_536, 0]) == -131_072)
    }

    @Test("An insert between two neighbours lands between them")
    func insertInTheMiddle() {
        let key = BoardOrderKey.insertKey(at: 1, among: [0, 131_072])
        #expect(key != nil)
        let inserted = key ?? 0
        #expect(inserted > 0)
        #expect(inserted < 131_072)
    }

    @Test("An insert with no room between the neighbours asks for a rebalance")
    func insertWithNoRoom() {
        // Neighbours one apart: there is no integer between them.
        #expect(BoardOrderKey.insertKey(at: 1, among: [10, 11]) == nil)
    }

    @Test("A rebalance keeps the order and moves the keys onto the ladder")
    func rebalanceKeepsOrder() {
        let rebased = BoardOrderKey.rebalance([-131_072, -65_536, 0, 65_536])
        #expect(rebased == [0, 65_536, 131_072, 196_608])
    }

    @Test("Ordering by the key is the ordering by position")
    func ordering() {
        let cards = (0..<4).map { index in
            BoardElement(
                id: "c\(index)",
                kind: .card,
                location: BoardLocation(
                    section: .inbox,
                    position: BoardLocation.Position(score: BoardOrderKey.key(forIndex: 3 - index))
                )
            )
        }
        let ordered = BoardOrderKey.ordered(cards) { $0.orderKey ?? 0 }
        #expect(ordered.map(\.id) == ["c3", "c2", "c1", "c0"])
    }
}

@Suite("A chapter becomes a column of cards")
struct ChapterColumnTests {

    private func chapter(body: String, title: String = "Chapter") -> WSChapter {
        WSChapter(id: "ch-1", bookID: "book-1", title: title, position: 0, body: body)
    }

    @Test("A level-two heading starts a card")
    func splitsOnLevelTwoHeadings() {
        let source = chapter(body: "# Title\n\n## First\n\ntext one\n\n## Second\n\ntext two\n")
        let cards = ChapterColumnBuilder.cards(for: source)
        #expect(cards.count == 2)
        #expect(cards[0].content.title == "First")
        #expect(cards[1].content.title == "Second")
    }

    @Test("A chapter with no level-two heading is one card, so nothing is lost")
    func chapterWithoutHeadings() {
        let source = chapter(body: "just a paragraph")
        let cards = ChapterColumnBuilder.cards(for: source)
        #expect(cards.count == 1)
        #expect(cards[0].content.body == "just a paragraph")
    }

    @Test("The cards carry the ladder's order keys")
    func cardsCarryOrderKeys() {
        let source = chapter(body: "## A\n\n## B\n\n## C\n")
        let cards = ChapterColumnBuilder.cards(for: source)
        #expect(cards.map(\.orderKey) == [0, 65_536, 131_072])
        #expect(cards.allSatisfy { $0.location.parentID == "ch-1" })
        #expect(cards.allSatisfy { $0.location.section == .inbox })
    }

    @Test("The chapter's own level-one heading is the chapter's title")
    func chapterTitle() {
        #expect(ChapterFileReader.title(in: "# The Real Title\n\n## First\n", fallback: "ch-1") == "The Real Title")
        #expect(ChapterFileReader.title(in: "no heading\n", fallback: "ch-1") == "ch-1")
    }

    @Test("The board carries the chapter's title")
    func boardCarriesTitle() {
        let board = ChapterColumnBuilder.board(id: "ch-1", title: "Chapter One")
        #expect(board.kind == .board)
        #expect(board.content.title == "Chapter One")
    }
}
