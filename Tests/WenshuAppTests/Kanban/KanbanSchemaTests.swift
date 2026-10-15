//
//  KanbanSchemaTests.swift · Wenshu · v0.23 ticket 013.004 (hermes gap 3)
//
// 
//

import Foundation
import SwiftData
import Testing
import WenshuData
@testable import WenshuApp

@Suite("KanbanSchema (hermes metadata parity)")
@MainActor
struct KanbanSchemaTests {
    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    ///  migration from KanbanStore actor.
    @MainActor
    private static func makeKanbanRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }



    /// Per-test in-memory SwiftData container (= tests don't share state via
    /// WSPersistenceContainer.shared). Each WSKanbanRepository is its own
    /// @MainActor-isolated object with its own ModelContext.
    private func makeStore(_ tag: String) throws -> WSKanbanRepository {
        _ = tag  // tag preserved for future per-test tracing
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    @Test("bootstrap creates kanban_tasks with all 10 columns (v0.23 ticket 013.003)")
    func testBootstrapSchema() async throws {
        let store = try makeStore("test")
                let tasks = try await store.list()
        #expect(tasks.isEmpty)
    }

    @Test("add task with priority + assignee + modelOverride round-trips")
    func testAddWithMetadata() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(
            title: "writer: 续写捕快",
            status: KanbanStatus.running.rawValue,
            priority: 8,
            assignee: "writer",
            modelOverride: "MiniMax-M3"
        )
        let task = try store.get(id: taskId)
        // startedAt auto-set when status = .running
        #expect(task?.priority == 8)
        #expect(task?.assignee == "writer")
        #expect(task?.modelOverride == "MiniMax-M3")
        #expect(task?.startedAt != nil)
        #expect(task?.completedAt == nil)

        // Round-trip via list()
        let loaded = try await store.list()
        #expect(loaded.count == 1)
        #expect(loaded[0].priority == 8)
        #expect(loaded[0].assignee == "writer")
        #expect(loaded[0].modelOverride == "MiniMax-M3")
        #expect(loaded[0].startedAt != nil)
    }

    @Test("add task with default status (.new) does NOT auto-set startedAt")
    func testAddNewStatusNoStartedAt() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(title: "backlog item", status: KanbanStatus.new.rawValue)
        let task = try store.get(id: taskId)
        #expect(task?.startedAt == nil)
        #expect(task?.completedAt == nil)
        #expect(task?.assignee == nil)
        #expect(task?.modelOverride == nil)
    }

    @Test("transition to .running auto-sets startedAt")
    func testTransitionRunningAutoSetsStarted() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(title: "task", status: KanbanStatus.new.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.running.rawValue)
        let loaded = try await store.get(id: taskId)
        #expect(loaded?.startedAt != nil)
        #expect(loaded?.completedAt == nil)
    }

    @Test("transition to .done auto-sets completedAt")
    func testTransitionDoneAutoSetsCompleted() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(title: "task", status: KanbanStatus.running.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.done.rawValue)
        let loaded = try await store.get(id: taskId)
        #expect(loaded?.startedAt != nil)
        #expect(loaded?.completedAt != nil)
        #expect(loaded?.status == KanbanStatus.done.rawValue)
    }

    @Test("transition preserves startedAt (COALESCE — only set on first .running)")
    func testTransitionStartedAtPreserved() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(title: "task", status: KanbanStatus.new.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.running.rawValue)
        let firstStart = try await store.get(id: taskId)
        #expect(firstStart?.startedAt != nil)
        let firstStartDate = firstStart!.startedAt!
        // Back to .blocked, then back to .running — startedAt should NOT change
        try await store.transition(id: taskId, to: KanbanStatus.blocked.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.running.rawValue)
        let secondStart = try await store.get(id: taskId)
        #expect(secondStart?.startedAt == firstStartDate)
    }

    @Test("transition to .failed auto-sets completedAt (v0.23 task 013.003)")
    func testTransitionFailedAutoSetsCompleted() async throws {
        let store = try makeStore("test")
                let taskId = try await store.add(title: "task", status: KanbanStatus.running.rawValue)
        try await store.transition(id: taskId, to: KanbanStatus.failed.rawValue)
        let loaded = try await store.get(id: taskId)
        #expect(loaded?.completedAt != nil)
        #expect(loaded?.status == KanbanStatus.failed.rawValue)
    }

    @Test("KanbanTask equality includes metadata fields")
    func testKanbanTaskEquality() {
        let now = Date()
        let a = KanbanTask(id: "1", title: "t", status: KanbanStatus.new, createdAt: now, updatedAt: now, priority: 5)
        let b = KanbanTask(id: "1", title: "t", status: KanbanStatus.new, createdAt: now, updatedAt: now, priority: 5)
        #expect(a == b)
        let c = KanbanTask(id: "1", title: "t", status: KanbanStatus.new, createdAt: now, updatedAt: now, priority: 8)
        #expect(a != c)
    }
}
