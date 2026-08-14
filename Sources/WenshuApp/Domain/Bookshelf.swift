// Bookshelf.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Domain model for a single bookshelf (= a named container of books inside
// the wenshu library). v0.02.0 ships just the bookshelf + its persistence;
// Book / Chapter land in v0.02.1.
//
// Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西, 然后重构一堆东西'.
// The shape of Bookshelf is locked by `Tests/WenshuAppTests/Domain/
// BookshelfTests.swift` — any future change to required fields, id type,
// or Codable strategy must surface there first (= not silently in some
// downstream file).
//
// Storage layout (= Apple HIG document-based app convention):
//   ~/Documents/wenshu/<shelf-id-uuid>/
//     shelf.json              ← encoded Bookshelf
//     books/                  ← v0.02.1: book subdirs land here
//     chapters/               ← v0.02.1: chapter .md files land here
//
// id == directory name (= UUID string) for filesystem stability and to
// avoid name collisions on rename (= renames update `name`, not `id`).

import Foundation

struct Bookshelf: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filesystem directory name for this shelf (= UUID string form).
    /// Stable across rename (= Apple HIG document-based app: id is the
    /// filesystem identity, name is just the display label).
    var directoryName: String {
        id.uuidString
    }

    // id-based identity (= Apple HIG document-based app convention: URL
    // = identity, name = display label only). Renaming a shelf changes
    // `name` but NOT `id`, so `shelf == shelf` still holds across renames
    // (= critical for SwiftUI List selection / @Observable diffing / diff
    // identification in WenshuLibrary).
    static func == (lhs: Bookshelf, rhs: Bookshelf) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}