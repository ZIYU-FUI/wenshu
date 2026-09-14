//
//  Persistence/Repositories/WSBookmarkRepository.swift · Wenshu · v0.72 SwiftData migration Phase 2
//
//  Migration commit 25 of 42: WSBookmarkRepository.
//  Per AGENTS.md §11.4.
//
//  SwiftData @Model replacement for BookmarkStore actor (= v0.19
//  ticket 22). Phase 5 ticket 10b deleted BookmarkStore.
//
//  Public API (preserved 1:1 from old BookmarkStore actor):
//    - add(_ bookmark: Bookmark) throws
//    - remove(id:) throws
//    - list() throws -> [Bookmark]
//
//  Domain type (preserved): Bookmark (= id + docId + label + createdAt;
//  = note: WSBookmark adds docID/bookID polymorphic anchor + note + position;
//  = migration upgrade).
//
//  Bookmark mapping: WSBookmark.docID → Bookmark.docId; WSBookmark.title → Bookmark.label.

import Foundation
import SwiftData

@MainActor
public final class WSBookmarkRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    public func add(_ bookmark: Bookmark) throws {
        let model = WSBookmark(
            id: bookmark.id,
            title: bookmark.label,
            docID: bookmark.docId
        )
        context.insert(model)
        try context.save()
    }

    public func remove(id: String) throws {
        let descriptor = FetchDescriptor<WSBookmark>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    public func list() throws -> [Bookmark] {
        let descriptor = FetchDescriptor<WSBookmark>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { model in
            Bookmark(
                id: model.id,
                docId: model.docID ?? "",
                label: model.title,
                createdAt: model.createdAt
            )
        }
    }
}
