//
//  Persistence/WSBookShelf.swift · Wenshu · v0.72 SwiftData migration Phase 1
//
//  Migration commit 15 of 21 @Model classes: WSBookShelf.
//  Mirrors implicit "shelves" container (= wenshu has 1+ shelves per library;
//  = shelves = directories under .ws/shelves/, = no DB row in old schema but
//  SwiftData benefits from explicit representation).
//
//  1↔N to WSBook (= shelf contains books). Same SwiftData pattern as
//  WSSession.children: parent @Relationship, child plain Optional.

import Foundation
import SwiftData

@Model
final class WSBookShelf {
    @Attribute(.unique) var id: String
    var name: String
    /// Sort position within library (= for ordering in sidebar)
    var position: Int
    var createdAt: Date
    var updatedAt: Date

    /// 1↔N WSBook via inverse = WSBook.shelf
    @Relationship(deleteRule: .nullify, inverse: \WSBook.shelf)
    var books: [WSBook] = []

    init(id: String, name: String, position: Int = 0) {
        self.id = id
        self.name = name
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
