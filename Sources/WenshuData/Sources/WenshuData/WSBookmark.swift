//
//  Persistence/WSBookmark.swift
//
//   : WSBookmark.
//  SwiftData @Model for bookmarks. Replaces `bookmarks` table from
//  BookmarkStore.swift (=  deleted BookmarkStore).
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
    public var docID: String?
    public var bookID: String?
    public var title: String
    public var note: String?
    public var position: Int
    public var createdAt: Date

    public init(id: String, title: String, docID: String? = nil, bookID: String? = nil) {
        self.id = id
        self.title = title
        self.docID = docID
        self.bookID = bookID
        self.position = 0
        self.createdAt = Date()
    }

    /// Polymorphic invariant: a bookmark must anchor to exactly one parent
    /// (doc or book; = never both, never neither).
    public var hasValidAnchor: Bool {
        (docID != nil) != (bookID != nil)
    }
}
