//
//  BookmarkDomain.swift · Wenshu · v0.72 SwiftData migration 
//
//  Domain types for the bookmarks feature (= preserved from
//  the now-deleted BookmarkStore.swift actor).
//
//  History:
//    - v0.19 ticket 22: Bookmark struct + BookmarkStore actor
//      (= SQLite-backed; = Obsidian replica).
//    - : BookmarkStore deleted; pure value types
//      preserved here (= no SQLite dependency). SwiftData persistence
//      lives in WSBookmark @Model + WSBookmarkRepository.swift.
//
//  Per AGENTS.md §11.4 SwiftData migration spec, raw sqlite3 stores
//  are being phased out (= SwiftData @Model replaces them).
//

import Foundation

/// One bookmark row (= matches the old `bookmarks` table schema
/// from BookmarkStore.swift before deletion).
///
/// Domain type preserved 1:1 from the old BookmarkStore actor
/// (= id + docId + label + createdAt). SwiftData persistence in
/// WSBookmark + WSBookmarkRepository.
struct Bookmark: Equatable, Sendable, Identifiable {
    var id: String
    var docId: String
    var label: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        docId: String,
        label: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.docId = docId
        self.label = label
        self.createdAt = createdAt
    }
}
