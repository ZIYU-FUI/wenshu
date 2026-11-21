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

    /// The stored picture of one card (= the same cover the material
    /// column shows; = the key namespaces the two card kinds apart),
    /// answered in ONE covers folder that arrives as a VALUE.
    ///
    /// THE ROOT ARRIVES, IT IS NOT FETCHED HERE. This board is the
    /// second grid door: `EditorView` renders `LinkedDocumentBoardSection`,
    /// which builds this board, and a `ForEach` that asked the
    /// root-resolving door per card would pay a UserDefaults read plus a
    /// bookmark decode inside the draw, once per card per pass (= B1's
    /// cost, met through a different grid than the material column's).
    /// The pass is bounded at ONE library visit by a counted row in
    /// `CoverLibraryLookupCountingTests`, which drives THIS door, and
    /// the shape is held by `CoverHotPathShapeTests` rule 3, which
    /// reads this file for the root-free door's name.
    func coverURL(for document: BookDoc, root: URL?) -> URL? {
        CardCoverService().entry(
            forKey: CardCoverService.key(forBookDoc: document.id),
            root: root
        ).imageURL
    }

    var body: some View {
        // ONE covers folder for the whole pass (= the same hoist the
        // material column got): the ForEach below draws a card per
        // document and every card asks its cover, so resolving the
        // library per card is preparation the frame must not do.
        let coversRoot = CardCoverService.coversRoot
        LazyVGrid(columns: columns, alignment: .leading, spacing: DesignTokens.spacingModerate) {
            ForEach(documents) { document in
                Card(
                    source: .bookDoc(document),
                    onDoubleClick: { _ in onOpen(document) },
                    // The board is a reading view (= the material column
                    // owns the rename and delete menus).
                    onRename: {},
                    onDelete: {},
                    // The picture is the card (= the boss: only the
                    // picture, = no moving cover on a board of nine).
                    coverImageURL: coverURL(for: document, root: coversRoot)
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
