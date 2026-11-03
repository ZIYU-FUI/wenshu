//
//  BoardCanvasDemo.swift
//  WenshuBoard
//
//  The demo record set: ONE set of records, read by two views.
//
//  The canvas reads the canvas regime (an x and a y, the score as the
//  z-order) and the column reads the list regime (an index, the score as the
//  order key). The records are the same records: the section decides which
//  fields of the position carry the meaning, so a demo built from two
//  separate sets would prove nothing about that.
//

import WenshuBoardKit

enum BoardCanvasDemo {

    /// The demo board's cards, laid out loosely on a plane.
    static let elements: [BoardElement] = {
        let board = BoardElement(
            id: "demo-board",
            kind: .board,
            location: BoardLocation(section: .canvas),
            content: BoardContent(title: "A column of cards")
        )
        let placements: [(x: Double, y: Double, title: String, body: String)] = [
            (40, 40, "First contact", "A card on the canvas carries an x and a y, not an index."),
            (260, 40, "Order is the score", "The score is the z-order here, and the order key in the list regime."),
            (480, 40, "Free placement", "Nothing forces these into a column."),
            (40, 220, "The grid", "The dot grid is this client's own cell size, not either reference's."),
            (260, 220, "Zoom", "A magnify gesture keeps the point under the cursor under the cursor."),
            (480, 220, "Pan", "A drag on the background moves the world, once per event."),
            (40, 400, "Culling", "An item off screen is not drawn and not hit tested."),
            (260, 400, "Z order", "The score decides who is on top."),
            (480, 400, "One model", "The list regime and the canvas regime read the same record."),
        ]
        let canvasCards = placements.enumerated().map { index, placement in
            BoardElement(
                id: "canvas-card-\(index)",
                kind: .card,
                location: BoardLocation(
                    parentID: board.id,
                    section: .canvas,
                    position: BoardLocation.Position(
                        x: placement.x,
                        y: placement.y,
                        score: Int64(index)
                    )
                ),
                content: BoardContent(title: placement.title, body: placement.body)
            )
        }
        // The SAME record set in the other regime: the section decides which
        // fields of the position are read, so these carry an index and an
        // order key instead of an x and a y.
        let listCards = (0..<5).map { index in
            BoardElement(
                id: "list-card-\(index)",
                kind: .card,
                location: BoardLocation(
                    parentID: board.id,
                    section: .inbox,
                    position: BoardLocation.Position(
                        index: index,
                        score: BoardOrderKey.key(forIndex: index)
                    )
                ),
                content: BoardContent(
                    title: "Beat \(index + 1)",
                    body: "The order key of this card is \(BoardOrderKey.key(forIndex: index))."
                )
            )
        }
        return canvasCards + listCards
    }()

    /// The cards of the list regime, in order by their order key.
    static var listCards: [BoardElement] {
        BoardOrderKey.ordered(elements.filter { $0.isInList }) { $0.orderKey ?? 0 }
    }
}
