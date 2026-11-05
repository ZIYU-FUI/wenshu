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
    ///   - readingLibrary: how the library is read, = when the
    ///     librarian's report can be checked against it. = Without it
    ///     the report is the model's own words and nothing more.
    static func format(
        handle: BackgroundDelegationHandle,
        text: String,
        readingLibrary: (@Sendable () async -> LibraryCorpusRead)? = nil
    ) async -> SubAgentResultFormatter {
        guard handle.agentName == SubAgentRoleRegistry.librarian.slug else {
            // Every other agent answers in prose, = and prose is what
            // the user should see. = The formatter does not add the
            // agent's name to it: = saying who answered is the
            // delivery's job, = because the delivery is what puts the
            // answer in the conversation.
            return SubAgentResultFormatter(text: text)
        }

        switch LibrarianReport.parse(text) {
        case let .report(result, documents):
            // The report is checked against the library when the
            // library can be read. = The check is what turns "the
            // model said two documents landed" into "the library
            // holds one of them, = and the other one is not there".
            var verifications: [LibrarianReport.Verification]?
            var unreadableNotice = ""
            if let readingLibrary {
                switch await readingLibrary() {
                case let .documents(references):
                    verifications = LibrarianReport.verify(documents, against: references)
                case let .unreadable(reason):
                    // The corpus could not be read. = The check did
                    // not run, = so the report must say that and NOT
                    // say the documents are missing. = A check that
                    // could not run and reports "not there" is the
                    // same lie as a check that points at the wrong
                    // directory.
                    unreadableNotice = LibraryCorpusRead.unreadable(reason).unreadableNotice
                }
            }
            return SubAgentResultFormatter(
                result: result,
                text: LibrarianReport.text(
                    for: result,
                    verifications: verifications,
                    unreadableNotice: unreadableNotice
                )
            )
        case .unreadable:
            // The run said something this app cannot read. = The user
            // sees what it said, = because a raw answer is better
            // than a silent empty one.
            return SubAgentResultFormatter(text: text)
        }
    }

    /// The text the conversation shows: = the agent's label, = and
    /// then what it said.
    ///
    /// It moved here from the delivery, = because the two answer the
    /// same question (= what does the user see when a run finishes?)
    /// = and the delivery now asks this formatter for the shape and
    /// then adds the label itself.
    static func body(for handle: BackgroundDelegationHandle, result: String) -> String {
        let label = SubAgentRoleRegistry.role(forSlug: handle.agentName)?.displayLabel
            ?? handle.agentName
        return "\(label)\n\n\(result)"
    }
}
