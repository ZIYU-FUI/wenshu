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
//  WHY the book travels beside it: the two session-id shapes carry
//  different information. A per-book chat's id is
//  `book:<uuid>:default` (= the book is inside it), but a brand new
//  chat's id is `s_<uuid>` (= the book is NOT). A new chat's session id
//  therefore cannot decide the book, so the book rides as its own value
//  and the tool can stamp both halves onto what it creates.
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

    /// The book the running turn belongs to. Nil = the turn names no book.
    @TaskLocal public static var currentBookID: String?

    /// Run `operation` with the given session and book bound around it.
    ///
    /// The binding covers the whole turn (= the tools the model calls
    /// run inside it), so a tool that asks for the scope sees the turn
    /// that called it.
    ///
    /// A turn with no book (= the A2A path) binds a nil book, so the
    /// book half stays empty rather than inventing one.
    public static func withScope<R>(
        sessionID: String,
        bookID: String? = nil,
        operation: () async throws -> R
    ) async rethrows -> R {
        try await $currentSessionID.withValue(sessionID) {
            try await $currentBookID.withValue(bookID) {
                try await operation()
            }
        }
    }
}
