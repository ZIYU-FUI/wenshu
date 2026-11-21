//
//  AsyncDelegationChangeSignalTests.swift · Wenshu ·  (2026-11-21)
//
//  The registry announces its own record changes.
//
//  A page that polls the registry once a second can only ask
//  whether anything had happened, because nothing told it when a record
//  moved. That clock is gone: a reader subscribes to `changes()` and
//  reads again when the registry says a record changed.
//
//  So the page now depends on three promises, and this suite is where
//  they are kept:
//
//    1. A subscriber learns the current state at subscribe time, so it
//       never shows an empty page for a scope that already has records.
//    2. Every record mutation is announced, so a snapshot cannot go
//       stale without the reader being woken. That includes the two
//       paths that take a record AWAY (the LRU eviction and the
//       retention cleanup), = asserted here at `drop`, not only at
//       `store`, because the page's mirror must shrink when the table
//       does.
//    3. A registry that changes nothing announces nothing, which is the
//       whole point of the change (= an idle column does no work).
//
//  A cancelled consumer is also dropped, so a closed page leaves no
//  subscriber behind, and the file's shape is pinned too: the record
//  table is written by two functions and both of them announce (= the
//  structural fact the refusal of a fallback scan rests on).
//

import Foundation
import Testing
@testable import WenshuApp
import WenshuData

@Suite("AsyncDelegation change signal (the registry says when a record moved)")
struct AsyncDelegationChangeSignalTests {
    private static let sessionID = SessionID(rawValue: "book:book-A:default")
    private static let bookA = BookID(rawValue: "book-A")

    private static func scope() -> AgentScope {
        AgentScope(sessionID: sessionID, bookID: bookA)
    }

    private static func handle(_ message: String) -> BackgroundDelegationHandle {
        BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: message,
            scope: scope()
        )
    }

    // MARK: - Test helpers

    /// Counts the signals one subscriber receives (= a stand-in for the
    /// status page: it subscribes, and every signal is one re-read).
    private actor Mailbox {
        private var received = 0

        func receive() {
            received += 1
        }

        var count: Int {
            received
        }
    }

    /// One live subscriber of one registry.
    private struct Subscriber {
        let mailbox: Mailbox
        let task: Task<Void, Never>

        /// Runs the consumer until its stream ends (= the registry
        /// terminates the stream when the task is cancelled).
        init(_ stream: AsyncStream<Void>) {
            let mailbox = Mailbox()
            self.mailbox = mailbox
            task = Task {
                for await _ in stream {
                    await mailbox.receive()
                }
            }
        }

        func cancel() async {
            task.cancel()
            _ = await mailbox.count
        }

        var count: Int {
            get async { await mailbox.count }
        }
    }

    /// Waits until a subscriber has seen `n` signals, up to a deadline,
    /// and says whether it got there (= so a test states the promise it
    /// is checking instead of sleeping for a fixed beat).
    private func arrived(_ subscriber: Subscriber, atLeast n: Int) async -> Bool {
        for _ in 0 ..< 200 {
            if await subscriber.count >= n {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await subscriber.count >= n
    }

    // MARK: - 1. A subscriber learns the state it subscribed to

    @Test("subscribing announces the current state, not only a later change")
    func subscribeAnnouncesCurrentState() async {
        let registry = AsyncDelegationRegistry()
        // A record exists BEFORE anyone subscribes (= a page that opens
        // on a scope with a finished task must read it at once).
        await registry.register(handle: Self.handle("already running"))

        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))
        await subscriber.cancel()
    }

    // MARK: - 2. Every record mutation is announced

    @Test("each record mutation wakes the reader")
    func mutationsAreAnnounced() async {
        let registry = AsyncDelegationRegistry()
        let subscriber = Subscriber(await registry.changes())
        // Only the subscribe signal so far.
        #expect(await arrived(subscriber, atLeast: 1))
        let baseline = await subscriber.count

        await registry.register(handle: Self.handle("planned"))
        let id = (await registry.handles(scope: Self.scope())).first!.id
        await registry.markRunning(id: id)
        await registry.appendOutput(handleID: id, text: "step one")
        await registry.recordCurrentTool(handleID: id, tool: "web_search")
        await registry.markCompleted(id: id, result: "done")

        // One of them has to wake the reader; which one is not fixed,
        // because the stream keeps only the newest signal (a reader that
        // is busy is handed the change it still has to act on, not every
        // intermediate one). So the promise a page can build on is "the
        // last change of a burst is never lost", asserted next.
        #expect(await arrived(subscriber, atLeast: baseline + 1))
        await subscriber.cancel()
    }

    @Test("the last change of a burst is never lost (= newest kept, not dropped)")
    func burstKeepsItsLastChange() async {
        let registry = AsyncDelegationRegistry()
        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))
        let baseline = await subscriber.count

        // A burst of output appends, the shape streaming output makes.
        await registry.register(handle: Self.handle("streaming"))
        let id = (await registry.handles(scope: Self.scope())).first!.id
        for line in 0 ..< 40 {
            await registry.appendOutput(handleID: id, text: "chunk \(line)")
        }
        await registry.markCompleted(id: id, result: "done")

        #expect(await arrived(subscriber, atLeast: baseline + 1))
        // Quiet now means the reader was handed the newest signal: the
        // last write is announced even when the ones before it collapsed.
        try? await Task.sleep(for: .milliseconds(300))
        let settled = await subscriber.count
        await registry.register(handle: Self.handle("one more"))
        #expect(await arrived(subscriber, atLeast: settled + 1))
        await subscriber.cancel()
    }

    @Test("a mutation a reader did not cause still wakes it")
    func anotherActorMutationIsAnnounced() async {
        let registry = AsyncDelegationRegistry()
        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))
        let baseline = await subscriber.count

        await registry.register(handle: Self.handle("written by the agent"))
        #expect(await arrived(subscriber, atLeast: baseline + 1))
        await subscriber.cancel()
    }

    @Test("two readers of one registry are each announced")
    func everySubscriberIsAnnounced() async {
        let registry = AsyncDelegationRegistry()
        let first = Subscriber(await registry.changes())
        let second = Subscriber(await registry.changes())
        #expect(await arrived(first, atLeast: 1))
        #expect(await arrived(second, atLeast: 1))
        let baseline = await first.count

        await registry.register(handle: Self.handle("shared change"))
        #expect(await arrived(first, atLeast: baseline + 1))
        #expect(await arrived(second, atLeast: baseline + 1))
        await first.cancel()
        await second.cancel()
    }

    // MARK: - 2b. A record taken away is announced like one written

    /// One registry, one subscriber: the reader's wake count is only
    /// evidence when nothing else could have woken it, so every test
    /// here drives ONE mutation and waits for ONE wake.
    @Test("a retirement wakes the reader (= the mirror shrinks on its own)")
    func retirementWakesTheReader() async {
        let registry = AsyncDelegationRegistry()
        // One record past the retention window, one inside it: the
        // cleanup's only effect on the table is to take the old one away,
        // so a wake after it can only be the retirement being announced.
        await registry.register(handle: BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "retired",
            startedAt: Date(timeIntervalSince1970: 0),
            scope: Self.scope()
        ))
        await registry.register(handle: Self.handle("kept"))

        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))
        let baseline = await subscriber.count
        let kept = (await registry.handles(scope: Self.scope())).count

        await registry.cleanup()

        #expect(await arrived(subscriber, atLeast: baseline + 1),
                "a record was retired and the reader was never told")
        #expect(await registry.handles(scope: Self.scope()).count == kept - 1,
                "the cleanup did not retire what the test put past its window")
        await subscriber.cancel()
    }

    @Test("a retirement that retires nothing wakes nobody (= no wake with nothing to show)")
    func aQuietRetirementIsSilent() async {
        let registry = AsyncDelegationRegistry()
        await registry.register(handle: Self.handle("still inside the window"))
        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))
        let baseline = await subscriber.count

        await registry.cleanup()

        // Nothing left the table, so no snapshot went stale, so the
        // writer's `guard removed` says nothing (= the same promise the
        // idle registry is tested for, at the removal path).
        try? await Task.sleep(for: .milliseconds(300))
        #expect(await subscriber.count == baseline)
        await subscriber.cancel()
    }

    @Test("the eviction announces its removal, not only the write it rides in")
    func evictionIsAnnouncedAsARemoval() async {
        let registry = AsyncDelegationRegistry()
        // The subscriber is NOT the witness here: the 51st completion
        // writes a record AND evicts one inside one actor step, and the
        // stream keeps only the newest signal, so the reader is woken
        // either way. The writer's own count is the witness, and it says
        // which function spoke (= delete the announce inside `drop` and
        // this goes red; delete the announce anywhere else and the tests
        // above do).
        var evictedID = ""
        for index in 0 ..< 51 {
            let handle = Self.handle("task \(index)")
            if index == 0 {
                evictedID = handle.id
            }
            await registry.register(handle: handle)
            await registry.markCompleted(id: handle.id, result: "done")
        }

        let counts = await registry.announcementCounts
        #expect(counts[.dropped, default: 0] == 1,
                "the 51st completion should have announced exactly one retirement")
        #expect(await registry.get(id: evictedID) == nil,
                "the LRU should have dropped the oldest record")
    }

    @Test("one registry's announcements are not another's")
    func announcementsArePerRegistry() async {
        let loud = AsyncDelegationRegistry()
        let quiet = AsyncDelegationRegistry()

        await loud.register(handle: Self.handle("written somewhere else"))

        #expect(await quiet.announcementCounts.isEmpty,
                "a test seam that leaks across instances cannot witness an instance")
        #expect(await loud.announcementCounts[.stored, default: 0] == 1)
    }

    // MARK: - 3. A registry that changes nothing says nothing

    @Test("an idle registry wakes no reader (= the clock the page used to run is gone)")
    func quietRegistryStaysQuiet() async {
        let registry = AsyncDelegationRegistry()
        await registry.register(handle: Self.handle("planned"))
        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))

        // The only way to prove "nothing happened" is to watch a window
        // in which something could have happened: 300 ms is longer than
        // the page's 250 ms settle window, so a self-driven wake lands
        // inside it.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(await subscriber.count == 1)
        await subscriber.cancel()
    }

    // MARK: - 4. The table cannot be written without being announced

    /// The premise under the whole design: there is no fallback timer
    /// because an unannounced mutation is not expressible. A sentence
    /// like that is only worth what reads it, so this test reads the
    /// source and fails if the file grows a third way to change the
    /// table, or if either writer stops speaking.
    @Test("the record table is written only by functions that announce")
    func recordTableIsWrittenOnlyByAnnouncingWriters() throws {
        let url = SourceLocator.url(
            "Sources/WenshuApp/Features/Agent/Store/AsyncDelegation.swift"
        )
        let source = try String(decoding: Data(contentsOf: url), as: UTF8.self)

        // A line WRITES the table when `records` is followed by `=` on
        // that line (= subscript or whole-table), or by a mutating call.
        // A read (`guard var handle = records[id] else`) has the `=` on
        // the OTHER side, so it does not match, and a comment line is
        // skipped for the same reason it is skipped everywhere.
        var function = ""
        var writers = Set<String>()
        var announcers = Set<String>()
        for raw in source.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") {
                continue
            }
            if let opened = line.range(of: "func ") {
                let rest = line[opened.upperBound...]
                let name = rest.prefix { $0.isLetter || $0 == "_" }
                function = String(name)
                // The declaration line names the function, so it is not
                // evidence about what the function DOES (= its own
                // `signalChanges(` in the text would else read as a call).
                continue
            }
            guard !function.isEmpty else { continue }
            if line.contains("signalChanges(") {
                announcers.insert(function)
            }
            let mutatesRecords = (line.contains("records[") || line.hasPrefix("records "))
                && line.contains("] = ")
            let mutatesByCall = ["records.removeValue", "records.removeAll", "records.updateValue"]
                .contains { line.contains($0) }
            if mutatesRecords || mutatesByCall {
                writers.insert(function)
            }
        }

        // The declaration (`private var records: [...] = [:]`) sits
        // outside any function, so `function` is still empty there.
        #expect(writers == ["store", "drop"],
                "the record table is written outside the announcing writers")
        #expect(announcers == ["store", "drop"],
                "one of the two writers no longer announces its own change")
    }

    // MARK: - Teardown

    @Test("a reader that stops is dropped, and the reader that stays keeps being told")
    func cancelledReaderIsForgotten() async {
        let registry = AsyncDelegationRegistry()
        let leaving = Subscriber(await registry.changes())
        let staying = Subscriber(await registry.changes())
        #expect(await arrived(leaving, atLeast: 1))
        #expect(await arrived(staying, atLeast: 1))
        let baseline = await staying.count

        // BOTH consumers are registered while they are live, so the count
        // is 2 (= one registry, and this test's registry is its own).
        #expect(await registry.debugChangeSubscriberCount == 2)

        await leaving.cancel()

        // The half the first round only inferred: the reader that left is
        // GONE from the registry, not merely quiet. `onTermination` runs
        // on the task that held the subscription, so it lands a moment
        // after the cancel; this waits for the CONDITION (= a count that
        // settles is a deregistration, and a test that slept for a fixed
        // time would be measuring the machine).
        var remaining = await registry.debugChangeSubscriberCount
        for _ in 0 ..< 100 where remaining > 1 {
            try? await Task.sleep(for: .milliseconds(5))
            remaining = await registry.debugChangeSubscriberCount
        }
        #expect(
            remaining == 1,
            "the reader that left is still a consumer of the stream (= `onTermination` did not deregister it)"
        )

        // And the reader that stayed is still told, on the registry that
        // now holds only it.
        await registry.register(handle: Self.handle("after a reader left"))
        #expect(await arrived(staying, atLeast: baseline + 1))
        await staying.cancel()
    }
}
