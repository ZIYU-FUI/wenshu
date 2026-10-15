//
//  Persistence/Repositories/WSBookmarkRepository.swift
//
//  v3.1 governance A1 refactor (= boundary probe continuation).
//  Apple canonical layering per Backyard Birds:
//    - write API = domain in (= Repository converts Bookmark -> WSBookmark @Model)
//    - read  API = @Model out (= caller converts WSBookmark -> Bookmark)
//
//  Public API after A1 probe:
//    - add(_ bookmark: Bookmark) throws            (write: domain in, persists @Model)
//    - remove(id:) throws                          (delete by id)
//    - list() throws -> [WSBookmark]               (read:  raw @Model out)
//
//  Caller-side conversion to Bookmark lives in caller =
//  BookmarkOps.load(...) / ArchivistStorage.listBookmarks() now does the
//  Bookmark() construction (not the data layer).
//
//  Per AGENTS.md §11.4.

import Foundation
import os
import SwiftData

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "wsbookmarkrepository")

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
                wenshuLogger.info("[wenshu.spotlight.auto] index failed after bookmark add: \(String(describing: error))")
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

    func list() throws -> [WSBookmark] {
        let descriptor = FetchDescriptor<WSBookmark>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
