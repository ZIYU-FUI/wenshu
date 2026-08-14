// Book.swift · Wenshu (Wenshu) · v0.02.1 (book module)
//
// Domain model for a single book (= a novel the user is writing).
// v0.02.1 ships just the book + its persistence; chapter content
// (= .md files inside the book's directory) lands in v0.03.0 alongside
// the EDITOR module.
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆
// 东西'. The shape of Book is locked by `Tests/WenshuAppTests/Domain/
// BookTests.swift`. Adding any required field forces the architectural
// decision to surface (= not just an incidental change in some file).
//
// Storage layout (= Apple HIG document-based app convention, building
// on the v0.02.0 shelf layout):
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json
//     books/<book-id-uuid>/
// book.json             ← encoded Book (this file)
//       chapters/<chapter-id-uuid>.md  (v0.03.0)
//
// id == directory name (= UUID string) so renames don't break the
// filesystem identity (= Apple HIG: URL = identity, name = label).

import Foundation

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    /// Author name; empty string = no author specified (= wenshu doesn't
    /// require one; we just record whatever the user types).
    var author: String
    /// Parent bookshelf (= filesystem constraint: the book's directory
    /// must live under its parent shelf's `books/`). Required at init so
    /// no orphan books ever land on disk.
    let shelfId: UUID
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        shelfId: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.shelfId = shelfId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filesystem directory name (= UUID string form). Stable across
    /// rename (= Apple HIG document-based app: id is the filesystem
    /// identity, title is just the display label).
    var directoryName: String {
        id.uuidString
    }

    // id-based identity (= Apple HIG document-based convention).
    // Renaming changes `title` but NOT `id`, so `book == book` still
    // holds across renames (critical for SwiftUI List diffing,
    // @Observable change detection, and selection identity in
    // WenshuLibrary).
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}