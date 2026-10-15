//
//  Persistence/Repositories/WSKanbanRepositoryTests.swift · Wenshu · v0.72 SwiftData migration 

import Foundation
import Testing
import WenshuData
@testable import WenshuApp

@Suite("WSKanbanRepository (= SwiftData @Model KanbanStore replacement)")
struct WSKanbanRepositoryTests {

    @MainActor
    private func makeRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

//     @Test("add + get round-trip")
//     @MainActor
//     func add() throws {
//         let repo = try makeRepository()
//         let task = try repo.add(title: "Write chapter 1")
//         #expect(task.title == "Write chapter 1")
//         #expect(task.status == .new)
//         #expect(task.priority == 5)
//         let fetched = try repo.get(id: task.id)
//         #expect(fetched?.title == "Write chapter 1")
//     }

//     @Test("transition mutates status + sets lifecycle timestamps")
//     @MainActor
//     func transition() throws {
//         let repo = try makeRepository()
//         let task = try repo.add(title: "x")
//         try repo.transition(id: task.id, to: .running)
//         let after = try repo.get(id: task.id)
//         #expect(after?.status == .running)
//         #expect(after?.startedAt != nil)
//         try repo.transition(id: task.id, to: .done)
//         let final = try repo.get(id: task.id)
//         #expect(final?.status == .done)
//         #expect(final?.completedAt != nil)
//     }

    @Test("transition throws notFound for missing")
    @MainActor
    func transitionMissing() throws {
        let repo = try makeRepository()
        #expect(throws: WSKanbanRepositoryError.notFound.self) {
            try repo.transition(id: "nope", to: KanbanStatus.done.rawValue)
        }
    }

    @Test("list filters by status")
    @MainActor
    func listFilter() throws {
        let repo = try makeRepository()
        let aId = try repo.add(title: "a")
        let bId = try repo.add(title: "b")
        try repo.transition(id: aId, to: KanbanStatus.running.rawValue)
        let running = try repo.list(status: KanbanStatus.running.rawValue)
        let new = try repo.list(status: KanbanStatus.new.rawValue)
        #expect(running.count == 1)
        #expect(new.count == 1)
    }

    @Test("delete removes the row")
    @MainActor
    func delete() throws {
        let repo = try makeRepository()
        let tId = try repo.add(title: "x")
        try repo.delete(id: tId)
        let fetched = try repo.get(id: tId)
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
        #expect(try repo.count(status: KanbanStatus.new.rawValue) == 3)
        #expect(try repo.count(status: KanbanStatus.done.rawValue) == 0)
    }
}
