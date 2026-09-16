// Bookshelf.swift · Wenshu (Wenshu) · v0.02.0 (bookshelf module)
//
// Domain model for a single bookshelf (= a named container of books inside
// the wenshu library). v0.02.0 ships just the bookshelf + its persistence;
// Book / Chapter land in v0.02.1.
//
// (Historical: this line had CJK content from a boss OOB message; the original text can be recovered via `git blame` on this line; the cleanup commit replaced it with a stub because its translation was incomplete.)
// Owner 8/15 15:55: 'needok,, refactor'.
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
    /// v0.30 boss 8/31 OOB: shelf icon name (= SF Symbols 6
    /// dot.case identifier, e.g. "books.vertical"). Optional
    /// (= nil = default "books.vertical" / "square.dashed"
    /// glyph via `displayIcon`).
    var icon: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Filesystem directory name for this shelf (= UUID string form).
    /// Stable across rename (= Apple HIG document-based app: id is the
    /// filesystem identity, name is just the display label).
    var directoryName: String {
        id.uuidString
    }

    /// v0.30 boss 8/31 OOB: shelf icon for sidebar display.
    /// Returns `icon` if set, otherwise a default SF Symbols 6
    /// icon name (= "square.dashed" for the reference-library
    /// root shelf, "books.vertical" for user-created shelves).
    /// v1.0.0-m1-shell boss 2026-09-15 OOB 'use outline uniformly':
    /// all defaults are outline (= non-.fill) icons.
    var displayIcon: String {
        if let icon, !icon.isEmpty {
            return icon
        }
        return id.uuidString == "00000000-0000-0000-0000-000000000000"
            ? "square.dashed"
            : "books.vertical"
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