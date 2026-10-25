//
//  ReferenceLibraryActor+Summary.swift
//
//  The rule that decides the summary of a reference document.
//
//  Why: a reference document is too long for the agent to read whole,
//  so the agent needs one line that says whether the document
//  constrains the chapter it is writing. That line is
//  `Reference.summary` (= the field the model already has, the card
//  summary the UI already shows, and the line the agent already
//  reads in `ReferenceDescriptor`). The rule that fills it is its own
//  concern, so it lives beside the actor rather than inside it (= the
//  actor is already over the file-size cap).
//

import Foundation

extension ReferenceLibraryActor {

    /// The summary to store on the document.
    ///
    /// - A caller that wrote a summary keeps it (= the caller's words
    ///   win; = the agent often knows the document better than a
    ///   one-line reduction of it does).
    /// - A document that already carries a summary keeps it (= one
    ///   model call per document; = the summary is written once, at
    ///   save time, and is never recomputed on a read).
    /// - A document without one gets a summary from the model (= a
    ///   document nobody can route is no constraint for the writing
    ///   that follows).
    ///
    /// A model failure throws: the document is not stored with a blank
    /// summary, and the failure is not silent (= the app's rule for a
    /// remote call that does not answer).
    func resolveSummary(
        requested: String,
        title: String,
        bodyMarkdown: String,
        keeping existing: String = ""
    ) async throws -> String {
        let trimmed = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let kept = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if !kept.isEmpty { return kept }
        guard let summaryService else { return "" }
        return try await summaryService.summarize(title: title, body: bodyMarkdown)
    }
}
