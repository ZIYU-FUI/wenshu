//
//  FullTextSearchTests.swift · Wenshu · v0.19 ticket 17
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("FullTextSearch (Obsidian replica)")
struct FullTextSearchTests {

    private func makeTempSearch() async throws -> FullTextSearch {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        let search = try FullTextSearch(path: tmp.path)
        try await search.bootstrap()
        return search
    }

    @Test("index + search 中文整词命中 (trigram tokenizer)")
    func indexAndSearch() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "红楼梦", body: "林黛玉进贾府")
        let results = try await s.search(query: "林黛玉")
        #expect(results.count >= 1)
        #expect(results.first?.docId == "doc-1")
    }

    @Test("highlight 含 <mark>")
    func highlightMark() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "test", body: "林黛玉 is a character")
        let results = try await s.search(query: "林黛玉")
        #expect(results.count >= 1)
        #expect(results[0].snippet.contains("<mark>"), "snippet 应包含 <mark> 高亮")
        #expect(results[0].snippet.contains("</mark>"))
    }

    @Test("英文 search 命中")
    func englishSearch() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "hello world", body: "the quick brown fox")
        try await s.index(docId: "doc-2", title: "another doc", body: "lazy dog sleeping")

        let results = try await s.search(query: "quick")
        #expect(results.count == 1)
        #expect(results[0].docId == "doc-1")
    }

    @Test("英文 phrase 查询")
    func englishPhraseQuery() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "t", body: "the quick brown fox")
        try await s.index(docId: "doc-2", title: "t", body: "the quick and brown")

        let results = try await s.search(query: "\"quick brown\"")
        #expect(results.count == 1)
        #expect(results[0].docId == "doc-1")
    }

    @Test("empty query 返回空")
    func emptyQuery() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "t", body: "test")
        let results = try await s.search(query: "")
        #expect(results.isEmpty)
    }

    @Test("remove 删除文档后再搜不到")
    func remove() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "t", body: "红楼梦")
        try await s.remove(docId: "doc-1")
        let results = try await s.search(query: "红楼梦")
        #expect(results.isEmpty)
    }

    @Test("upsert: 同一 docId 重新 index 覆盖旧内容")
    func upsert() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "old", body: "old content apple banana")
        try await s.index(docId: "doc-1", title: "new", body: "new content apple banana")
        let resultsOld = try await s.search(query: "old content")
        #expect(resultsOld.isEmpty, "旧内容应已被覆盖")
    }

    @Test("BM25 排名: 多次出现词的相关度更高")
    func bm25Rank() async throws {
        let s = try await makeTempSearch()
        try await s.index(docId: "doc-1", title: "t", body: "apple banana orange")
        try await s.index(docId: "doc-2", title: "t", body: "apple banana orange apple banana orange apple banana orange")

        let results = try await s.search(query: "apple")
        #expect(results.count == 2)
        // doc-2 rank 应比 doc-1 更低 (更相关)
        #expect(results[0].docId == "doc-2", "多次出现的 doc 应排第一")
    }

    @Test("limit 限制")
    func limitResults() async throws {
        let s = try await makeTempSearch()
        for i in 0..<10 {
            try await s.index(docId: "doc-\(i)", title: "t", body: "apple chapter \(i) banana orange")
        }
        let results = try await s.search(query: "apple", limit: 3)
        #expect(results.count == 3)
    }
}
