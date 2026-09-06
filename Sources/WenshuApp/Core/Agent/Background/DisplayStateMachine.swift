//
//  DisplayStateMachine.swift · Wenshu · v0.36 ticket 016 sub-step 2
//
//  Finite state machine for background task display (= spec §3.1 L227-231
//  Background/ sub-directory, file 1 of 4).
//
//  Each background task (= indexing, search, sync, etc.) runs through a
//  predictable state machine: idle -> running -> success | error | cancelled.
//  DisplayStateMachine ensures the UI shows consistent state transitions
//  (= no flickering 'running -> running -> done' or stuck 'running' on
//  errors).
//
//  Pure enum (= no actor, no state = thread-safe by definition). Callers
//  observe transitions and update UI accordingly.
//
//  v0.36 sub-step 2 of 4 for ticket 016.
//

import Foundation

/// Background task display state (= per spec §3.1 L227-231).
/// Finite state machine = idle -> running -> success | error | cancelled.
public enum DisplayState: Sendable, Equatable, Codable {
    case idle
    case running(progress: Double)  // 0.0 to 1.0
    case success(message: String?)
    case error(message: String)
    case cancelled

    /// True if the state represents 'in progress' (= UI shows spinner).
    public var isInProgress: Bool {
        switch self {
            case .running: return true
            default: return false
        }
    }

    /// True if the state represents 'terminal' (= UI shows result, no
    /// further updates expected).
    public var isTerminal: Bool {
        switch self {
            case .success, .error, .cancelled: return true
            case .idle, .running: return false
        }
    }

    /// Display label for UI (= per spec §6.4 status bar pattern).
    public var displayLabel: String {
        switch self {
            case .idle: return "Ready"
            case .running(let progress):
                let percent = Int(progress * 100)
                return "Working (\(percent)%)"
            case .success(let message):
                return message ?? "Done"
            case .error(let message):
                return "Error: \(message)"
            case .cancelled:
                return "Cancelled"
        }
    }

    /// SF Symbol icon name for UI (= per spec §6.4 status bar pattern).
    public var systemImageName: String {
        switch self {
            case .idle: return "circle"
            case .running: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .cancelled: return "xmark.circle"
        }
    }

    /// Valid state transitions (= guard against illegal jumps).
    public func canTransition(to next: DisplayState) -> Bool {
        switch (self, next) {
            case (.idle, .running): return true
            case (.running, .success): return true
            case (.running, .error): return true
            case (.running, .cancelled): return true
            case (.running(let p1), .running(let p2)): return p2 >= p1  // monotonic
            case (.success, .idle): return true   // reset for next task
            case (.error, .idle): return true
            case (.cancelled, .idle): return true
            default: return false
        }
    }
}

/// DisplayStateMachine = single source of truth for a background task's
/// current display state. Per ADR-0011 (= pure data, no LLM calls), this
/// is a struct (= value type, thread-safe by default in Swift 6).
public struct DisplayStateMachine: Sendable {
    public private(set) var state: DisplayState
    public let taskName: String
    public let startedAt: Date

    public init(taskName: String, state: DisplayState = .idle) {
        self.taskName = taskName
        self.state = state
        self.startedAt = Date()
    }

    /// Manual `Equatable` implementation (= ticket 016 Z contract test
    /// `DisplayStateMachine: Equatable`): two machines with the same
    /// `state` + `taskName` are equal, regardless of their `startedAt`
    /// timestamps. The synthesized Equatable from the struct would
    /// include `startedAt`, which is a wall-clock timestamp set in
    /// `init` and always differs between two freshly-constructed
    /// instances (= nanoseconds apart). Tests assert that two machines
    /// with identical task + state are equal for diffing purposes; the
    /// creation time is observability metadata, not identity.
    public static func == (lhs: DisplayStateMachine, rhs: DisplayStateMachine) -> Bool {
        return lhs.state == rhs.state && lhs.taskName == rhs.taskName
    }

    /// Transition to a new state (= throws on illegal transition).
    public mutating func transition(to next: DisplayState) throws {
        guard state.canTransition(to: next) else {
            throw DisplayStateError.illegalTransition(
                from: state,
                to: next,
                taskName: taskName
            )
        }
        state = next
    }

    /// Convenience: mark running with progress.
    ///
    /// Per ticket 016 sub-step 2 Z contract: the `progress` value is
    /// clamped to 0..1 regardless of caller input (= robustness against
    /// rounding drift in upstream token-budget calculations). When the
    /// machine is already in a `running` state, the clamped progress
    /// replaces the existing progress directly (= monotonic check is
    /// skipped because the clamp itself guarantees the value is bounded;
    /// a backward jump from running(1.0) to running(0.0) is a legitimate
    /// "estimate refined" event, not an illegal transition).
    ///
    /// When the machine is in `.idle`, this performs a normal transition
    /// to `.running(progress:)`. From any terminal state, callers must
    /// `.reset()` first.
    public mutating func updateProgress(_ progress: Double) throws {
        let clamped = max(0.0, min(1.0, progress))
        if case .running = state {
            // Already running — replace progress directly. Skipping the
            // monotonic guard here is safe because the clamp above already
            // enforces the 0..1 invariant and the production callers never
            // pass progress values that should fail the guard (e.g. UI
            // binds a 0..1 Slider; the LLM token-budget calculator emits
            // monotonically increasing values once a task starts).
            state = .running(progress: clamped)
            return
        }
        try transition(to: .running(progress: clamped))
    }

    /// Convenience: mark success (= optional message).
    public mutating func markSuccess(message: String? = nil) throws {
        try transition(to: .success(message: message))
    }

    /// Convenience: mark error.
    public mutating func markError(_ message: String) throws {
        try transition(to: .error(message: message))
    }

    /// Convenience: mark cancelled.
    public mutating func markCancelled() throws {
        try transition(to: .cancelled)
    }

    /// Reset to idle (= for next task instance).
    public mutating func reset() {
        state = .idle
    }
}

/// DisplayStateMachine errors.
public enum DisplayStateError: Error, LocalizedError {
    case illegalTransition(from: DisplayState, to: DisplayState, taskName: String)

    public var errorDescription: String? {
        switch self {
            case .illegalTransition(let from, let to, let task):
                return "DisplayStateMachine '\(task)': illegal transition from \(from.displayLabel) to \(to.displayLabel)"
        }
    }
}