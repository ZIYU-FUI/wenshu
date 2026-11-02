//
//  BoardCanvasDemo.swift
//  WenshuBoard
//
//  Demo elements for the canvas, placed in world coordinates.
//
//  These are the same records the list regime uses, with `location.section`
//  set to the canvas and `location.position.x` / `.y` set instead of
//  `position.index`. Nothing about the model changes between the two
//  regimes: the section decides which fields of the position are read.
//

import Foundation
import WenshuBoardKit

enum BoardCanvasDemo {

    /// The demo board's cards, laid out loosely on a plane.
    static let elements: [BoardElement] = {
        let board = BoardElement(
            id: "canvas-board",
            kind: .board,
            location: BoardLocation(section: .canvas),
            content: BoardContent(title: "A canvas of cards")
        )
        let placements: [(x: Double, y: Double, title: String, body: String)] = [
            (40, 40, "First contact", "A card on the canvas carries an x and a y, not an index."),
            (260, 40, "Order is the score", "The score is the z-order here, and the order key in the list regime."),
            (480, 40, "Free placement", "Nothing forces these into a column."),
            (40, 220, "The grid", "The dot grid is the reference's gridSize, drawn in world space."),
            (260, 220, "Zoom", "A magnify gesture keeps the point under the cursor under the cursor."),
            (480, 220, "Pan", "A drag on the background moves the world."),
            (40, 400, "Culling", "An item off screen is not drawn and not hit tested."),
            (260, 400, "Z order", "The score decides who is on top."),
            (480, 400, "One model", "The list regime and the canvas regime read the same record."),
        ]
        return placements.enumerated().map { index, placement in
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
    }()
}
