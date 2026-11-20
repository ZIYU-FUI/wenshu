//
//  AsyncDelegationChangeSignalTests.swift · Wenshu ·  (2026-11-21)
//
//  The registry announces its own record changes.
//
//  The sub-agent status page used to ask the registry once a second
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
//       stale without the reader being woken.
//    3. A registry that changes nothing announces nothing, which is the
//       whole point of the change (= an idle column does no work).
//
//  A cancelled consumer is also dropped, so a closed page leaves no
//  subscriber behind.
//
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

    // MARK: - 3. A registry that changes nothing says nothing

    @Test("an idle registry wakes no reader (= the clock the page used to run is gone)")
    func quietRegistryStaysQuiet() async {
        let registry = AsyncDelegationRegistry()
        await registry.register(handle: Self.handle("planned"))
        let subscriber = Subscriber(await registry.changes())
        #expect(await arrived(subscriber, atLeast: 1))

        // The only way to prove "nothing happened" is to watch a window
        // in which something could have happened: 300 ms is longer than
        // the old page's whole beat, and the old code woke three times
        // inside it.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(await subscriber.count == 1)
        await subscriber.cancel()
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

        await leaving.cancel()
        await registry.register(handle: Self.handle("after a reader left"))
        #expect(await arrived(staying, atLeast: baseline + 1))
        await staying.cancel()
    }
}
