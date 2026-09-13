//
//  Persistence/WSBook.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Phase 1 commit 15/21: WSBook.
//  Mirrors `books` table from WenshuWorkspace.swift.
//  Central entity of wenshu's data model (= a book holds chapters, outline,
//  foreshadowing, placeholders, characters, world).
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
//    - WSOutlineNode    (= commit 17)
//    - WSForeshadowing  (= commit 18)
//    - WSPlaceholder    (= commit 19)

import Foundation
import SwiftData

@Model
public final class WSBook {
    @Attribute(.unique) public var id: String
    var title: String
    var idea: String?
    var length: Int?
    var shelfID: String?
    var createdAt: Date
    var updatedAt: Date

    /// Inverse relationship target (= declared on WSBookShelf.books)
    var shelf: WSBookShelf?

    /// 1↔N WSWorld (= per-book world-building entries)
    @Relationship(deleteRule: .cascade, inverse: \WSWorld.book)
    var worlds: [WSWorld] = []

    /// 1↔N WSCharacter (= per-book fictional people)
    @Relationship(deleteRule: .cascade, inverse: \WSCharacter.book)
    var characters: [WSCharacter] = []

    /// 1↔N WSOutlineDocument (= per-book outline .md files; = metadata index)
    @Relationship(deleteRule: .cascade, inverse: \WSOutlineDocument.book)
    var outlineDocuments: [WSOutlineDocument] = []

    /// 1↔N WSForeshadowing (= tracked foreshadowing events)
    @Relationship(deleteRule: .cascade, inverse: \WSForeshadowing.book)
    var foreshadowings: [WSForeshadowing] = []

    /// 1↔N WSPlaceholder (= TODO / FIXME markers in draft)
    @Relationship(deleteRule: .cascade, inverse: \WSPlaceholder.book)
    var placeholders: [WSPlaceholder] = []

    init(id: String, title: String, idea: String? = nil, length: Int? = nil, shelfID: String? = nil) {
        self.id = id
        self.title = title
        self.idea = idea
        self.length = length
        self.shelfID = shelfID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
