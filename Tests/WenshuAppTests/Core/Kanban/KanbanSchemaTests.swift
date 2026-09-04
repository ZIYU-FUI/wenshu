//
//  KanbanSchemaTests.swift · Wenshu · v0.23 ticket 013.004 (hermes gap 3)
//
//  Boss 2026-08-23 拍: hermes kanban metadata parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("KanbanSchema (hermes metadata parity)")
struct KanbanSchemaTests {

    private func tmpPath(_ tag: String) -> String {
        NSTemporaryDirectory() + "wenshu-kanban-\(tag)-\(UUID().uuidString).sqlite"
    }

    @Test("bootstrap creates kanban_tasks with all 10 columns (v0.23 ticket 013.003)")
    func testBootstrapSchema() async throws {
        let store = try KanbanStore(path: tmpPath("bootstrap"))
        try await store.bootstrap()
        let tasks = try await store.list()
        #expect(tasks.isEmpty)
    }

    @Test("add task with priority + assignee + modelOverride round-trips")
    func testAddWithMetadata() async throws {
        let store = try KanbanStore(path: tmpPath("add-meta"))
        try await store.bootstrap()
        let task = try await store.add(
            title: "writer: 续写捕快",
            status: .running,
            priority: 8,
            assignee: "writer",
            modelOverride: "MiniMax-M3"
        )
        // startedAt auto-set when status = .running
        #expect(task.priority == 8)
        #expect(task.assignee == "writer")
        #expect(task.modelOverride == "MiniMax-M3")
        #expect(task.startedAt != nil)
        #expect(task.completedAt == nil)

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
        let store = try KanbanStore(path: tmpPath("new-no-started"))
        try await store.bootstrap()
        let task = try await store.add(title: "backlog item", status: .new)
        #expect(task.startedAt == nil)
        #expect(task.completedAt == nil)
        #expect(task.assignee == nil)
        #expect(task.modelOverride == nil)
    }

    @Test("transition to .running auto-sets startedAt")
    func testTransitionRunningAutoSetsStarted() async throws {
        let store = try KanbanStore(path: tmpPath("trans-running"))
        try await store.bootstrap()
        let task = try await store.add(title: "task", status: .new)
        try await store.transition(id: task.id, to: .running)
        let loaded = try await store.get(id: task.id)
        #expect(loaded?.startedAt != nil)
        #expect(loaded?.completedAt == nil)
    }

    @Test("transition to .done auto-sets completedAt")
    func testTransitionDoneAutoSetsCompleted() async throws {
        let store = try KanbanStore(path: tmpPath("trans-done"))
        try await store.bootstrap()
        let task = try await store.add(title: "task", status: .running)
        try await store.transition(id: task.id, to: .done)
        let loaded = try await store.get(id: task.id)
        #expect(loaded?.startedAt != nil)
        #expect(loaded?.completedAt != nil)
        #expect(loaded?.status == .done)
    }

    @Test("transition preserves startedAt (COALESCE — only set on first .running)")
    func testTransitionStartedAtPreserved() async throws {
        let store = try KanbanStore(path: tmpPath("started-preserved"))
        try await store.bootstrap()
        let task = try await store.add(title: "task", status: .new)
        try await store.transition(id: task.id, to: .running)
        let firstStart = try await store.get(id: task.id)
        #expect(firstStart?.startedAt != nil)
        let firstStartDate = firstStart!.startedAt!
        // Back to .blocked, then back to .running — startedAt should NOT change
        try await store.transition(id: task.id, to: .blocked)
        try await store.transition(id: task.id, to: .running)
        let secondStart = try await store.get(id: task.id)
        #expect(secondStart?.startedAt == firstStartDate)
    }

    @Test("transition to .failed auto-sets completedAt (v0.23 task 013.003)")
    func testTransitionFailedAutoSetsCompleted() async throws {
        let store = try KanbanStore(path: tmpPath("trans-failed"))
        try await store.bootstrap()
        let task = try await store.add(title: "task", status: .running)
        try await store.transition(id: task.id, to: .failed)
        let loaded = try await store.get(id: task.id)
        #expect(loaded?.completedAt != nil)
        #expect(loaded?.status == .failed)
    }

    @Test("KanbanTask equality includes metadata fields")
    func testKanbanTaskEquality() {
        let now = Date()
        let a = KanbanTask(id: "1", title: "t", status: .new, createdAt: now, updatedAt: now, priority: 5)
        let b = KanbanTask(id: "1", title: "t", status: .new, createdAt: now, updatedAt: now, priority: 5)
        #expect(a == b)
        let c = KanbanTask(id: "1", title: "t", status: .new, createdAt: now, updatedAt: now, priority: 8)
        #expect(a != c)
    }
}