//
//  Persistence/Repositories/WSBookmarkRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSBookmarkRepository (= SwiftData @Model BookmarkStore replacement)")
struct WSBookmarkRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSBookmarkRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSBookmarkRepository(container: container)
    }

    @Test("add + list round-trip")
    @MainActor
    func add() throws {
        let repo = try makeRepository()
        let bm = Bookmark(id: "bm-1", docId: "doc-1", label: "My anchor")
        try repo.add(bm)
        let list = try repo.list()
        #expect(list.count == 1)
        #expect(list[0].id == "bm-1")
        #expect(list[0].docId == "doc-1")
        #expect(list[0].label == "My anchor")
    }

    @Test("remove deletes the row")
    @MainActor
    func remove() throws {
        let repo = try makeRepository()
        try repo.add(Bookmark(id: "bm-1", docId: "doc-1", label: "x"))
        try repo.remove(id: "bm-1")
        let list = try repo.list()
        #expect(list.isEmpty)
    }

    @Test("list returns empty when no bookmarks")
    @MainActor
    func listEmpty() throws {
        let repo = try makeRepository()
        let list = try repo.list()
        #expect(list.isEmpty)
    }
}
