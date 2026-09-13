//
//  Persistence/Repositories/WSTodoRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
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
        #expect(item.status == .pending)
        #expect(item.priority == .medium)
        let fetched = try repo.get(id: item.id)
        #expect(fetched?.id == item.id)
    }

    @Test("setStatus mutates status")
    @MainActor
    func setStatus() throws {
        let repo = try makeRepository()
        let item = try repo.add(title: "x")
        try repo.setStatus(id: item.id, status: .completed)
        let fetched = try repo.get(id: item.id)
        #expect(fetched?.status == .completed)
    }

    @Test("setStatus throws notFound for missing")
    @MainActor
    func setStatusMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSTodoRepositoryError.notFound.self) {
            try repo.setStatus(id: "nope", status: .completed)
        }
    }

    @Test("list filters by status + sorts by priority")
    @MainActor
    func listFilterAndSort() throws {
        let repo = try makeRepository()
        _ = try repo.add(title: "low task", priority: .low)
        _ = try repo.add(title: "high task", priority: .high)
        _ = try repo.add(title: "urgent task", priority: .urgent)
        _ = try repo.add(title: "completed task")
        let completed = try repo.list(status: .completed)
        #expect(completed.count == 0)  // no items have .completed yet
        let all = try repo.list()
        #expect(all.count == 4)
        // highest priority first
        #expect(all[0].priority == .urgent)
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
        let pending = try repo.count(status: .pending)
        let completed = try repo.count(status: .completed)
        #expect(pending == 2)
        #expect(completed == 0)
    }
}
