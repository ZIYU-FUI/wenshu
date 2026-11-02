//
//  WenshuBoardApp.swift
//  WenshuBoard
//
//  The card board, as its own app.
//
//  It does NOT touch the desktop app's sources and it does not open the
//  library: one library, one writer. The first slice shows the card column
//  the model produces, so the shape can be looked at before any of it is
//  wired to the shared store.
//

import SwiftUI
import WenshuBoardKit

@main
struct WenshuBoardApp: App {

    init() {
        // The proof path renders the canvas into a bitmap and leaves. It is
        // how a geometry claim gets looked at without a human and a window.
        if let directory = RenderProof.requestedDirectory() {
            RenderProof.write(to: directory)
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                BoardCanvasView(elements: BoardCanvasDemo.elements)
                    .tabItem {
                        Label("Canvas", systemImage: "square.grid.2x2")
                    }
                BoardColumnView(column: BoardColumn.demo)
                    .tabItem {
                        Label("Column", systemImage: "rectangle.stack")
                    }
            }
        }
        .defaultSize(width: 960, height: 720)
    }
}

/// One column of cards.
struct BoardColumnView: View {
    let column: BoardColumn

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(column.title)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            Divider()
            List(column.cards, id: \.id) { card in
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.content.title ?? card.id)
                        .font(.body)
                    Text(card.content.body ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

/// A column of cards: the board plus its ordered children.
struct BoardColumn {
    var title: String
    var cards: [BoardElement]

    /// The cards in order, by their order key.
    var orderedCards: [BoardElement] {
        BoardOrderKey.ordered(cards) { $0.orderKey ?? 0 }
    }

    /// A column with no library behind it, so the app can be looked at
    /// without a writer conflict.
    static var demo: BoardColumn {
        let board = BoardElement(
            id: "demo-board",
            kind: .board,
            location: BoardLocation(section: .canvas),
            content: BoardContent(title: "A column of cards")
        )
        let cards = (0..<5).map { index in
            BoardElement(
                id: "demo-card-\(index)",
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
                    title: "Card \(index + 1)",
                    body: "The order key of this card is \(BoardOrderKey.key(forIndex: index))."
                )
            )
        }
        return BoardColumn(title: board.content.title ?? "Board", cards: cards)
    }
}
