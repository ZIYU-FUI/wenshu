//
//  Persistence/WSBookmark.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 4 of 21 @Model classes: WSBookmark.
//  Mirrors `bookmarks` table from BookmarkStore.swift (= v0.19 ticket 22).
//
//  Polymorphic design: a bookmark can anchor to EITHER a document OR a book
//  (= old schema used `doc_id` only). At least one of docID / bookID must be set
//  (= old schema required docID NOT NULL; = we relax to optional for richer use).
//
//  Tests verify exactly one anchor is set per bookmark.

import Foundation
import SwiftData

@Model
public final class WSBookmark {
    @Attribute(.unique) public var id: String
    var docID: String?
    var bookID: String?
    var title: String
    var note: String?
    var position: Int
    var createdAt: Date

    init(id: String, title: String, docID: String? = nil, bookID: String? = nil) {
        self.id = id
        self.title = title
        self.docID = docID
        self.bookID = bookID
        self.position = 0
        self.createdAt = Date()
    }

    /// Polymorphic invariant: a bookmark must anchor to exactly one parent
    /// (doc or book; = never both, never neither).
    var hasValidAnchor: Bool {
        (docID != nil) != (bookID != nil)
    }
}
