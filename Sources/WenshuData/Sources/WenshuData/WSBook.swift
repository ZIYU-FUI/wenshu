//
//  Persistence/WSBook.swift
//
//   : WSBook.
//  Mirrors `books` table from WenshuWorkspace.swift.
//  Central entity of wenshu's data model (= a book holds chapters,
//  characters, world).
//
//  Schema (= 1:1 with old sqlite3 `books`):
//    - id: TEXT PRIMARY KEY
//    - title: TEXT NOT NULL
//    - idea: TEXT (= book synopsis)
//    - length: INTEGER (= target word/page count)
//    - shelf_id: TEXT (FK to WSBookShelf.id)
//    - created_at: REAL
//    - updated_at: REAL
//
//  Children (= all 1↔N; will be added in subsequent commits):
//    - WSChapter        (= commit 16)

import Foundation
import SwiftData

@Model
public final class WSBook {
    @Attribute(.unique) public var id: String
    public var title: String
    public var idea: String?
    public var length: Int?
    public var shelfID: String?
    public var createdAt: Date
    public var updatedAt: Date

    /// Inverse relationship target (= declared on WSBookShelf.books)
    public var shelf: WSBookShelf?

    /// 1↔N WSEntity (= per-book entities of any kind: person /
    /// location / object / ability / event). Replaces the
    /// `worlds` + `characters` relationships with a single
    /// `entities` collection (= kind-discriminated; = see
    /// WSEntity.swift for the 5-kind enum).
    @Relationship(deleteRule: .cascade, inverse: \WSEntity.book)
    public var entities: [WSEntity] = []

    public init(id: String, title: String, idea: String? = nil, length: Int? = nil, shelfID: String? = nil) {
        self.id = id
        self.title = title
        self.idea = idea
        self.length = length
        self.shelfID = shelfID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
