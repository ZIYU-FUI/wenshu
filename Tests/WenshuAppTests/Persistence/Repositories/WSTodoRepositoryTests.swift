//
//  Persistence/Repositories/WSTodoRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("WSTodoRepository (= SwiftData @Model TodoStore replacement)")
struct WSTodoRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSTodoRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSTodoRepository(container: container)
    }

    @Test("add + get round-trip")
    @MainActor
    func add() throws {
        let repo = try makeRepository()
        let item = try repo.add(title: "buy milk")
        #expect(item.title == "buy milk")
        #expect(item.status == TodoStatus.pending.rawValue)
        #expect(item.priority == TodoPriority.medium.rawValue)
        let fetched = try repo.get(id: item.id)
        #expect(fetched?.id == item.id)
    }

    @Test("setStatus mutates status")
    @MainActor
    func setStatus() throws {
        let repo = try makeRepository()
        let item = try repo.add(title: "x")
        try repo.setStatus(id: item.id, status: TodoStatus.completed)
        let fetched = try repo.get(id: item.id)
        #expect(fetched?.status == TodoStatus.completed.rawValue)
    }

    @Test("setStatus throws notFound for missing")
    @MainActor
    func setStatusMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSTodoRepositoryError.notFound.self) {
            try repo.setStatus(id: "nope", status: TodoStatus.completed)
        }
    }

    @Test("list filters by status + sorts by priority")
    @MainActor
    func listFilterAndSort() throws {
        let repo = try makeRepository()
        _ = try repo.add(title: "low task", priority: TodoPriority.low)
        _ = try repo.add(title: "high task", priority: TodoPriority.high)
        _ = try repo.add(title: "urgent task", priority: TodoPriority.urgent)
        _ = try repo.add(title: "completed task")
        let completed = try repo.list(status: TodoStatus.completed)
        #expect(completed.count == 0)  // no items have .completed yet
        let all = try repo.list()
        #expect(all.count == 4)
        // highest priority first
        #expect(all[0].priority == TodoPriority.urgent.rawValue)
    }

    @Test("delete removes the row")
    @MainActor
    func delete() throws {
        let repo = try makeRepository()
        let item = try repo.add(title: "x")
        try repo.delete(id: item.id)
        let fetched = try repo.get(id: item.id)
        #expect(fetched == nil)
    }

    @Test("count respects status filter")
    @MainActor
    func count() throws {
        let repo = try makeRepository()
        _ = try repo.add(title: "a")
        _ = try repo.add(title: "b")
        let pending = try repo.count(status: TodoStatus.pending)
        let completed = try repo.count(status: TodoStatus.completed)
        #expect(pending == 2)
        #expect(completed == 0)
    }
}
