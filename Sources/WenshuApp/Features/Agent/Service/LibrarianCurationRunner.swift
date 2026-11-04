//
//  LibrarianCurationRunner.swift · Wenshu
//
//  Runs the librarian's `curate` procedure and says what it found.
//
//  Why this is code and not a prompt:
//
//  The curation analysis is deterministic (= `Curator.curate`, = pure
//  data analysis, = no model call, = per ADR-0011). = Handing it to a
//  model would mean asking the model to do arithmetic and
//  comparisons it has no tool for, = and then reporting whatever it
//  said. = The librarian's tool list does not include the analyser,
//  = so a model asked to curate would have had to guess with the
//  tools it does have. = That is the "the prompt promises the model
//  something the code cannot deliver" failure, = and it was fixed
//  once already for the role tool lists.
//
//  So the procedure runs here: = the library's documents go in, = the
//  analyser's report comes out, = and the conversation shows the
//  report. = The run deletes nothing. = A document the user kept is
//  the user's document.
//

import Foundation
import WenshuData

/// Runs one `curate` procedure and formats its outcome.
@MainActor
struct LibrarianCurationRunner {

    /// The library the run looks at.
    let library: ReferenceLibraryActor

    /// The thresholds the analysis uses.
    let curator: LibrarianCurator

    init(library: ReferenceLibraryActor, curator: LibrarianCurator = LibrarianCurator()) {
        self.library = library
        self.curator = curator
    }

    /// The outcome of one run.
    enum Outcome: Sendable, Equatable {
        /// The run looked at the library and reported.
        case reported(LibrarianCurator.Report)

        /// The run could not read the library.
        case failed(String)
    }

    /// Run the procedure.
    func run() async -> Outcome {
        let references: [Reference]
        do {
            references = try await library.allReferencesForCuration()
        } catch {
            return .failed(String(describing: error))
        }
        return .reported(curator.curate(references: references))
    }

    /// The text the conversation shows.
    ///
    /// The report says three things: = what needs a decision, = how
    /// many documents were looked at, = and which check could not
    /// run. = The third one is not optional: = a report that lists
    /// two checks and stays silent about the third reads as "the
    /// third found nothing", = and the third did not look at all.
    nonisolated static func text(for report: LibrarianCurator.Report) -> String {
        var lines: [String] = []
        lines.append("Library curation: \(report.scanned) document(s) examined.")

        if report.findings.isEmpty {
            lines.append("")
            lines.append("Nothing needs a decision.")
        } else {
            lines.append("")
            lines.append("What needs a decision (\(report.findings.count)):")

            // Group by kind, = because the user decides per kind
            // (= merge the duplicates, = look at the orphans).
            let byKind = Dictionary(grouping: report.findings, by: \.kind)
            for kind in [CurationFinding.Kind.duplicate, .orphan, .stale] {
                guard let group = byKind[kind], !group.isEmpty else { continue }
                lines.append("")
                lines.append("\(label(for: kind)) (\(group.count)):")
                for finding in group {
                    lines.append("- \(finding.entityTitle): \(finding.description)")
                }
            }
        }

        if !report.unavailableChecks.isEmpty {
            lines.append("")
            for check in report.unavailableChecks {
                lines.append("Not checked: \(check)")
            }
        }

        lines.append("")
        lines.append("Nothing was changed. = The report is for you to decide on.")
        return lines.joined(separator: "\n")
    }

    /// The heading for a finding kind.
    nonisolated private static func label(for kind: CurationFinding.Kind) -> String {
        switch kind {
        case .duplicate: return "Possible duplicates"
        case .stale: return "Stale entries"
        case .orphan: return "Orphans"
        }
    }
}
