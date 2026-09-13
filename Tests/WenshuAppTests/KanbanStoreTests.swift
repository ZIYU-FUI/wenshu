//
//  KanbanStoreTests.swift · Wenshu · v0.18 ticket 05 (hermes replica)
//
// testlocal Kanban. cwd db, testclean.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("KanbanStore (hermes replica)")
struct KanbanStoreTests {

    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    /// Phase 5 ticket 6 migration from KanbanStore actor.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    private static func tempDBPath() -> String {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-kanban-\(UUID().uuidString.prefix(8)).db")
            .path
    }

    @Test("add + get round-trip")
    @MainActor
    func testAddGet() async throws {
        let store = try Self.makeKanbanRepository()
                let task = try await store.add(title: "实现 MemoryStore", status: .new)
        let got = try await store.get(id: task.id)
        #expect(got?.title == "实现 MemoryStore")
        #expect(got?.status == .new)
    }

    @Test("transition 改 status")
    @MainActor
    func testTransition() async throws {
        let store = try Self.makeKanbanRepository()
                let task = try await store.add(title: "test", status: .new)
        try await store.transition(id: task.id, to: .running)
        let updated = try await store.get(id: task.id)
        #expect(updated?.status == .running)
        try await store.transition(id: task.id, to: .done)
        let final = try await store.get(id: task.id)
        #expect(final?.status == .done)
    }

    @Test("list 按 status 过滤")
    @MainActor
    func testListByStatus() async throws {
        let store = try Self.makeKanbanRepository()
                _ = try await store.add(title: "task 1", status: .new)
        _ = try await store.add(title: "task 2", status: .new)
        _ = try await store.add(title: "task 3", status: .running)
        let newTasks = try await store.list(status: .new)
        let runningTasks = try await store.list(status: .running)
        #expect(newTasks.count == 2)
        #expect(runningTasks.count == 1)
    }

    @Test("delete 删 1 个")
    @MainActor
    func testDelete() async throws {
        let store = try Self.makeKanbanRepository()
                let task = try await store.add(title: "test")
        try await store.delete(id: task.id)
        let got = try await store.get(id: task.id)
        #expect(got == nil)
    }

    @Test("count 准确")
    @MainActor
    func testCount() async throws {
        let store = try Self.makeKanbanRepository()
                #expect((try? await store.count()) ?? -1 == 0)
        _ = try await store.add(title: "a", status: .new)
        _ = try await store.add(title: "b", status: .ready)
        _ = try await store.add(title: "c", status: .done)
        let total = (try? await store.count()) ?? -1
        #expect(total == 3)
        let done = (try? await store.count(status: .done)) ?? -1
        #expect(done == 1)
    }

    @Test("KanbanStatus rawValue round-trip")
    @MainActor
    func testStatusRawValue() {
        for s in KanbanStatus.allCases {
            #expect(KanbanStatus(rawValue: s.rawValue) == s)
        }
    }
}