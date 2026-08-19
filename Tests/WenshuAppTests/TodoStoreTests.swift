//
//  TodoStoreTests.swift · Wenshu · v0.18 ticket 06 (hermes replica)
//
//  单元测试本地 Todo. cwd 下临时 db.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("TodoStore (hermes replica)")
struct TodoStoreTests {
    private static func tempDBPath() -> String {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-todo-\(UUID().uuidString.prefix(8)).db")
            .path
    }

    @Test("add + get round-trip")
    func testAddGet() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let todo = try await store.add(title: "implement FileTools", priority: .high)
        let got = try await store.get(id: todo.id)
        #expect(got?.title == "implement FileTools")
        #expect(got?.status == .pending)
        #expect(got?.priority == .high)
    }

    @Test("setStatus 改 status")
    func testSetStatus() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let todo = try await store.add(title: "test")
        try await store.setStatus(id: todo.id, status: .inProgress)
        let updated = try await store.get(id: todo.id)
        #expect(updated?.status == .inProgress)
        try await store.setStatus(id: todo.id, status: .completed)
        let final = try await store.get(id: todo.id)
        #expect(final?.status == .completed)
    }

    @Test("list 按 status 过滤 + priority 排序")
    func testListByStatusPriority() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        _ = try await store.add(title: "low task", priority: .low)
        _ = try await store.add(title: "urgent task", priority: .urgent)
        _ = try await store.add(title: "medium task", priority: .medium)
        let pending = try await store.list(status: .pending)
        #expect(pending.count == 3)
        #expect(pending[0].priority == .urgent)
        #expect(pending[1].priority == .medium)
        #expect(pending[2].priority == .low)
    }

    @Test("delete 删 1 个")
    func testDelete() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let todo = try await store.add(title: "test")
        try await store.delete(id: todo.id)
        let got = try await store.get(id: todo.id)
        #expect(got == nil)
    }

    @Test("count 按 status 过滤")
    func testCount() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        _ = try await store.add(title: "a", priority: .high)
        _ = try await store.add(title: "b", priority: .medium)
        let todo1 = try await store.add(title: "c", priority: .low)
        try await store.setStatus(id: todo1.id, status: .completed)
        let pending = (try? await store.count(status: .pending)) ?? -1
        #expect(pending == 2)
        let completed = (try? await store.count(status: .completed)) ?? -1
        #expect(completed == 1)
    }

    @Test("dueDate 持久化")
    func testDueDate() async throws {
        let store = try TodoStore(path: Self.tempDBPath())
        try await store.bootstrap()
        let due = Date(timeIntervalSince1970: 1900000000)  // 2030-03-08
        let todo = try await store.add(title: "future task", priority: .urgent, dueDate: due)
        let got = try await store.get(id: todo.id)
        #expect(got?.dueDate?.timeIntervalSince1970 == 1900000000)
    }
}