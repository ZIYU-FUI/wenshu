//
//  Persistence/WSOutlineNode.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 16 of 21 @Model classes: WSOutlineNode.
//  Mirrors `outline_entries` table from WenshuWorkspace.swift.
//
//  Hierarchical outline (= a chapter's structure; = self-referential
//  via `parent` property; = recursive 1↔N children).
//
//  Old schema columns:
//    - id: TEXT PRIMARY KEY
//    - book_id: TEXT NOT NULL (= redundant with chapter; = derive from chapter)
//    - level: INTEGER (= depth in tree; = derive from parent depth)
//    - title: TEXT
//    - line_number: INTEGER
//    - parent_id: TEXT (= FK to outline_entries.id; = self-referential)
//
//  SwiftData representation:
//    - chapter: parent chapter (inverse declared on WSChapter.outlineNodes)
//    - parent: parent node (= plain Optional to avoid circular ref)
//    - children: @Relationship on WSOutlineNode (= recursive; = to-many)
//
//  The `level` and `book_id` fields are DERIVED (= not stored) — level
//  from parent depth, book from chapter.book.bookID.

import Foundation
import SwiftData

@Model
final class WSOutlineNode {
    @Attribute(.unique) var id: String
    /// FK to WSChapter.id (= redundant with book_id but kept for query convenience)
    var chapterID: String
    var title: String
    /// Line number within chapter file (= anchor in source text)
    var lineNumber: Int?
    /// FK to parent WSOutlineNode.id (= self-referential; = nil for root)
    var parentID: String?
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSChapter.outlineNodes)
    var chapter: WSChapter?

    /// Parent node (= plain Optional to avoid SwiftData circular reference)
    var parent: WSOutlineNode?

    /// Recursive children (= self-referential 1↔N; = inverse = parent)
    @Relationship(deleteRule: .nullify, inverse: \WSOutlineNode.parent)
    var children: [WSOutlineNode] = []

    init(id: String, chapterID: String, title: String, lineNumber: Int? = nil, parentID: String? = nil) {
        self.id = id
        self.chapterID = chapterID
        self.title = title
        self.lineNumber = lineNumber
        self.parentID = parentID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
