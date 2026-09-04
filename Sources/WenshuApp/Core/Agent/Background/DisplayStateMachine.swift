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
public struct DisplayStateMachine: Sendable, Equatable {
    public private(set) var state: DisplayState
    public let taskName: String
    public let startedAt: Date

    public init(taskName: String, state: DisplayState = .idle) {
        self.taskName = taskName
        self.state = state
        self.startedAt = Date()
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
    public mutating func updateProgress(_ progress: Double) throws {
        let clamped = max(0.0, min(1.0, progress))
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