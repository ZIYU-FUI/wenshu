//
//  MemoryStoreTests.swift · Wenshu · v0.17 ticket 01 (hermes replica)
//
//  单元测试 SQLite-backed MemoryStore. 临时文件 db, 测试后自动删除.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("MemoryStore (hermes replica)")
struct MemoryStoreTests {
    /// 测试用临时 db 路径
    private static func tempDBPath() -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("test.db").path
    }

    @Test("add + search round-trip 1 memory")
    func testAddSearch() async throws {
        let store = try MemoryStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let memory = try await store.add(userId: "u1", content: "老板喜欢 1 PT 拖拽线")
        let results = try await store.search(userId: "u1", query: "1 PT")
        #expect(results.count == 1)
        #expect(results.first?.memoryId == memory.memoryId)
        #expect(results.first?.content == "老板喜欢 1 PT 拖拽线")
    }

    @Test("get + update + delete")
    func testGetUpdateDelete() async throws {
        let store = try MemoryStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let memory = try await store.add(userId: "u1", content: "old content")
        let got = try await store.get(memoryId: memory.memoryId)
        #expect(got?.content == "old content")
        try await store.update(memoryId: memory.memoryId, content: "new content")
        let updated = try await store.get(memoryId: memory.memoryId)
        #expect(updated?.content == "new content")
        try await store.delete(memoryId: memory.memoryId)
        let deleted = try await store.get(memoryId: memory.memoryId)
        #expect(deleted == nil)
    }

    @Test("search 不通 user 隔离")
    func testUserIsolation() async throws {
        let store = try MemoryStore(path: Self.tempDBPath())
        try await store.bootstrap()
        _ = try await store.add(userId: "alice", content: "alice secret")
        _ = try await store.add(userId: "bob", content: "bob secret")
        let aliceResults = try await store.search(userId: "alice", query: "secret")
        let bobResults = try await store.search(userId: "bob", query: "secret")
        #expect(aliceResults.count == 1)
        #expect(aliceResults.first?.userId == "alice")
        #expect(bobResults.count == 1)
        #expect(bobResults.first?.userId == "bob")
    }

    @Test("count 准确")
    func testCount() async throws {
        let store = try MemoryStore(path: Self.tempDBPath())
        try await store.bootstrap()
        #expect((try? await store.count(userId: "u1")) ?? -1 == 0)
        _ = try await store.add(userId: "u1", content: "first")
        _ = try await store.add(userId: "u1", content: "second")
        _ = try await store.add(userId: "u1", content: "third")
        #expect((try? await store.count(userId: "u1")) ?? -1 == 3)
    }
}