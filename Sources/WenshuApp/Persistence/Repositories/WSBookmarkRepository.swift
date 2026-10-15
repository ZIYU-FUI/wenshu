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

    func add(id: String, title: String, docID: String? = nil) throws -> WSBookmark {
        let model = WSBookmark(
            id: id,
            title: title,
            docID: docID
        )
        context.insert(model)
        try context.save()
        return model
    }

    func remove(id: String) throws {
        let descriptor = FetchDescriptor<WSBookmark>(
            predicate: #Predicate { $0.id == id }
        )
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    func list() throws -> [WSBookmark] {
        let descriptor = FetchDescriptor<WSBookmark>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
