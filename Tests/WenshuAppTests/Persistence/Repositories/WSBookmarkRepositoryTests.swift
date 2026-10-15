//
//  Persistence/Repositories/WSBookmarkRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import Testing
import WenshuData
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
        try repo.add(id: "bm-1", title: "My anchor", docID: "doc-1")
        let list = try repo.list()
        #expect(list.count == 1)
        #expect(list[0].id == "bm-1")
        #expect(list[0].docID == "doc-1")
        #expect(list[0].label == "My anchor")
    }

    @Test("remove deletes the row")
    @MainActor
    func remove() throws {
        let repo = try makeRepository()
        try repo.add(id: "bm-1", title: "x", docID: "doc-1")
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
