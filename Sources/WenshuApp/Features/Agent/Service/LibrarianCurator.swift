//
//  LibrarianCurator.swift · Wenshu
//
//  The librarian's `curate` procedure, executed.
//
//  The analysis itself was already written (= `Curator.curate`,
//  which finds duplicates, = orphans, = and stale entries). = What
//  was missing was the run: = nothing called it, = so the library
//  had no way to say "look at yourself and tell me what needs a
//  decision".
//
//  This is that run, and it does three things:
//
//  1. It adapts the library's documents to what the analyser reads.
//     The analyser was written against a flat entity (= id, = title,
//     = snippet, = last-accessed, = cross-reference count); = the
//     library's document is a richer thing, = so the mapping is
//     spelled out here, = in one place, = rather than guessed at
//     inside the analysis.
//  2. It runs the analysis. = No model call, = per ADR-0011.
//  3. It says what it found, = and it says what it COULD NOT find.
//     One of the analyser's three checks needs a fact the library
//     does not keep, = and a report that quietly omits a check reads
//     as "nothing to report", = which is a lie.
//
//  The run never deletes anything. = A document the user kept is the
//  user's document; = the report tells the user what needs a
//  decision, = and the decision is the user's.
//

import Foundation
import WenshuData

/// Runs the librarian's `curate` procedure.
struct LibrarianCurator: Sendable {

    /// What one curation run found.
    ///
    /// The findings are the analyser's own (= `CurationFinding`),
    /// so the report says the same thing the analyser said, = and a
    /// finding does not get re-described on the way out.
    struct Report: Sendable, Equatable {
        /// The findings, = one per thing that needs a decision.
        let findings: [CurationFinding]

        /// How many documents were looked at.
        let scanned: Int

        /// The checks that could NOT run, = and why.
        ///
        /// Nil = every check ran. A check that could not run is named
        /// here, = because a report that omits a check reads as "no
        /// problem found" = and that is how a gap turns into a
        /// silent wrong answer.
        let unavailableChecks: [String]

        init(
            findings: [CurationFinding] = [],
            scanned: Int = 0,
            unavailableChecks: [String] = []
        ) {
            self.findings = findings
            self.scanned = scanned
            self.unavailableChecks = unavailableChecks
        }
    }

    /// The thresholds the analysis uses.
    let config: Curator.Config

    init(config: Curator.Config = Curator.Config()) {
        self.config = config
    }

    /// Analyse the library's documents.
    ///
    /// - Parameter references: the documents to look at (= the
    ///   user-managed layers, = which is what the user browses).
    /// - Returns: what needs a decision, = and what could not be
    ///   checked.
    func curate(references: [Reference]) -> Report {
        let entities = references.map(Self.entity(for:))

        // The analyser skips an entity whose last-accessed date is
        // nil (= its stale check is `if let lastAccess = ...`).
        //
        // The library does not keep a last-accessed date. = It keeps
        // when a document was last CHANGED, = which is a different
        // fact: = a document the user reads every day and never edits
        // would look stale under that substitution, = and a document
        // the user edited once and never opened again would not. = So
        // the date is left nil, = the stale check does not run, = and
        // the report says which check did not run.
        let report = Curator.curate(entities: entities, config: config)

        var unavailable: [String] = []
        if !references.isEmpty {
            unavailable.append(
                "stale (= the library keeps no last-accessed date, = so 'not read in N days' cannot be answered)"
            )
        }

        return Report(
            findings: report.findings,
            scanned: report.totalEntitiesScanned,
            unavailableChecks: unavailable
        )
    }

    /// The analyser's view of one library document.
    ///
    /// The mapping, = spelled out:
    ///
    /// - `id` = the document's id, = as a string (= the analyser
    ///   compares ids as strings, = and a finding has to name the
    ///   document it is about).
    /// - `title` = the document's title.
    /// - `snippet` = the document's summary, = which is what the
    ///   duplicate check compares. = The summary is the document's
    ///   own description of itself, = and two documents that say the
    ///   same thing in the same words ARE the duplicate case the
    ///   check is looking for.
    /// - `lastAccessedAt` = nil, = because the library does not keep
    ///   it. = See the note in `curate(references:)`.
    /// - `crossReferenceCount` = how many other documents point at
    ///   this one. = Zero = an orphan, = which is the analyser's
    ///   third check, = and the check is meaningful here because the
    ///   library does keep cross-references.
    static func entity(for reference: Reference) -> Curator.Entity {
        Curator.Entity(
            id: reference.id.uuidString,
            title: reference.title,
            snippet: reference.summary,
            lastAccessedAt: nil,
            crossReferenceCount: reference.characterRefIds.count
                + reference.worldRefIds.count
                + reference.bookRefIds.count
        )
    }
}
