// KanbanCardContent.swift
//
// One board card's content (= its task + the body already parsed).
//
// The card's body is MARKDOWN, = and parsing it is work. = The board
// used to parse it inside the card's body, = so every body pass
// parsed every task's body on the board (= once per card, = and the
// board holds one card per task).
//
// So the body is parsed ONCE, = at the board's loading boundary
// (= where the board reads its tasks), = and the card draws the
// parsed text (= the same text, = the same parser, = the same result).
//
// Pure value type (= no SQLite dependency), = like the rest of the
// board's model.
//

import Foundation

/// One board card's content (= its task and its parsed body).
struct KanbanCardContent: Identifiable, Equatable, Sendable {
    /// The task the card shows (= its title, its group and its state).
    let task: KanbanTask

    /// The task's body, parsed once (= nil when the task has no body).
    ///
    /// The markdown is the board's own body parser's output (= the
    /// same inline parser the chat uses), = so the card draws exactly
    /// the text it drew before.
    let parsedBody: AttributedString?

    /// The card's identity (= the task's).
    var id: String {
        task.id
    }

    /// The content of one task (= the body parsed once, = at the load).
    init(task: KanbanTask, parsedBody: AttributedString?) {
        self.task = task
        self.parsedBody = parsedBody
    }
}
