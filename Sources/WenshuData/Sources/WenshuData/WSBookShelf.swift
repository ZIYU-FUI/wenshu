//
//  Persistence/WSBookShelf.swift
//
//   : WSBookShelf.
//  Mirrors implicit "shelves" container (= wenshu has 1+ shelves per library;
//  = shelves = directories under .ws/shelves/, = no DB row in old schema but
//  SwiftData benefits from explicit representation).
//
//  1↔N to WSBook (= shelf contains books). Same SwiftData pattern as
//  WSSession.children: parent @Relationship, child plain Optional.

import Foundation
import SwiftData

@Model
public final class WSBookShelf {
    @Attribute(.unique) public var id: String
    public var name: String
    /// Sort position within library (= for ordering in sidebar)
    public var position: Int
    public var createdAt: Date
    public var updatedAt: Date

    /// 1↔N WSBook via inverse = WSBook.shelf
    @Relationship(deleteRule: .nullify, inverse: \WSBook.shelf)
    public var books: [WSBook] = []

    public init(id: String, name: String, position: Int = 0) {
        self.id = id
        self.name = name
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
