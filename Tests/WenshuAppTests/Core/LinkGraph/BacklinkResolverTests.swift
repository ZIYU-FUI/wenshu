//
//  BacklinkResolverTests.swift · Wenshu · v0.19 ticket 12
//  单元测试: BacklinkResolver resolve / backlinks / forwardLinks
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("BacklinkResolver (Obsidian replica)")
struct BacklinkResolverTests {

    // Mock DocumentIndexing, 模拟 doc name ↔ docId 映射
    actor MockDocumentIndex: DocumentIndexing {
        private var nameToId: [String: String] = [:]
        private var idToName: [String: String] = [:]

        func setMapping(name: String, docId: String) {
            nameToId[name] = docId
            idToName[docId] = name
        }

        nonisolated func docId(forName name: String) async -> String? {
            await self.lookupDocId(forName: name)
        }

        nonisolated func name(forDocId docId: String) async -> String? {
            await self.lookupName(forDocId: docId)
        }

        private func lookupDocId(forName name: String) -> String? { nameToId[name] }
        private func lookupName(forDocId docId: String) -> String? { idToName[docId] }
    }

    private func makeTempSetup() async throws -> (LinkIndex, BacklinkResolver, MockDocumentIndex) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
        let index = try LinkIndex(path: tmp.path)
        try await index.bootstrap()
        let docIndex = MockDocumentIndex()
        let resolver = BacklinkResolver(index: index, documentIndex: docIndex)
        return (index, resolver, docIndex)
    }

    @Test("resolve 解析 markdown + 入库")
    func resolveContent() async throws {
        let (_, resolver, docIndex) = try await makeTempSetup()
        await docIndex.setMapping(name: "林黛玉", docId: "doc-LD")

        try await resolver.resolve(
            content: "第一回 [[林黛玉]] 进贾府, 又见 [[贾宝玉]]。",
            sourceDocId: "doc-chapter-1"
        )

        let forward = try await resolver.forwardLinks(forDocId: "doc-chapter-1")
        #expect(forward.count == 2)
    }

    @Test("resolve 清空旧链接再入库 (重写场景)")
    func resolveOverwrite() async throws {
        let (_, resolver, docIndex) = try await makeTempSetup()
        await docIndex.setMapping(name: "林黛玉", docId: "doc-LD")

        try await resolver.resolve(content: "[[林黛玉]] 旧版", sourceDocId: "doc-A")
        try await resolver.resolve(content: "[[贾宝玉]] 新版", sourceDocId: "doc-A")

        let forward = try await resolver.forwardLinks(forDocId: "doc-A")
        #expect(forward.count == 1, "重写应清空旧链接, 只保留新的")
        #expect(forward[0].targetRef == "贾宝玉")
    }

    @Test("backlinks 按 docId 查 (resolved)")
    func backlinksByDocId() async throws {
        let (_, resolver, docIndex) = try await makeTempSetup()
        await docIndex.setMapping(name: "林黛玉", docId: "doc-LD")

        try await resolver.resolve(content: "[[林黛玉]]", sourceDocId: "doc-A")
        try await resolver.resolve(content: "[[林黛玉]]", sourceDocId: "doc-B")

        let backlinks = try await resolver.backlinks(forDocId: "doc-LD")
        #expect(backlinks.count == 2)
    }

    @Test("backlinks 按 name 查 (unresolved)")
    func backlinksByName() async throws {
        let (_, resolver, _) = try await makeTempSetup()

        try await resolver.resolve(content: "[[林黛玉]]", sourceDocId: "doc-A")
        try await resolver.resolve(content: "[[林黛玉]]", sourceDocId: "doc-B")

        let backlinks = try await resolver.backlinks(forName: "林黛玉")
        #expect(backlinks.count == 2)
    }

    @Test("[[未存在的 name]] 入库 targetDocId 为 NULL")
    func unresolvedLink() async throws {
        let (_, resolver, _) = try await makeTempSetup()

        try await resolver.resolve(content: "[[未来角色]]", sourceDocId: "doc-A")

        let forward = try await resolver.forwardLinks(forDocId: "doc-A")
        #expect(forward.count == 1)
        #expect(forward[0].targetDocId == nil)
    }

    @Test("空内容 resolve 不报错")
    func resolveEmpty() async throws {
        let (_, resolver, _) = try await makeTempSetup()

        try await resolver.resolve(content: "", sourceDocId: "doc-A")

        let forward = try await resolver.forwardLinks(forDocId: "doc-A")
        #expect(forward.isEmpty)
    }

    @Test("中英文混合链接")
    func mixedLanguage() async throws {
        let (_, resolver, docIndex) = try await makeTempSetup()
        await docIndex.setMapping(name: "Chapter 1", docId: "doc-en")

        try await resolver.resolve(
            content: "[[Chapter 1]] 与 [[第一章]] 并存",
            sourceDocId: "doc-A"
        )

        let forward = try await resolver.forwardLinks(forDocId: "doc-A")
        #expect(forward.count == 2)
        let refs = forward.map { $0.targetRef }
        #expect(refs.contains("Chapter 1"))
        #expect(refs.contains("第一章"))
    }
}
