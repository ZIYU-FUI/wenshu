//
//  BoardElementTests.swift
//  WenshuBoardTests
//
//  One record, two placement regimes, and the switch between them.
//
//  The client's central claim is that a board, a column and a card are the
//  SAME record, and that the section decides which fields of the position
//  carry the meaning. A claim like that is worth a test of its own: without
//  one, the model could stop honouring the section and the claim would
//  still read true.
//

import Testing
import WenshuBoardKit

@Suite("One record, two regimes")
struct BoardElementRegimeTests {

    private func canvasCard(id: String, x: Double, y: Double, score: Int64) -> BoardElement {
        BoardElement(
            id: id,
            kind: .card,
            location: BoardLocation(
                section: .canvas,
                position: BoardLocation.Position(x: x, y: y, score: score)
            )
        )
    }

    private func listCard(id: String, index: Int, score: Int64) -> BoardElement {
        BoardElement(
            id: id,
            kind: .card,
            location: BoardLocation(
                section: .inbox,
                position: BoardLocation.Position(index: index, score: score)
            )
        )
    }

    @Test("The section says which regime a record is in")
    func theSectionIsTheSwitch() {
        let onCanvas = canvasCard(id: "a", x: 10, y: 20, score: 3)
        let inList = listCard(id: "b", index: 0, score: 65_536)
        #expect(onCanvas.isOnCanvas)
        #expect(!onCanvas.isInList)
        #expect(inList.isInList)
        #expect(!inList.isOnCanvas)
    }

    @Test("The order key exists only in the list regime")
    func theOrderKeyIsTheLists() {
        let onCanvas = canvasCard(id: "a", x: 10, y: 20, score: 3)
        let inList = listCard(id: "b", index: 0, score: 65_536)
        #expect(onCanvas.orderKey == nil)
        #expect(inList.orderKey == 65_536)
    }

    @Test("The score means two different things in the two regimes")
    func theScoreMeansTwoThings() {
        // The same field is the z-order on a canvas and the order key in a
        // list, so reading the key off a canvas record would hand back a
        // z-index.
        let onCanvas = canvasCard(id: "a", x: 0, y: 0, score: 7)
        #expect(onCanvas.location.position.score == 7)
        #expect(onCanvas.orderKey == nil)
    }

    @Test("A record carries both regimes' fields and the section picks")
    func oneRecordHoldsBothShapes() {
        // One envelope, both placements: the same record can be placed in
        // either regime, and moving it is a change of section.
        var element = canvasCard(id: "a", x: 10, y: 20, score: 3)
        #expect(element.location.position.x == 10)
        element.location.section = .inbox
        #expect(element.isInList)
        #expect(element.location.position.x == 10)
    }
}
