//
//  DisplayStateMachineTests.swift · Wenshu · v0.38 Batch 3 sub-step 11
//
//  Tests for DisplayStateMachine + DisplayState transitions + DisplayStateError
//  (= v0.36 ticket 016 sub-step 2).
//
//  Per 老板 cadence 2026-09-03 '继续推进移植' (= 长期 auto-pilot mode
//  per '一直跑移植就行' + '不用问我了') + 'PO 全链路方法论执行,
//  不要跳步骤' + '1 RULE 1 commit'.
//
//  Safe scope (= NOT v0.34 in-flight) = DisplayStateMachine is v0.36
//  ticket 016 (= my work).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("DisplayStateMachine deep (= v0.36 ticket 016)")
struct DisplayStateMachineDeepTests {

    // MARK: - DisplayState extensions (= isInProgress, isTerminal, labels)

    @Test("DisplayState: idle.isInProgress = false, isTerminal = false")
    func displayStateIdleFlags() {
        let s = DisplayState.idle
        #expect(!s.isInProgress)
        #expect(!s.isTerminal)
    }

    @Test("DisplayState: running(0.5).isInProgress = true, isTerminal = false")
    func displayStateRunningFlags() {
        let s = DisplayState.running(progress: 0.5)
        #expect(s.isInProgress)
        #expect(!s.isTerminal)
    }

    @Test("DisplayState: success.isTerminal = true")
    func displayStateSuccessFlags() {
        let s = DisplayState.success(message: nil)
        #expect(s.isTerminal)
        #expect(!s.isInProgress)
    }

    @Test("DisplayState: error.isTerminal = true")
    func displayStateErrorFlags() {
        let s = DisplayState.error(message: "boom")
        #expect(s.isTerminal)
    }

    @Test("DisplayState: cancelled.isTerminal = true")
    func displayStateCancelledFlags() {
        let s = DisplayState.cancelled
        #expect(s.isTerminal)
    }

    @Test("DisplayState: 5 SF Symbol icon names")
    func displayStateIconNames() {
        #expect(DisplayState.idle.systemImageName == "circle")
        #expect(DisplayState.running(progress: 0.5).systemImageName == "arrow.triangle.2.circlepath")
        #expect(DisplayState.success(message: nil).systemImageName == "checkmark.circle.fill")
        #expect(DisplayState.error(message: "x").systemImageName == "exclamationmark.triangle.fill")
        #expect(DisplayState.cancelled.systemImageName == "xmark.circle")
    }

    @Test("DisplayState: 5 display labels")
    func displayStateLabels() {
        #expect(DisplayState.idle.displayLabel == "Ready")
        #expect(DisplayState.running(progress: 0.5).displayLabel.contains("50%"))
        #expect(DisplayState.success(message: nil).displayLabel == "Done")
        #expect(DisplayState.success(message: "42 files").displayLabel == "42 files")
        #expect(DisplayState.error(message: "oops").displayLabel.contains("oops"))
        #expect(DisplayState.cancelled.displayLabel == "Cancelled")
    }

    // MARK: - DisplayState.canTransition (state machine logic)

    @Test("DisplayState: idle -> running = allowed")
    func canTransitionIdleToRunning() {
        #expect(DisplayState.idle.canTransition(to: .running(progress: 0.0)))
    }

    @Test("DisplayState: running -> success = allowed")
    func canTransitionRunningToSuccess() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .success(message: nil)))
    }

    @Test("DisplayState: running -> error = allowed")
    func canTransitionRunningToError() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .error(message: "x")))
    }

    @Test("DisplayState: running -> cancelled = allowed")
    func canTransitionRunningToCancelled() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .cancelled))
    }

    @Test("DisplayState: success -> idle = allowed (reset)")
    func canTransitionSuccessToIdle() {
        #expect(DisplayState.success(message: nil).canTransition(to: .idle))
    }

    @Test("DisplayState: error -> idle = allowed (reset)")
    func canTransitionErrorToIdle() {
        #expect(DisplayState.error(message: "x").canTransition(to: .idle))
    }

    @Test("DisplayState: cancelled -> idle = allowed (reset)")
    func canTransitionCancelledToIdle() {
        #expect(DisplayState.cancelled.canTransition(to: .idle))
    }

    @Test("DisplayState: idle -> success = NOT allowed")
    func cannotTransitionIdleToSuccess() {
        #expect(!DisplayState.idle.canTransition(to: .success(message: nil)))
    }

    @Test("DisplayState: running(0.3) -> running(0.2) = NOT allowed (backward)")
    func cannotTransitionRunningBackwards() {
        #expect(!DisplayState.running(progress: 0.3).canTransition(to: .running(progress: 0.2)))
    }

    @Test("DisplayState: running(0.3) -> running(0.5) = allowed (monotonic)")
    func canTransitionRunningForward() {
        #expect(DisplayState.running(progress: 0.3).canTransition(to: .running(progress: 0.5)))
    }

    @Test("DisplayState: running(0.5) -> running(0.5) = allowed (equal)")
    func canTransitionRunningSame() {
        #expect(DisplayState.running(progress: 0.5).canTransition(to: .running(progress: 0.5)))
    }

    // MARK: - DisplayStateMachine transitions

    @Test("DisplayStateMachine: idle -> running")
    func machineIdleToRunning() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.0))
        #expect(machine.state == .running(progress: 0.0))
    }

    @Test("DisplayStateMachine: updateProgress clamps to 0..1")
    func machineUpdateProgressClamps() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.0))
        try machine.updateProgress(1.5)
        #expect(machine.state == .running(progress: 1.0))
        try machine.updateProgress(-0.5)
        #expect(machine.state == .running(progress: 0.0))
    }

    @Test("DisplayStateMachine: markSuccess")
    func machineMarkSuccess() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.5))
        try machine.markSuccess(message: "all done")
        #expect(machine.state == .success(message: "all done"))
    }

    @Test("DisplayStateMachine: markError")
    func machineMarkError() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.3))
        try machine.markError("connection lost")
        #expect(machine.state == .error(message: "connection lost"))
    }

    @Test("DisplayStateMachine: markCancelled")
    func machineMarkCancelled() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.1))
        try machine.markCancelled()
        #expect(machine.state == .cancelled)
    }

    @Test("DisplayStateMachine: reset to idle")
    func machineReset() throws {
        var machine = DisplayStateMachine(taskName: "test")
        try machine.transition(to: .running(progress: 0.5))
        try machine.markSuccess(message: "done")
        machine.reset()
        #expect(machine.state == .idle)
    }

    @Test("DisplayStateMachine: illegal transition throws")
    func machineIllegalTransition() {
        var machine = DisplayStateMachine(taskName: "test")
        // Cannot transition from idle to success
        do {
            try machine.transition(to: .success(message: nil))
            Issue.record("expected throw")
        } catch {
            // expected
        }
    }

    @Test("DisplayStateMachine: taskName + startedAt preserved")
    func machinePreservesMetadata() throws {
        let machine = DisplayStateMachine(taskName: "index-doc")
        #expect(machine.taskName == "index-doc")
        let now = Date()
        let diff = abs(machine.startedAt.timeIntervalSince(now))
        #expect(diff < 1.0)  // started within last second
    }

    @Test("DisplayStateMachine: Equatable")
    func machineEquatable() {
        let a = DisplayStateMachine(taskName: "test")
        let b = DisplayStateMachine(taskName: "test")
        #expect(a == b)
    }

    // MARK: - DisplayStateError

    @Test("DisplayStateError.illegalTransition: errorDescription contains task name")
    func errorDescription() {
        let error = DisplayStateError.illegalTransition(
            from: .idle,
            to: .success(message: nil),
            taskName: "index"
        )
        let desc = error.errorDescription
        #expect(desc != nil)
        #expect(desc!.contains("index"))
    }
}
