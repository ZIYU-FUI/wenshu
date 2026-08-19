//
//  BookmarkStoreTests.swift · Wenshu · v0.19 ticket 22
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BookmarkStore (Obsidian replica)")
struct BookmarkStoreTests {

    private func makeTempStore() async throws -> BookmarkStore {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        let store = try BookmarkStore(path: tmp.path)
        try await store.bootstrap()
        return store
    }

    @Test("add + list")
    func addAndList() async throws {
        let store = try await makeTempStore()
        let bookmark = Bookmark(docId: "doc-1", label: "重要章节")
        try await store.add(bookmark)

        let list = try await store.list()
        #expect(list.count == 1)
        #expect(list[0].label == "重要章节")
        #expect(list[0].docId == "doc-1")
    }

    @Test("多书签按 created_at DESC 排序")
    func multipleBookmarksOrder() async throws {
        let store = try await makeTempStore()
        try await store.add(Bookmark(docId: "doc-1", label: "first", createdAt: Date(timeIntervalSince1970: 1000)))
        try await store.add(Bookmark(docId: "doc-2", label: "second", createdAt: Date(timeIntervalSince1970: 2000)))
        try await store.add(Bookmark(docId: "doc-3", label: "third", createdAt: Date(timeIntervalSince1970: 3000)))

        let list = try await store.list()
        #expect(list.map { $0.label } == ["third", "second", "first"])
    }

    @Test("remove 按 id")
    func removeById() async throws {
        let store = try await makeTempStore()
        let bookmark = Bookmark(docId: "doc-1", label: "临时")
        try await store.add(bookmark)
        try await store.remove(id: bookmark.id)

        let list = try await store.list()
        #expect(list.isEmpty)
    }

    @Test("remove 不存在的 id 不报错")
    func removeNonexistent() async throws {
        let store = try await makeTempStore()
        try await store.remove(id: "不存在的id")
        let list = try await store.list()
        #expect(list.isEmpty)
    }

    @Test("加重复 id 失败 (PRIMARY KEY 冲突)")
    func addDuplicateId() async throws {
        let store = try await makeTempStore()
        let id = "duplicate-id"
        try await store.add(Bookmark(id: id, docId: "doc-1", label: "first"))
        await #expect(throws: BookmarkStoreError.self) {
            _ = try await store.add(Bookmark(id: id, docId: "doc-2", label: "second"))
        }
    }

    @Test("list 空 store")
    func listEmpty() async throws {
        let store = try await makeTempStore()
        let list = try await store.list()
        #expect(list.isEmpty)
    }
}
