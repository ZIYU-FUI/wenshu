//
//  KanbanStoreTests.swift · Wenshu · v0.18 ticket 05 (hermes replica)
//
// testlocal Kanban. cwd db, testclean.
//

import Testing
import SwiftData
import Foundation
import WenshuData
@testable import WenshuApp

@Suite("KanbanStore (hermes replica)")
struct KanbanStoreTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSMemoryRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from MemoryStore actor.
    @MainActor
    private static func makeMemoryRepository() throws -> WSMemoryRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSMemoryRepository(container: container)
    }



    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from KanbanStore actor.
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
                let taskId = try await store.add(title: "实现 MemoryStore", status: KanbanStatus.new.rawValue)
        let got = try await store.get(id: taskId)
        #expect(got?.title == "实现 MemoryStore")
        #expect(got?.status == KanbanStatus.new.rawValue)
    }

    @Test("transition 改 status")
    @MainActor
    func testTransition() async throws {
        let store = try Self.makeKanbanRepository()
                let taskId = try await store.add(title: "test", status: KanbanStatus.new.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.running.rawValue)
        let updated = try await store.get(id: taskId)
        #expect(updated?.status == KanbanStatus.running.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.done.rawValue)
        let final = try await store.get(id: taskId)
        #expect(final?.status == KanbanStatus.done.rawValue)
    }

    @Test("list 按 status 过滤")
    @MainActor
    func testListByStatus() async throws {
        let store = try Self.makeKanbanRepository()
                _ = try await store.add(title: "task 1", status: KanbanStatus.new.rawValue)
        _ = try await store.add(title: "task 2", status: KanbanStatus.new.rawValue)
        _ = try await store.add(title: "task 3", status: KanbanStatus.running.rawValue)
        let newTasks = try await store.list(status: KanbanStatus.new.rawValue)
        let runningTasks = try await store.list(status: KanbanStatus.running.rawValue)
        #expect(newTasks.count == 2)
        #expect(runningTasks.count == 1)
    }

    @Test("delete 删 1 个")
    @MainActor
    func testDelete() async throws {
        let store = try Self.makeKanbanRepository()
                let taskId = try await store.add(title: "test")
        try await store.delete(id: taskId)
        let got = try await store.get(id: taskId)
        #expect(got == nil)
    }

    @Test("count 准确")
    @MainActor
    func testCount() async throws {
        let store = try Self.makeKanbanRepository()
                #expect((try? await store.count()) ?? -1 == 0)
        _ = try await store.add(title: "a", status: KanbanStatus.new.rawValue)
        _ = try await store.add(title: "b", status: KanbanStatus.ready.rawValue)
        _ = try await store.add(title: "c", status: KanbanStatus.done.rawValue)
        let total = (try? await store.count()) ?? -1
        #expect(total == 3)
        let done = (try? await store.count(status: KanbanStatus.done.rawValue)) ?? -1
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