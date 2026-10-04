//
//  Persistence/Repositories/WSBookmarkRepository.swift
//
//  Migration commit 25 of 42: WSBookmarkRepository.
//  Per AGENTS.md §11.4.
//
//  SwiftData @Model replacement for BookmarkStore actor (= v0.19
//  ticket 22).  deleted BookmarkStore.
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
final class WSBookmarkRepository {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer = WSPersistenceContainer.shared) {
        self.container = container
    }

    func add(_ bookmark: Bookmark) throws {
        let model = WSBookmark(
            id: bookmark.id,
            title: bookmark.label,
            docID: bookmark.docId
        )
        context.insert(model)
        try context.save()

        // v2.9a ((see OOB.md #2026-09-28) OOB A8): bootstrap the new
        // bookmark into the Spotlight index (= Cmd-F should
        // surface bookmarks alongside chapters + references).
        let title = bookmark.label
        let docID = bookmark.id
        Task.detached(priority: .utility) {
            do {
                try await CSSearchableIndexSearch.shared.index(
                    docId: docID,
                    title: title,
                    body: title
                )
            } catch {
                NSLog("[wenshu.spotlight.auto] index failed after bookmark add: %@", String(describing: error))
            }
        }
    }

    func remove(id: String) throws {
        let descriptor = FetchDescriptor<WSBookmark>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()

            // v2.9a ((see OOB.md #2026-09-28) OOB A8): remove the
            // bookmark from the Spotlight index (= keeps the
            // index clean).
            Task.detached(priority: .utility) {
                try? await CSSearchableIndexSearch.shared.remove(docId: id)
            }
        }
    }

    func list() throws -> [Bookmark] {
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
