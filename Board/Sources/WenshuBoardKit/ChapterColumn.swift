//
//  ChapterColumn.swift
//  WenshuBoard
//
//  The join between the shared data tier and the card model.
//
//  Wenshu's chapter is a Markdown file. The card model needs a chapter to be
//  a list of addressable cards. This is the one place the two meet, and it
//  is deliberately a pure function: the shared tier owns the data, the card
//  layer owns the shape, and neither reaches into the other.
//
//  The file tier is the production path. A SwiftData chapter row exists, is
//  in the schema, and holds zero rows on a live library (= the store that
//  would populate it is never instantiated in production), so the row path
//  below is for a migrated library, not for the common case.
//

import Foundation
import WenshuData

/// Builds a card column out of a Wenshu chapter.
public enum ChapterColumnBuilder {

    /// The board element that stands for the chapter itself.
    ///
    /// A board with no parent: the chapter is the root of its own tree, the
    /// way the reference's workspace root board is.
    public static func board(
        id: String,
        title: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> BoardElement {
        BoardElement(
            id: id,
            kind: .board,
            location: BoardLocation(section: .canvas, position: BoardLocation.Position()),
            content: BoardContent(title: title),
            meta: BoardMeta(
                creator: nil,
                modifiedBy: nil,
                createdTime: createdAt,
                modifiedTime: updatedAt,
                significantModified: updatedAt,
                platform: nil,
                versionID: nil
            )
        )
    }

    /// The board element for a chapter read from the file tier.
    public static func board(for file: ChapterFile) -> BoardElement {
        board(id: file.id, title: file.title, updatedAt: file.modifiedAt)
    }

    /// The cards of a chapter read from the file tier.
    public static func cards(for file: ChapterFile) -> [BoardElement] {
        cards(id: file.id, body: file.markdown)
    }

    /// The cards of a chapter held in a SwiftData row.
    public static func cards(for chapter: WSChapter) -> [BoardElement] {
        cards(id: chapter.id, body: chapter.body)
    }

    /// The cards of a chapter body.
    ///
    /// The split is on the ATX level-two heading, because that is the level a
    /// chapter's beats are written at: a level-one heading is the chapter's own
    /// title and belongs to the board, not to a card. A chapter with no
    /// level-two heading is one card, so no chapter is ever lost.
    public static func cards(id: String, body: String) -> [BoardElement] {
        splitIntoBlocks(body).enumerated().map { offset, block in
            BoardElement(
                id: "\(id)-card-\(offset)",
                kind: .card,
                location: BoardLocation(
                    parentID: id,
                    section: .inbox,
                    position: BoardLocation.Position(
                        index: offset,
                        score: BoardOrderKey.key(forIndex: offset)
                    )
                ),
                content: BoardContent(title: block.title, body: block.markdown),
                meta: BoardMeta()
            )
        }
    }

    /// A heading and the markdown under it.
    struct Block: Equatable {
        var title: String
        var markdown: String
    }

    /// Split a Markdown body on its level-two headings.
    ///
    /// Text before the first level-two heading is dropped: it belongs to the
    /// chapter, and the chapter's own title is the board's title.
    static func splitIntoBlocks(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        var title: String?
        var body: [String] = []

        func flush() {
            guard let heading = title else { return }
            blocks.append(Block(title: heading, markdown: body.joined(separator: "\n")))
            title = nil
            body = []
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## ") {
                flush()
                title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                body = [String(line)]
            } else if title != nil {
                body.append(String(line))
            }
        }
        flush()

        if blocks.isEmpty {
            // A chapter with no level-two heading is one card, so the chapter
            // is never lost by the split.
            let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [Block(title: "", markdown: trimmed)]
        }
        return blocks
    }
}
