//
//  LinkIndexTests.swift · Wenshu · v0.19 ticket 12
//  单元测试: LinkIndex actor SQLite add / remove / searchForward / searchBackward
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("LinkIndex (Obsidian replica)")
struct LinkIndexTests {

    // 每个 test 用独立临时 SQLite, 避免互相污染 (v0.18 ticket 05 KanbanStore 同范式: cwd + UUID 临时目录)
    private func makeTempIndex() async throws -> LinkIndex {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        let index = try LinkIndex(path: tmp.path)
        try await index.bootstrap()
        return index
    }

    @Test("add 1 条链接 + searchForward")
    func addAndSearchForward() async throws {
        let index = try await makeTempIndex()
        let link = Link(sourceDocId: "doc-A", targetRef: "林黛玉", targetDocId: "doc-LD", line: 0, offset: 6)
        try await index.add(link)

        let forward = try await index.searchForward(sourceDocId: "doc-A")
        #expect(forward.count == 1)
        #expect(forward[0].targetRef == "林黛玉")
        #expect(forward[0].targetDocId == "doc-LD")
    }

    @Test("searchBackward 按 targetRef")
    func searchBackwardByRef() async throws {
        let index = try await makeTempIndex()
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "林黛玉", targetDocId: nil, line: 0, offset: 0))
        try await index.add(Link(sourceDocId: "doc-B", targetRef: "林黛玉", targetDocId: nil, line: 1, offset: 5))

        let backlinks = try await index.searchBackward(targetRef: "林黛玉")
        #expect(backlinks.count == 2)
    }

    @Test("searchBackward 按 targetDocId")
    func searchBackwardByDocId() async throws {
        let index = try await makeTempIndex()
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "林黛玉", targetDocId: "doc-LD", line: 0, offset: 0))
        try await index.add(Link(sourceDocId: "doc-B", targetRef: "林黛玉", targetDocId: "doc-LD", line: 1, offset: 5))

        let backlinks = try await index.searchBackward(targetDocId: "doc-LD")
        #expect(backlinks.count == 2)
    }

    @Test("removeAll 清空 doc 的所有链接")
    func removeAll() async throws {
        let index = try await makeTempIndex()
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "foo", targetDocId: nil, line: 0, offset: 0))
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "bar", targetDocId: nil, line: 1, offset: 0))

        try await index.removeAll(sourceDocId: "doc-A")
        let forward = try await index.searchForward(sourceDocId: "doc-A")
        #expect(forward.isEmpty)
    }

    @Test("add 重复链接 (同 sourceDocId + targetRef)")
    func addDuplicates() async throws {
        let index = try await makeTempIndex()
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "foo", targetDocId: nil, line: 0, offset: 0))
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "foo", targetDocId: nil, line: 1, offset: 5))

        let forward = try await index.searchForward(sourceDocId: "doc-A")
        #expect(forward.count == 2, "同 source 不同 line/offset 应保留两条")
    }

    @Test("searchForward 不存在的 doc 返回空")
    func searchForwardEmpty() async throws {
        let index = try await makeTempIndex()
        let forward = try await index.searchForward(sourceDocId: "doc-nonexistent")
        #expect(forward.isEmpty)
    }

    @Test("targetDocId 为 NULL 不影响 searchBackwardByRef")
    func searchBackwardWithNullDocId() async throws {
        let index = try await makeTempIndex()
        try await index.add(Link(sourceDocId: "doc-A", targetRef: "未创建的人物", targetDocId: nil, line: 0, offset: 0))

        let backlinks = try await index.searchBackward(targetRef: "未创建的人物")
        #expect(backlinks.count == 1)
    }
}
