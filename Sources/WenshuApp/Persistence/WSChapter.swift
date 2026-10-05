//
//  Persistence/WSChapter.swift
//
//   : WSChapter.
//  Mirrors chapters = filesystem directories (= .ws/shelves/<shelf-id>/books/<book-id>/chapters/).
//  Old schema had no chapters table (= chapters were filesystem-only);
//  SwiftData introduces explicit representation.

import Foundation
import SwiftData

@Model
final class WSChapter {
    @Attribute(.unique) var id: String
    /// FK to WSBook.id
    var bookID: String
    var title: String
    /// Position within book (= sort order)
    var position: Int
    /// Word count (= updated by editor on save)
    var wordCount: Int
    /// Draft status: "draft" / "in_review" / "published"
    var status: String
    /// Short summary (= editable; = shown in the sidebar list).
    var summary: String
    /// The chapter body markdown (= was a separate .md file in the
    /// pre-v2.6 FileSystemChapterStore; = now stored inline in the
    /// SwiftData row so chapter content is fully captured by the
    /// SwiftData schema).
    var body: String
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBook)
    var book: WSBook?

    /// 1↔N WSOutlineNode (= chapter's outline tree; = self-referential hierarchy
    /// handled by WSOutlineNode.parent)
    @Relationship(deleteRule: .cascade, inverse: \WSOutlineNode.chapter)
    var outlineNodes: [WSOutlineNode] = []

    init(
        id: String,
        bookID: String,
        title: String,
        position: Int,
        status: String = "draft",
        summary: String = "",
        body: String = ""
    ) {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.position = position
        self.wordCount = 0
        self.status = status
        self.summary = summary
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
