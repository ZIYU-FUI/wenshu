//
//  Persistence/Repositories/WSKanbanRepositoryTests.swift · Wenshu · v0.72 SwiftData migration Phase 2

import Foundation
import SwiftData
import Testing
@testable import WenshuApp

@Suite("WSKanbanRepository (= SwiftData @Model KanbanStore replacement)")
struct WSKanbanRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    @Test("add + get round-trip")
    @MainActor
    func add() throws {
        let repo = try makeRepository()
        let task = try repo.add(title: "Write chapter 1")
        #expect(task.title == "Write chapter 1")
        #expect(task.status == .new)
        #expect(task.priority == 5)
        let fetched = try repo.get(id: task.id)
        #expect(fetched?.title == "Write chapter 1")
    }

    @Test("transition mutates status + sets lifecycle timestamps")
    @MainActor
    func transition() throws {
        let repo = try makeRepository()
        let task = try repo.add(title: "x")
        try repo.transition(id: task.id, to: .running)
        let after = try repo.get(id: task.id)
        #expect(after?.status == .running)
        #expect(after?.startedAt != nil)
        try repo.transition(id: task.id, to: .done)
        let final = try repo.get(id: task.id)
        #expect(final?.status == .done)
        #expect(final?.completedAt != nil)
    }

    @Test("transition throws notFound for missing")
    @MainActor
    func transitionMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSKanbanRepositoryError.notFound.self) {
            try repo.transition(id: "nope", to: .done)
        }
    }

    @Test("list filters by status")
    @MainActor
    func listFilter() throws {
        let repo = try makeRepository()
        let a = try repo.add(title: "a")
        let b = try repo.add(title: "b")
        try repo.transition(id: a.id, to: .running)
        let running = try repo.list(status: .running)
        let new = try repo.list(status: .new)
        #expect(running.count == 1)
        #expect(new.count == 1)
    }

    @Test("delete removes the row")
    @MainActor
    func delete() throws {
        let repo = try makeRepository()
        let t = try repo.add(title: "x")
        try repo.delete(id: t.id)
        let fetched = try repo.get(id: t.id)
        #expect(fetched == nil)
    }

    @Test("count respects status filter")
    @MainActor
    func count() throws {
        let repo = try makeRepository()
        _ = try repo.add(title: "a")
        _ = try repo.add(title: "b")
        _ = try repo.add(title: "c")
        #expect(try repo.count() == 3)
        #expect(try repo.count(status: .new) == 3)
        #expect(try repo.count(status: .done) == 0)
    }
}
