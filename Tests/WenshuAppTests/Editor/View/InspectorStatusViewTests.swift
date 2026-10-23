//
//  InspectorStatusViewTests.swift · Wenshu
//
//  The status page's own logic: the elapsed-time format, the card's
//  elapsed label, and the output a card can open.
//
//  The page is a View, so per the wenshu test convention its logic
//  is exercised through the value types behind it
//  (= InspectorStatusElapsed + InspectorStatusTask), not through
//  ViewInspector.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("Inspector status page")
struct InspectorStatusViewTests {

    private static let start = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Elapsed time

    @Test("the elapsed time reads as M:SS over a minute")
    func elapsedReadsAsMinutesAndSeconds() {
        // 135 minutes and 54 seconds.
        let now = Self.start.addingTimeInterval(135 * 60 + 54)
        #expect(InspectorStatusElapsed.text(since: Self.start, now: now) == "135:54")
    }

    @Test("the elapsed time reads as Ns under a minute")
    func elapsedReadsAsSecondsUnderAMinute() {
        let now = Self.start.addingTimeInterval(42)
        #expect(InspectorStatusElapsed.text(since: Self.start, now: now) == "42s")
    }

    // MARK: - Card

    @Test("a running card shows the elapsed time")
    func runningCardShowsTheElapsedTime() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running,
            startedAt: Self.start
        )
        let task = InspectorStatusTask(handle: handle)
        let now = Self.start.addingTimeInterval(90)

        let elapsed = task.elapsedText(at: now)
        #expect(elapsed == "1:30", "a running task shows the time since it started")
    }

    @Test("a pending card shows no elapsed time")
    func pendingCardShowsNoElapsedTime() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .pending,
            startedAt: Self.start
        )
        let task = InspectorStatusTask(handle: handle)
        let now = Self.start.addingTimeInterval(90)

        #expect(task.elapsedText(at: now) == nil,
                "a task that has not started has no elapsed time to show")
    }

    // MARK: - Output

    @Test("a task with no output has no output area")
    func taskWithNoOutputHasNoOutputArea() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running,
            startedAt: Self.start,
            outputTail: ""
        )
        let task = InspectorStatusTask(handle: handle)

        #expect(task.output == nil, "a task that produced nothing has no output")
        #expect(!task.canOpen, "a task with no output cannot be opened")
    }

    @Test("a running task shows the text it streamed so far")
    func runningTaskShowsItsStreamedText() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .running,
            startedAt: Self.start,
            outputTail: "The letter arrives in chapter three."
        )
        let task = InspectorStatusTask(handle: handle)

        #expect(task.output == "The letter arrives in chapter three.")
        #expect(task.canOpen)
    }

    @Test("a finished task shows its answer")
    func finishedTaskShowsItsAnswer() {
        let handle = BackgroundDelegationHandle(
            agentName: "researcher",
            userMessage: "Find the scene where the letter arrives.",
            state: .completed,
            startedAt: Self.start,
            completedAt: Self.start.addingTimeInterval(30),
            result: "Chapter three."
        )
        let task = InspectorStatusTask(handle: handle)

        #expect(task.output == "Chapter three.")
        #expect(task.canOpen)
    }
}
