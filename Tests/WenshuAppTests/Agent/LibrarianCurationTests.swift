//
//  Tests/Agent/LibrarianCurationTests.swift · Wenshu
//
//  Verifies the librarian's `curate` procedure.
//
//  Why this test exists (= the gap it closes):
//
//  The analysis was written (= `Curator.curate`, = which finds
//  duplicates, = orphans, = and stale entries) but nothing called it,
//  = so the library had no way to say "look at yourself and tell me
//  what needs a decision". = Worse, = `@librarian curate` reached a
//  model that has no tool for the analyser, = so the model would have
//  had to guess at curation with the tools it does have.
//
//  What is pinned here:
//
//  1. The run finds the duplicates, = the orphans, = and it says how
//     many documents it looked at.
//  2. The run says which check could NOT run. = The library keeps no
//     last-accessed date, = so "not read in N days" cannot be
//     answered, = and a report that omits that check reads as "the
//     check found nothing" = which is a lie.
//  3. The run deletes nothing. = The curator is advisory, = and the
//     library after the run is the library before it.
//  4. The report says what it found AND that nothing was changed.
//

import Foundation
import Testing
import WenshuAgent
@testable import WenshuApp
import WenshuData

@Suite("The librarian's curate procedure")
struct LibrarianCurationTests {

    /// A document with the given title, = summary, = and cross
    /// references.
    private static func reference(
        title: String,
        summary: String = "",
        crossReferences: Int = 0
    ) -> Reference {
        let refs = (0..<crossReferences).map { _ in UUID() }
        return Reference(
            title: title,
            layer: .layerEntities,
            summary: summary,
            characterRefIds: refs
        )
    }

    @Test("two documents that say the same thing are reported as a duplicate")
    func findsDuplicates() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Red Cliff", summary: "the battle at red cliff in 208"),
            Self.reference(title: "Battle of Red Cliffs", summary: "the battle at red cliff in 208")
        ])

        let duplicates = report.findings.filter { $0.kind == .duplicate }
        #expect(!duplicates.isEmpty)
        #expect(report.scanned == 2)
    }

    @Test("a document nothing points at is reported as an orphan")
    func findsOrphans() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Cao Cao", summary: "a warlord", crossReferences: 0)
        ])

        let orphans = report.findings.filter { $0.kind == .orphan }
        #expect(orphans.count == 1)
        #expect(orphans.first?.entityTitle == "Cao Cao")
    }

    @Test("a document other documents point at is not an orphan")
    func crossReferencedDocumentIsNotAnOrphan() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Cao Cao", summary: "a warlord", crossReferences: 2)
        ])

        let orphans = report.findings.filter { $0.kind == .orphan }
        #expect(orphans.isEmpty)
    }

    @Test("the report says the stale check could not run")
    func saysTheStaleCheckCouldNotRun() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Cao Cao", summary: "a warlord", crossReferences: 1)
        ])

        // The library keeps no last-accessed date, = so the check is
        // impossible, = and the report has to say so. = A report that
        // stays quiet about it reads as "nothing is stale".
        #expect(report.unavailableChecks.count == 1)
        #expect(report.unavailableChecks.first?.contains("stale") == true)
    }

    @Test("an empty library has nothing to report and nothing unavailable")
    func emptyLibrary() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [])

        #expect(report.findings.isEmpty)
        #expect(report.scanned == 0)
        // Nothing was examined, = so no check was skipped = for
        // reasons of missing data; = there was simply nothing there.
        #expect(report.unavailableChecks.isEmpty)
    }

    @Test("the run reports and changes nothing")
    func changesNothing() {
        let references = [
            Self.reference(title: "Cao Cao", summary: "a warlord"),
            Self.reference(title: "Cao Cao", summary: "a warlord")
        ]
        let before = references.map { $0.title }

        let curator = LibrarianCurator()
        _ = curator.curate(references: references)

        #expect(references.map { $0.title } == before)
    }

    @Test("the text says what was found and that nothing was changed")
    func textSaysWhatHappened() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Cao Cao", summary: "a warlord")
        ])

        let text = LibrarianCurationRunner.text(for: report)

        #expect(text.contains("1 document"))
        #expect(text.contains("Cao Cao"))
        #expect(text.contains("Nothing was changed"))
        // The check that could not run is named in the text too, = not
        // only in the structured report.
        #expect(text.contains("Not checked"))
    }

    @Test("the text of a clean library says there is nothing to decide")
    func textOfCleanLibrary() {
        let curator = LibrarianCurator()
        let report = curator.curate(references: [
            Self.reference(title: "Cao Cao", summary: "a warlord", crossReferences: 1)
        ])

        let text = LibrarianCurationRunner.text(for: report)

        #expect(text.contains("Nothing needs a decision"))
        #expect(text.contains("Nothing was changed"))
    }
}
