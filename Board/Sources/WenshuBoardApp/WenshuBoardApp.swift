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
            // A proof run that produced nothing must not report success.
            let written = RenderProof.write(to: directory)
            exit(written == RenderProof.expectedBitmaps ? 0 : 1)
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

/// The column's own metrics.
///
/// The client's design token layer is an open decision (AGENTS.md 5.3), so
/// the values live here, named, until it lands. Nothing in this file spells a
/// bare number into a layout call.
private enum ColumnMetrics {
    static let titleInset: CGFloat = 20
    static let titleSpacing: CGFloat = 16
    static let cardSpacing: CGFloat = 4
    static let cardInset: CGFloat = 8
}

/// One column of cards.
struct BoardColumnView: View {
    let column: BoardColumn

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(column.title)
                .font(.headline)
                .padding(.horizontal, ColumnMetrics.titleInset)
                .padding(.vertical, ColumnMetrics.titleSpacing)
            Divider()
            List(column.orderedCards, id: \.id) { card in
                VStack(alignment: .leading, spacing: ColumnMetrics.cardSpacing) {
                    Text(card.content.title ?? card.id)
                        .font(.body)
                    Text(card.content.body ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, ColumnMetrics.cardInset)
            }
        }
    }
}

/// A column of cards: the board plus its ordered children.
struct BoardColumn {
    var title: String
    var cards: [BoardElement]

    /// The cards of the list regime, in order by their order key.
    ///
    /// The section decides which regime reads which fields of the position,
    /// so the column reads the index and the order key, and the canvas
    /// records are not listed here.
    var orderedCards: [BoardElement] {
        BoardOrderKey.ordered(cards.filter { $0.isInList }) { $0.orderKey ?? 0 }
    }

    /// A column with no library behind it, so the app can be looked at
    /// without a writer conflict.
    ///
    /// It reads the demo record set, so the column and the canvas show two
    /// views of the SAME records.
    static var demo: BoardColumn {
        BoardColumn(
            title: "A column of cards",
            cards: BoardCanvasDemo.elements
        )
    }
}
