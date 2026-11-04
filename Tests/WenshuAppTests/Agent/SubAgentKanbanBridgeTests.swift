//
//  Tests/Agent/SubAgentKanbanBridgeTests.swift · Wenshu
//
//  Verifies that a delegation's kanban card follows the run.
//
//  Why this test exists (= the gap it closes):
//
//  A research noun became a card in "new". = The delegation ran, =
//  and the card stayed in "new" whether the research had produced an
//  answer or failed outright. = The board was a list of intentions,
//  not a list of what happened. = The user could not tell a finished
//  research from a queued one.
//
//  What is pinned here:
//
//  1. A finished run puts the card in "done". = A failed run puts it
//     in "failed". = The card's state is the run's state.
//  2. A card that was created while the work was in flight says
//     "running", = not "new". = "new" claimed the work had not begun,
//     = which was false the moment the card existed.
//  3. A delegation with no card is not an error. = Most delegations
//     make no card, = so "there is nothing to move" is the normal
//     case.
//  4. A card that cannot be moved does not throw. = The run's own
//     outcome is in the ledger, = and a board that cannot be written
//     to must not turn that into a failed run.
//
//  The repository is backed by an in-memory SwiftData container, = so
//  the card's real lifecycle (= including its timestamps) is
//  exercised.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("A delegation's kanban card follows the run")
struct SubAgentKanbanBridgeTests {

    @MainActor
    private static func makeRepository() throws -> WSKanbanRepository {
        let container = try WSPersistenceContainer.makeInMemoryContainer()
        return WSKanbanRepository(container: container)
    }

    @MainActor
    @Test("a finished run puts the card in done")
    func finishedRunMovesTheCardToDone() throws {
        let repository = try Self.makeRepository()
        let bridge = SubAgentKanbanBridge(repository: repository)

        let cardID = try repository.add(title: "research: 赤壁之战", status: "running")
        let moved = bridge.move(cardID: cardID, to: .done)

        #expect(moved)
        #expect(try repository.get(id: cardID)?.status == "done")
    }

    @MainActor
    @Test("a failed run puts the card in failed")
    func failedRunMovesTheCardToFailed() throws {
        let repository = try Self.makeRepository()
        let bridge = SubAgentKanbanBridge(repository: repository)

        let cardID = try repository.add(title: "research: 曹操", status: "running")
        let moved = bridge.move(cardID: cardID, to: .failed)

        #expect(moved)
        #expect(try repository.get(id: cardID)?.status == "failed")
    }

    @MainActor
    @Test("a card made for work already in flight says running, not new")
    func inFlightCardSaysRunning() throws {
        let repository = try Self.makeRepository()

        let cardID = try repository.add(title: "research: 赤壁之战", status: "running")
        let card = try #require(try repository.get(id: cardID))

        #expect(card.status == "running")
        // The repository stamps the start time when the card says
        // running, = which is what makes the board's timeline true.
        #expect(card.startedAt != nil)
    }

    @MainActor
    @Test("a delegation with no card has nothing to move, and that is not an error")
    func noCardIsNotAnError() throws {
        let repository = try Self.makeRepository()
        let bridge = SubAgentKanbanBridge(repository: repository)

        #expect(bridge.move(cardID: nil, to: .done) == false)
        #expect(bridge.move(cardID: "", to: .done) == false)
    }

    @MainActor
    @Test("a card that cannot be moved does not throw")
    func unmovableCardDoesNotThrow() throws {
        let repository = try Self.makeRepository()
        let bridge = SubAgentKanbanBridge(repository: repository)

        // An id that names no card. = The move fails inside the
        // repository, = and the bridge swallows it, = because the run
        // itself is not the card's problem.
        let moved = bridge.move(cardID: "no-such-card", to: .done)

        #expect(moved == false)
    }

    @MainActor
    @Test("the card records when the work finished")
    func cardRecordsTheFinish() throws {
        let repository = try Self.makeRepository()
        let bridge = SubAgentKanbanBridge(repository: repository)

        let cardID = try repository.add(title: "research: 赤壁之战", status: "running")
        #expect(try repository.get(id: cardID)?.completedAt == nil)

        bridge.move(cardID: cardID, to: .done)

        let card = try #require(try repository.get(id: cardID))
        #expect(card.completedAt != nil)
    }
}
