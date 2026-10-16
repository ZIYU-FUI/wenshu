//
//  ImportServiceBodyWriter.swift
//
//  Body computation helper extracted from ImportService.swift
//  (= §6.6 god-class split + discoverability: computeBodyToWrite
//  = 30 LOC moved out of the main file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1521 LOC = 2.5x the 600-LOC cap. The
//  `computeBodyToWrite` is a single concern (= "decide which body
//  to write based on the rewrite mode + the LLM's output"). Putting
//  it in a dedicated file named after the concern
//  (= ImportServiceBodyWriter.swift) lets the next reader find the
//  body-decision logic by name.
//
//  This func is static (= no instance state; = safe to call from
//  any context).
//

import Foundation

/// Namespace container for the body-decision helper. Wrapped in an
/// enum (= same pattern as A56's `enum ImportServiceDedup` and A59's
/// `enum ImportServiceHashing`).
enum ImportServiceBodyWriter {

    /// Compute the body to write based on the rewriteMode (= .consolidate
    /// always uses the original verbatim; = .reorganize produces no main file
    /// body (= the agent's writeBookDoc tool owns the writes); =
    /// .searchAndRewrite prefers the LLM's `rewrittenBody` when present,
    /// falling back to the original).
    static func computeBodyToWrite(
        originalBody: String,
        rewrittenBody: String?,
        folder: BookFolder,
        rewriteMode: ImportFileInput.RewriteMode
    ) -> String {
        switch rewriteMode {
        case .consolidate:
            return ImportDocumentTemplate.prepareBodyForWrite(
                rawBody: originalBody,
                folder: folder
            )
        case .reorganize:
            // The agent owns writing in .reorganize mode; = the orchestrator
            // has nothing to write for the main file (= rewrittenBody is always
            // nil per routeReorganizeMultiTurn's signature).
            return ""
        case .searchAndRewrite:
            if let rewritten = rewrittenBody, !rewritten.isEmpty {
                return ImportDocumentTemplate.prepareBodyForWrite(
                    rawBody: rewritten,
                    folder: folder
                )
            }
            return ImportDocumentTemplate.prepareBodyForWrite(
                rawBody: originalBody,
                folder: folder
            )
        }
    }

}
