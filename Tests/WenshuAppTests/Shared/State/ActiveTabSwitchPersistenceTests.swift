//
//  ActiveTabSwitchPersistenceTests.swift · Wenshu · P2 root fix
//
//  The contract of `ActiveTabPersistence` (= the writer
//  `AppState.activeTabId` hands its value to since 2026-11-21):
//
//  1. The frame that switches tabs does NO storage work at all. Three
//     switches in a row leave the persisted key exactly where it was,
//     and the burst takes ONE hop (= counted with `hopCount`, because
//     the queue flag reads true for a per-switch queue as well).
//  2. A switch is still persisted. The hop writes the NEWEST id, and a
//     launch that reads the record reopens the tab the user left on.
//  3. Closing is a durability point: `closeTab` returns with the id it
//     just rewritten already on disk, because a record naming a
//     document the user closed is a correctness bug, not a stale one.
//  4. The restore semantics did not move: an id that names no open tab
//     still falls back to the first tab (= `restoreOpenTabs`' existing
//     branch), and the read path is still `.activeTabId`.
//  5. The code claim, read off the source: no defaults call survives in
//     the `activeTabId` observer, and the persistence file carries no
//     clock (= the house rule that a timer is the anti-pattern being
//     removed, never the fallback).
//
//  WHY THIS SUITE OWNS ITS OWN DEFAULTS SUITE. Every assertion about
//  "nothing was written" reads a value back, and the process-global
//  `UserDefaults.standard` record is written by every other suite in
//  the binary that opens a tab (= the drift measured 2026-11-19 that
//  made the relaunch case in ActiveBookIdentityTests pass alone and
//  fail combined). `AppState(tabDefaults:)` exists so this contract can
//  be measured without that race (= see the AppState.swift row's prose
//  in docs/agents/nfi.md). Production passes nothing and gets
//  `UserDefaultsStore.shared`, so a real launch is unchanged.
//
//  NO SLEEP, NO WALL CLOCK. The hop is taken by pumping the main
//  actor's queue (`Task.yield`), which is FIFO: a job enqueued by the
//  switch has necessarily run by the time the yielding task resumes.
//  Nothing here waits on time, so nothing here can be flaky on load.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("P2 active-tab persistence — no storage in the switch frame", .serialized)
@MainActor
struct ActiveTabSwitchPersistenceTests {
    /// A defaults suite belonging to this test instance alone.
    private let suiteName: String
    private let store: UserDefaultsStore

    init() {
        suiteName = "wenshu.active-tab-switch.\(UUID().uuidString)"
        store = UserDefaultsStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    /// Put this instance's own defaults suite away. Called at the end of
    /// every case (= a struct cannot declare a deinitializer, and each
    /// case gets a fresh instance with a fresh suite name; same cleanup
    /// idiom as `AgentBehaviorTests`).
    private func dropStore() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Fixtures

    /// A tab the persistence record keeps. `documentPath` is nil so the
    /// restore path never reads a file off disk, and the body is
    /// non-empty so `AppState.tabs(from:)` does not filter it out as the
    /// legacy placeholder tab.
    private func makeTab(_ label: String = UUID().uuidString) -> EditorTab {
        EditorTab(
            id: UUID(),
            documentPath: nil,
            draft: "typed body \(label)",
            originalBody: "typed body \(label)",
            mode: .edit,
            title: label
        )
    }

    /// A session with two open tabs, the first of them active (= the
    /// state a user is in when they click the tab strip).
    private func makeSession() -> (AppState, EditorTab, EditorTab) {
        let state = AppState(tabDefaults: store)
        let first = makeTab("first")
        let second = makeTab("second")
        state.openTabs = [first, second]
        state.activeTabId = first.id
        return (state, first, second)
    }

    /// Take the main actor's next turns (= the hop's turn among them).
    ///
    /// NOT a sleep and NOT a budget: `Task.yield()` re-enqueues THIS
    /// task at the back of the main actor's queue, so every job queued
    /// before it — the one the switch queued — has run when it resumes.
    /// Three turns because the third turn is free; the first one is
    /// what the contract needs.
    private func takeTheHops() async {
        for _ in 0 ..< 3 {
            await Task.yield()
        }
    }

    // MARK: - 1. The switch frame does no storage work

    @Test("a tab switch performs no defaults write inside its own frame")
    func switchFrameWritesNothingSynchronously() async {
        let (state, _, second) = makeSession()
        // `makeSession` switched once (= to the first tab) and has not
        // yielded, so the record is still untouched. That is the claim,
        // not a fixture artifact: the switch, not the list write, owns
        // this key.
        #expect(store.uuid(forKey: .activeTabId) == nil,
                "the pending switch already reached disk (= the write is still inside the interaction frame)")

        state.activeTabId = second.id
        #expect(store.uuid(forKey: .activeTabId) == nil,
                "switching tabs still writes UserDefaults synchronously")

        await takeTheHops()
        #expect(store.uuid(forKey: .activeTabId) == second.id,
                "the hop never wrote the id the user switched to (= a switch is now unpersisted)")
        #expect(state.activeTabPersistence.pendingActiveTabId == nil,
                "the hop left the pending value installed (= the next flush would write a switch that is already persisted)")
        dropStore()
    }

    @Test("a burst of switches coalesces into one hop and one write of the newest id")
    func aBurstOfSwitchesCoalesces() async {
        let (state, first, second) = makeSession()
        #expect(store.uuid(forKey: .activeTabId) == nil)

        // Counted, not flagged. `isFlushHopQueued` reads true after a
        // burst whether the switches coalesced or each queued its own
        // hop (= the flag is raised by the FIRST switch and the guard
        // is what keeps the later ones from queueing), so the only
        // reading that can see coalescing is how many hops ran.
        let hopsBeforeBurst = state.activeTabPersistence.hopCount

        state.activeTabId = second.id
        state.activeTabId = first.id
        state.activeTabId = second.id

        #expect(store.uuid(forKey: .activeTabId) == nil,
                "three switches wrote defaults synchronously")
        #expect(state.activeTabPersistence.pendingActiveTabId == second.id,
                "the pending slot did not hold the newest of three switches (= it is a queue, not a coalescing slot)")
        #expect(state.activeTabPersistence.isFlushHopQueued,
                "no hop was waiting for the burst (= the newest switch would never be written)")

        await takeTheHops()
        // The coalescing claim, measured: the fixture's switch and the
        // three of this burst share ONE hop. Delete the guard in
        // `markSwitched` and each of the four queues its own, so this
        // reads 4 and the case goes red (= the case as first written
        // could not see that mutation, and it is the mutation this
        // case is named for).
        #expect(state.activeTabPersistence.hopCount - hopsBeforeBurst == 1,
                "four switches took \(state.activeTabPersistence.hopCount - hopsBeforeBurst) hops (= the pending slot became a per-switch queue)")
        #expect(store.uuid(forKey: .activeTabId) == second.id,
                "the coalesced hop wrote something other than the newest switch")
        #expect(!state.activeTabPersistence.isFlushHopQueued,
                "the hop left the queue flag raised (= no later switch would ever be persisted)")
        dropStore()
    }

    // MARK: - 2. A switch is still persisted across a launch

    @Test("a relaunch reopens the tab the last switch landed on")
    func aSwitchSurvivesARelaunch() async {
        let first = makeTab("first")
        let second = makeTab("second")
        let before = AppState(tabDefaults: store)
        before.openTabs = [first, second]
        before.activeTabId = first.id
        before.activeTabId = second.id
        await takeTheHops()
        #expect(store.uuid(forKey: .activeTabId) == second.id,
                "nothing reached the record the next launch reads")

        let after = AppState(tabDefaults: store)
        #expect(after.openTabs.map(\.id) == [first.id, second.id],
                "the tab list did not come back through the same record")
        #expect(after.activeTabId == second.id,
                "the launch reopened a different tab than the one the user was left on")
        dropStore()
    }

    // MARK: - 3. Closing is a durability point

    @Test("closeTab returns with the id it rewrote already on disk")
    func closingATabFlushesTheIdItRewrote() {
        let (state, first, second) = makeSession()
        #expect(store.uuid(forKey: .activeTabId) == nil,
                "the switch's write must still be pending when the close begins")

        state.closeTab(id: second.id, bookStore: nil)

        let persisted = store.uuid(forKey: .activeTabId)
        #expect(persisted == first.id,
                "the close did not flush the id it left active (= the record is behind the click)")
        #expect(persisted == state.activeTabId,
                "the record and the live focus disagree right after a close")
        #expect(state.activeTabPersistence.pendingActiveTabId == nil,
                "the close left a switch pending (= the next flush would write an id nobody switched to)")
        dropStore()
    }

    @Test("closing the last tab persists an id that names no open document")
    func closingTheLastTabPersistsTheClearedId() {
        let (state, first, second) = makeSession()
        state.closeTab(id: second.id, bookStore: nil)
        // One tab left (= the first); closing it leaves the editor empty.
        let only = first
        state.closeTab(id: only.id, bookStore: nil)

        let persisted = store.uuid(forKey: .activeTabId)
        #expect(state.openTabs.isEmpty, "the fixture did not close every tab")
        #expect(persisted != nil,
                "the cleared id never reached the record (= the next launch would restore the closed document)")
        #expect(state.openTabs.first(where: { $0.id == persisted }) == nil,
                "the persisted id still names a document the user closed")
        #expect(persisted == state.activeTabId,
                "the persisted active-tab id is not the one the close path wrote")
        dropStore()
    }

    // MARK: - 4. Restore semantics did not move

    @Test("a persisted id that names no open tab still falls back to the first tab")
    func aDanglingPersistedIdStillFallsBack() throws {
        let first = makeTab("first")
        let second = makeTab("second")
        let snapshot = try JSONEncoder().encode(AppState.snapshot(of: [first, second]))
        store.setData(snapshot, forKey: .openTabs)
        store.setUUID(UUID(), forKey: .activeTabId)

        let restored = AppState(tabDefaults: store)
        #expect(restored.activeTabId == first.id,
                "the fallback the restore path already had moved (= a dangling id must still land on the first tab)")
        #expect(restored.openTabs.map(\.id) == [first.id, second.id])
        dropStore()
    }

    // MARK: - 5. The code claim, read off the source

    /// The source with every full-line comment dropped.
    ///
    /// WHY: the claim this case makes is about the CODE, and the code is
    /// allowed to be documented with the name of the call that used to
    /// sit there (= the observer's own comment records what was removed).
    private func codeOnly(_ source: String) -> String {
        source
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("no defaults call survives in the active-tab observer, and the writer carries no clock")
    func theObserverAndTheWriterAreClean() throws {
        let stateGroup = try SourceLocator.readGroup(prefixed: "AppState")
        let persistence = try SourceLocator.readSource(named: "ActiveTabPersistence.swift")

        let observer = try #require(block(after: "var activeTabId: UUID = UUID() {", in: stateGroup))
        let observerCode = codeOnly(observer)
        #expect(!observerCode.contains("UserDefaultsStore"),
                "the activeTabId observer still names UserDefaults at all")
        #expect(!observerCode.contains("setUUID"),
                "the activeTabId observer still writes a defaults value")
        #expect(observerCode.contains("markSwitched"),
                "the activeTabId observer does not hand its value to the writer (= the switch has no persistence path)")

        #expect(!codeOnly(stateGroup).contains("setUUID"),
                "a defaults write for the active-tab id is back somewhere in the AppState group")
        for clock in ["Timer.scheduledTimer", "Timer.publish", "Task.sleep", "while !Task.isCancelled"] {
            #expect(!codeOnly(persistence).contains(clock),
                    "ActiveTabPersistence carries a \(clock) (= a clock is the anti-pattern this ticket removes, not the fallback it keeps)")
        }
        #expect(persistence.contains("markSwitched"),
                "the writer no longer has the switch entry point the observer calls")
    }

    /// The source from `marker` up to the first line that closes a
    /// block at the same indent (= here: the property's own `}`).
    private func block(after marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        let tail = source[start.upperBound...]
        guard let end = tail.range(of: "\n    }\n") else { return nil }
        return String(tail[..<end.upperBound])
    }
}
