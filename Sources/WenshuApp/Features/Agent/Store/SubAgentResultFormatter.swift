//
//  SubAgentResultFormatter.swift · Wenshu
//
//  How one agent's result reads in the conversation.
//
//  Every agent answers in its own shape. = The researcher answers in
//  prose, = and prose is what the user should see. = The librarian
//  answers in a JSON report, = because it files documents and the
//  user needs to know WHICH ones and WHAT happened to each, = and a
//  raw JSON blob in a chat is not that.
//
//  So the result is formatted per agent, = and the agent that has no
//  formatter of its own gets its text unchanged. = The formatter
//  lives here, = beside the delivery, = because the two answer the
//  same question: = what does the user see when a run finishes?
//
//  The librarian's formatter also RECORDS the report, = because the
//  `LibrarianResult` type is how the app says what a run did, = and
//  without a reader for the JSON it had no producer at all.
//

import Foundation
import WenshuData

/// Formats one agent's finished result for the conversation.
struct SubAgentResultFormatter: Sendable {

    /// What the run produced, = in the app's vocabulary.
    ///
    /// Nil = the run's text is not in a shape this app reads, = and
    /// the text itself is what the user should see. = A run that
    /// reported something unreadable is NOT an empty success.
    let result: LibrarianResult?

    /// The text the conversation shows.
    let text: String

    init(result: LibrarianResult? = nil, text: String) {
        self.result = result
        self.text = text
    }

    /// Format a finished run's result.
    ///
    /// - Parameters:
    ///   - agentName: which agent produced it.
    ///   - text: what the run produced.
    static func format(agentName: String, text: String) -> SubAgentResultFormatter {
        guard agentName == SubAgentRoleRegistry.librarian.slug else {
            // Every other agent answers in prose, = and prose is what
            // the user should see.
            return SubAgentResultFormatter(text: text)
        }

        switch LibrarianReport.parse(text) {
        case .report(let result):
            return SubAgentResultFormatter(
                result: result,
                text: LibrarianReport.text(for: result)
            )
        case .unreadable(let raw):
            // The run said something this app cannot read. = The user
            // sees what it said, = because a raw answer is better
            // than a silent empty one.
            return SubAgentResultFormatter(text: raw)
        }
    }
}
