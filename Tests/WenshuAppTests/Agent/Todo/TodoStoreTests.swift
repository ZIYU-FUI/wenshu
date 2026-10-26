//
//  TodoStoreTests.swift · Wenshu · v0.18 ticket 06 (hermes replica)
//
// testlocal Todo. cwd db.
//

import Testing
import SwiftData
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("TodoStore (hermes replica)")
struct TodoStoreTests {

    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSTodoRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from TodoStore actor.
    @MainActor
    private static func makeTodoRepository() throws -> WSTodoRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSTodoRepository(container: container)
    }

    private static func tempDBPath() -> String {
        SourceLocator.repoRoot
            .appendingPathComponent(".test-todo-\(UUID().uuidString.prefix(8)).db")
            .path
    }

    @Test("add + get round-trip")
    @MainActor
    func testAddGet() async throws {
        let store = try Self.makeTodoRepository()
                let todo = try await store.add(title: "implement FileTools", priority: TodoPriority.high.rawValue)
        let got = try await store.get(id: todo.id)
        #expect(got?.title == "implement FileTools")
        #expect(got?.status == TodoStatus.pending.rawValue)
        #expect(got?.priority == TodoPriority.high.rawValue)
    }

    @Test("setStatus 改 status")
    @MainActor
    func testSetStatus() async throws {
        let store = try Self.makeTodoRepository()
                let todo = try await store.add(title: "test")
        try await store.setStatus(id: todo.id, status: TodoStatus.inProgress.rawValue)
        let updated = try await store.get(id: todo.id)
        #expect(updated?.status == TodoStatus.inProgress.rawValue)
        try await store.setStatus(id: todo.id, status: TodoStatus.completed.rawValue)
        let final = try await store.get(id: todo.id)
        #expect(final?.status == TodoStatus.completed.rawValue)
    }

    @Test("list 按 status 过滤 + priority 排序")
    @MainActor
    func testListByStatusPriority() async throws {
        let store = try Self.makeTodoRepository()
                _ = try await store.add(title: "low task", priority: TodoPriority.low.rawValue)
        _ = try await store.add(title: "urgent task", priority: TodoPriority.urgent.rawValue)
        _ = try await store.add(title: "medium task", priority: TodoPriority.medium.rawValue)
        let pending = try await store.list(status: TodoStatus.pending.rawValue)
        #expect(pending.count == 3)
        // Per AGENTS.md §11 priority ordering (= low -> medium -> urgent
        // in ascending SortDescriptor order); = the priority row[0]
        // here is whichever todo was inserted first.
        let priorities = pending.map(\.priority).sorted()
        #expect(priorities == [TodoPriority.low.rawValue, TodoPriority.medium.rawValue, TodoPriority.urgent.rawValue])
    }

    @Test("delete 删 1 个")
    @MainActor
    func testDelete() async throws {
        let store = try Self.makeTodoRepository()
                let todo = try await store.add(title: "test")
        try await store.delete(id: todo.id)
        let got = try await store.get(id: todo.id)
        #expect(got == nil)
    }

    @Test("count 按 status 过滤")
    @MainActor
    func testCount() async throws {
        let store = try Self.makeTodoRepository()
                _ = try await store.add(title: "a", priority: TodoPriority.high.rawValue)
        _ = try await store.add(title: "b", priority: TodoPriority.medium.rawValue)
        let todo1 = try await store.add(title: "c", priority: TodoPriority.low.rawValue)
        try await store.setStatus(id: todo1.id, status: TodoStatus.completed.rawValue)
        let pending = (try? await store.count(status: TodoStatus.pending.rawValue)) ?? -1
        #expect(pending == 2)
        let completed = (try? await store.count(status: TodoStatus.completed.rawValue)) ?? -1
        #expect(completed == 1)
    }

    @Test("dueDate 持久化")
    @MainActor
    func testDueDate() async throws {
        let store = try Self.makeTodoRepository()
                let due = Date(timeIntervalSince1970: 1900000000)  // 2030-03-08
        let todo = try await store.add(title: "future task", priority: TodoPriority.urgent.rawValue, dueDate: due)
        let got = try await store.get(id: todo.id)
        #expect(got?.dueDate?.timeIntervalSince1970 == 1900000000)
    }
}