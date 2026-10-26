// Sources/WenshuApp/Features/Editor/View/LinkedDocumentCardBoard.swift
//
// The board of documents an index points at.
//
// The app's own card (= the picture is the card, = the words sit on
// it), smaller than the material column's, = several on one row.
//
// The boss (2026-10-26): the index's link list read as plain text;
// = "我们的文档卡片有现成的, 能在文件中直接展示卡片吗" = the cards say
// the same thing in the shape the app already uses. The cards here
// are the picture only (= no moving cover): the moving cover is a
// separate thing the user asks for, = and a board of nine moving
// covers would be noise.

import SwiftUI

struct LinkedDocumentCardBoard: View {

    /// The documents the board shows.
    let documents: [BookDoc]

    /// Opens a document.
    let onOpen: (BookDoc) -> Void

    /// The board's card width (= smaller than the material column's,
    /// = so several cards sit on one row).
    private static let cardWidth: CGFloat = 132

    private var columns: [GridItem] {
        [GridItem(.fixed(Self.cardWidth), spacing: DesignTokens.spacingModerate)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.spacingModerate) {
            ForEach(documents) { document in
                Card(
                    source: .bookDoc(document),
                    onDoubleClick: { _ in onOpen(document) },
                    // The board is a reading view (= the material column
                    // owns the rename and delete menus).
                    onRename: {},
                    onDelete: {}
                )
                .frame(
                    width: Self.cardWidth,
                    height: Self.cardWidth / DesignTokens.coverTileRatio
                )
                .help(document.title)
            }
        }
    }
}
