//
//  TurnScope.swift · WenshuAgent · the scope of the turn in flight
//
//  WHY this exists: the conductor knows which chat session a turn runs
//  for, but the tools it hands to the model do not. The `Tool` protocol
//  carries only the tool's input string (= `execute(input:)`), so the
//  session cannot travel as an argument without changing every tool in
//  the package.
//
//  HOW it travels: a task local. The conductor binds the session around
//  the turn, and a tool reads it when it runs (= the tool executor
//  dispatches inside the bound task, so the value is still there). One
//  mechanism, no signature change, and the session is scoped to the turn
//  that produced it.
//
//  WHY it carries a string: the runtime package does not own the app's
//  domain ids. The app maps this value onto its own typed id at the
//  tool boundary.
//

import Foundation

/// The scope of the turn currently running.
public enum TurnScope {

    /// The chat session the running turn belongs to. Nil = no turn in flight.
    @TaskLocal public static var currentSessionID: String?

    /// Run `operation` with the given session bound around it.
    ///
    /// The binding covers the whole turn (= the tools the model calls
    /// run inside it), so a tool that asks for the session sees the turn
    /// that called it.
    public static func withScope<R>(
        sessionID: String,
        operation: () async throws -> R
    ) async rethrows -> R {
        try await $currentSessionID.withValue(sessionID) {
            try await operation()
        }
    }
}
