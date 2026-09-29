// BookmarkDomain.swift · WenshuApp · v0.72
//
// Domain types for the bookmarks feature (= pure value types; no
// SQLite dependency). SwiftData persistence lives in `WSBookmark`
// @Model + `WSBookmarkRepository`.
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
