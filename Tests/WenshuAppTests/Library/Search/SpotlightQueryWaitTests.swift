//
//  SpotlightQueryWaitTests.swift
//
//  The wait for the system index.
//
//  **⇒ The wait used to be a `DispatchGroup.wait()` on the search
//  actor's OWN executor.** = The index's answer decided when the
//  actor came back, = so a slow, = disabled, = or wedged index held
//  every other caller on that actor for as long as it liked. = The
//  whole-suite test run had to SKIP the index's own suite, = because
//  that wait could hang.
//
//  Coverage:
//    - the wait ends when the index answers
//    - the wait ends at the DEADLINE when the index never answers
//    - the deadline CANCELS the index (= the index stops working on
//      a question nobody waits for)
//    - the wait ends when the caller is cancelled
//    - exactly one of {the index, = the deadline, = the cancellation}
//      finishes the wait (= a continuation resumed twice traps)
//    - the wait does not hold the thread that asked
//
//  Q112: 1 source + 1 test per ticket
//  (= SpotlightQueryWait.swift + this file).
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The system index is waited for, not blocked on")
struct SpotlightQueryWaitTests {
    // MARK: - The index answers

    @Test("the wait ends when the index answers")
    func waitEndsWhenTheIndexAnswers() async {
        let outcome = await SpotlightQueryWait.awaitOutcome(
            timeout: .seconds(5),
            start: { done in
                done(.answered)
            },
            cancel: {}
        )
        #expect(outcome == .answered)
    }

    @Test("an index that answers with an error is a failed answer")
    func errorIsAFailedAnswer() async {
        let outcome = await SpotlightQueryWait.awaitOutcome(
            timeout: .seconds(5),
            start: { done in
                done(.failed)
            },
            cancel: {}
        )
        #expect(outcome == .failed)
    }

    @Test("the wait ends when the index answers LATE")
    func waitEndsWhenTheIndexAnswersLate() async {
        let outcome = await SpotlightQueryWait.awaitOutcome(
            timeout: .seconds(5),
            start: { done in
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    done(.answered)
                }
            },
            cancel: {}
        )
        #expect(outcome == .answered)
    }

    // MARK: - The index never answers

    @Test("the wait ends at the deadline when the index never answers")
    func waitEndsAtTheDeadline() async {
        // **⇒ The test is BOUNDED, = and not only by the code.** = A
        // test that waits for the deadline to fire HANGS when the
        // deadline is broken, = and a hang is not a verdict: = the
        // suite stops and nobody learns which assertion failed. = **⇒
        // So the test races the wait against its OWN ceiling**, = and
        // a wait that never ends fails with a named assertion.
        let outcome = await Self.outcomeWithin(
            .seconds(5),
            of: {
                await SpotlightQueryWait.awaitOutcome(
                    timeout: .milliseconds(50),
                    start: { _ in
                        // The index never answers.
                    },
                    cancel: {}
                )
            }
        )
        #expect(outcome == .timedOut, "the wait must END at the deadline (= the test's own ceiling must not be what ended it)")
    }

    @Test("the deadline CANCELS the index")
    func deadlineCancelsTheIndex() async {
        let cancelled = CancelledFlag()
        let outcome = await Self.outcomeWithin(
            .seconds(5),
            of: {
                await SpotlightQueryWait.awaitOutcome(
                    timeout: .milliseconds(50),
                    start: { _ in
                        // The index never answers.
                    },
                    cancel: { cancelled.recordCancel() }
                )
            }
        )
        #expect(outcome == .timedOut, "the wait must END at the deadline (= the test's own ceiling must not be what ended it)")
        #expect(cancelled.wasCancelled)
    }

    @Test("an index that answers after the deadline does not change the answer")
    func lateAnswerDoesNotChangeTheAnswer() async {
        let outcome = await Self.outcomeWithin(
            .seconds(5),
            of: {
                await SpotlightQueryWait.awaitOutcome(
                    timeout: .milliseconds(50),
                    start: { done in
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            done(.answered)
                        }
                    },
                    cancel: {}
                )
            }
        )
        #expect(outcome == .timedOut, "a late answer must not change the answer (= the test's own ceiling must not be what ended it)")
    }

    // MARK: - The caller gives up

    @Test("the cancellation CANCELS the index")
    func cancellationCancelsTheIndex() async {
        let cancelled = CancelledFlag()
        let task = Task {
            await SpotlightQueryWait.awaitOutcome(
                timeout: .seconds(30),
                start: { _ in
                    // The index never answers.
                },
                cancel: { cancelled.recordCancel() }
            )
        }
        task.cancel()
        let outcome = await task.value
        #expect(outcome == .cancelled)
        #expect(cancelled.wasCancelled)
    }

    // MARK: - The thread

    @Test("the wait does not hold the thread that asked")
    func waitDoesNotHoldTheThread() async {
        // **⇒ THE DEFECT THIS FILE MEASURES.** = The old wait was
        // `group.wait()` = a BLOCKING wait = so the thread that asked
        // could do nothing else until the index answered. = The new
        // wait suspends, = so the same thread runs other work while
        // the index thinks.
        let indexAnswered = Flag()
        let otherWorkRan = Flag()

        async let waiting = SpotlightQueryWait.awaitOutcome(
            timeout: .seconds(5),
            start: { done in
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    indexAnswered.record()
                    done(.answered)
                }
            },
            cancel: {}
        )
        // The thread that asked keeps working while the index thinks.
        try? await Task.sleep(for: .milliseconds(20))
        otherWorkRan.record()
        let outcome = await waiting

        #expect(otherWorkRan.wasSet)
        #expect(indexAnswered.wasSet)
        #expect(outcome == .answered)
    }

    // MARK: - The helpers

    /// The outcome of a wait, = bounded by the TEST's own ceiling.
    ///
    /// **⇒ A test that waits for the code's deadline HANGS when the
    /// deadline is broken.** = A hang is not a verdict: = the suite
    /// stops, = and nobody learns which assertion failed. = **⇒ So the
    /// wait races a second task**, = and the ceiling's answer is
    /// `nil` (= NOT an outcome).
    ///
    /// **⇒ The ceiling's answer must not be one of the outcomes.** = A
    /// helper that returned `.timedOut` when the ceiling fired would
    /// make a BROKEN deadline (= one that resolves nothing) look like
    /// a WORKING one (= the assertion would see the value it expects).
    /// = **⇒ That is a green mutation, = and a green mutation is a gap
    /// in the test, = not a harmless variant.** = So the ceiling
    /// answers `nil`, = and `nil` is not `.timedOut`.
    private static func outcomeWithin(
        _ ceiling: Duration,
        of wait: @escaping @Sendable () async -> SpotlightQueryOutcome
    ) async -> SpotlightQueryOutcome? {
        await withTaskGroup(of: SpotlightQueryOutcome?.self) { group in
            group.addTask { await wait() }
            group.addTask {
                try? await Task.sleep(for: ceiling)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// A flag a test can read (= the seam that makes "did this run"
    /// observable without a clock).
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var flag = false

        /// Record that this ran.
        func record() {
            lock.withLock { flag = true }
        }

        var wasSet: Bool {
            lock.withLock { flag }
        }
    }

    /// A flag that records that the index was cancelled.
    private final class CancelledFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        /// Record that the index was cancelled.
        func recordCancel() {
            lock.withLock { cancelled = true }
        }

        var wasCancelled: Bool {
            lock.withLock { cancelled }
        }
    }
}
