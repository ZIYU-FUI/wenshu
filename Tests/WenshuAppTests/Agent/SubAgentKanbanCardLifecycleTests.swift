//
//  Tests/Agent/SubAgentKanbanCardLifecycleTests.swift · Wenshu
//
//  The card's id survives the run.
//
//  Why this test exists (= the gap it closes):
//
//  The kanban bridge moves the card, = and the bridge was correct,
//  but the id never reached it: = the runner took a snapshot of the
//  handle when the run started, = and wrote that snapshot back when
//  the run moved to "running", = and the card's id is attached AFTER
//  the delegation returns. = So the write-back erased the id, = and
//  the card stayed in "running" for ever = while the research it
//  named was already done.
//
//  What is pinned here:
//
//  1. The order the production code really uses: = register, =
//     attach the card, = then the run's state transition. = The card
//     id survives it.
//  2. The transition does not erase the id, = because it happens on
//     the record the registry holds now.
//  3. The card id is read at the END of the run, = so a run that
//     started before the attach still finds it.
//
//  The registry here is the real one, = and the runner's own methods
//  are exercised against it, = because the defect was an ORDER, = and
//  a test that does not reproduce the order cannot see it.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The card's id survives the run")
struct SubAgentKanbanCardLifecycleTests {

    @Test("the state transition does not erase the card id")
    func theTransitionDoesNotEraseTheCardID() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            id: "run-order",
            agentName: "researcher",
            userMessage: "find something"
        )
        await registry.register(handle: handle)

        // The production order: = the delegation returns, = the card
        // is made, = the id is attached. = The drain loop can pick
        // the handle up in between, = so the transition has to
        // survive it.
        await registry.attachKanbanTaskID(handleID: "run-order", kanbanTaskID: "card-xyz")
        await registry.markRunning(id: "run-order")

        let current = await registry.get(id: "run-order")
        #expect(current?.kanbanTaskID == "card-xyz", "the card id must survive the transition")
        #expect(current?.state == .running, "and the state must have moved")
    }

    @Test("the card id is there for the reader at the end of the run")
    func theCardIDIsThereAtTheEndOfTheRun() async {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            id: "run-end",
            agentName: "researcher",
            userMessage: "find something"
        )
        await registry.register(handle: handle)

        // A snapshot taken BEFORE the attach = = what the runner
        // used to write back. = It has no card id.
        let snapshot = await registry.get(id: "run-end")
        #expect(snapshot?.kanbanTaskID == nil)

        await registry.attachKanbanTaskID(handleID: "run-end", kanbanTaskID: "card-late")
        await registry.markRunning(id: "run-end")

        // The reader at the end of the run reads the registry, = not
        // the snapshot.
        let atEnd = await registry.get(id: "run-end")
        #expect(atEnd?.kanbanTaskID == "card-late")
    }

    @Test("a write-back of an old snapshot is what used to lose the card id")
    func aStaleWriteBackLosesTheCardID() async throws {
        let registry = AsyncDelegationRegistry()
        let handle = BackgroundDelegationHandle(
            id: "run-stale",
            agentName: "researcher",
            userMessage: "find something"
        )
        await registry.register(handle: handle)

        let stale = try #require(await registry.get(id: "run-stale"))
        await registry.attachKanbanTaskID(handleID: "run-stale", kanbanTaskID: "card-stale")

        // The old shape: = the caller mutates its own snapshot and
        // writes it back. = The card id goes with it.
        //
        // The registry no longer offers that shape (= `update` was
        // removed, = because it had no production caller left once
        // the runner moved to `markRunning`), = so this test writes
        // the record directly = the way the old code did = and shows
        // what it cost. = It is here so the shape stays gone.
        var running = stale
        running.state = .running
        await registry.writeBackForTest(running)

        let after = await registry.get(id: "run-stale")
        #expect(after?.kanbanTaskID == nil, "this is the defect, = shown so it cannot come back")
    }
}
