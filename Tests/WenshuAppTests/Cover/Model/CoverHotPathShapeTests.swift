//
//  Tests/WenshuAppTests/Cover/Model/CoverHotPathShapeTests.swift
//
//   : CoverHotPathShapeTests.
//  A source-reading guard on the cover's hot doors, for the costs a
//  counting seam cannot see.
//
//  Why this suite exists, when the lane already counts. A count only
//  sees an ask that REPORTS to the counter, and that is a hole with a
//  name: put the picture cache's key back to
//  `url.resourceValues(forKeys:)` - the exact shape that cost 24
//  main-thread stats per warm screenful, and the shape the last round
//  removed - and every row the disk census prints still reads 0,
//  because an unannounced ask announces nothing. The library lookup got
//  counted this round precisely because it sat behind a door the census
//  could not see (= `CoverDiskCounting`'s lookup bucket), and a bucket
//  only covers the door it is wired into.
//
//  So this suite holds the SHAPE instead of the number: a declaration
//  that owes the disk nothing is read and checked for owing it nothing,
//  and a counter that has to sit in FRONT of a branch is checked for
//  sitting in front of it. The tree already reads source as the
//  specification elsewhere (= `SourceLocator`), and the guarantee a
//  shape gives is the one a count cannot: it holds on a machine where
//  the ask is free, and on a door nobody wired.
//
//  A guard that fails to LOOK is an error here, never a pass: a missing
//  declaration throws (= `CoverShapeGuardError`), because an assertion
//  over an empty string is the vacuous green this lane was sent back for.
//

import Foundation
import Testing

@Suite("Cover hot paths hold their shape")
struct CoverHotPathShapeTests {
    @Test("The doors that owe no file ask make none, and the counter sits in front of the override")
    func theShapeTheCountingSeamCannotSeeIsHeldByTheSource() throws {
        // 1. THE PICTURE KEY asks the path nothing. `url.path` is the
        // whole of it: a size-and-date key re-pays one metadata ask per
        // card per pass, invisible to a seam that counts announced doors.
        let imageCache = try SourceLocator.readSource(named: "CoverImageCache.swift")
        let keyBody = try body(
            of: "private func key(for url: URL) -> String {",
            in: imageCache,
            file: "CoverImageCache.swift"
        )
        let fileAsks = [
            "resourceValues",
            "fileExists",
            "attributesOfItem",
            "contentsOfDirectory",
            "Data(contentsOf",
        ]
        let asked = fileAsks.filter { keyBody.contains($0) }
        #expect(
            asked.isEmpty,
            "the picture cache's key asks the file \(asked.joined(separator: ", ")) again: one metadata ask per card per pass, and the counting seam cannot see an unannounced ask (= CoverImageCache.key(for:))"
        )

        // 2. THE ENTRY DOOR'S HIT PATH resolves no library. The root
        // arrives as a parameter, so a warm card costs neither a disk ask
        // nor a bookmark decode (= B1, held by its shape as well as by
        // its count).
        let service = try SourceLocator.readSource(named: "CardCoverService.swift")
        let hitBody = try body(
            of: "func entry(forKey key: String, root: URL?) -> CoverEntry {",
            in: service,
            file: "CardCoverService.swift"
        )
        #expect(
            !hitBody.contains("coversRoot") && !hitBody.contains("ActiveLibrary"),
            "the entry door went back to resolving the library itself (= B1): \(hitBody)"
        )

        // 3. NO GRID FILE THIS GUARD READS asks the root-free cover
        // door in its per-card path. The list names EVERY file the rule
        // reads (= the material column's two grid files and the
        // linked-document board, the second grid door B1 was found
        // behind), and the literals name the spellings each file is
        // read for; the rule is NOT a claim about any file outside the
        // list. A root-free ask inside a per-card path is a bookmark
        // decode per card, which is what this lane removed from the
        // column and then from the board.
        let guardedGrids: [(file: String, rootFreeAsks: [String])] = [
            ("PreviewPaneGrids.swift", [
                "coverEntry(for: target)",
                "CardCoverService().entry(forKey: target.coverKey)",
                "CardCoverService().coverImageURL(",
                "CardCoverService().coverVideoURL(",
            ]),
            ("PreviewPaneScopeViews.swift", [
                "coverEntry(for: target)",
                "CardCoverService().entry(forKey: target.coverKey)",
                "CardCoverService().coverImageURL(",
                "CardCoverService().coverVideoURL(",
            ]),
            ("LinkedDocumentCardBoard.swift", [
                "CardCoverService().coverImageURL(",
                "CardCoverService().coverVideoURL(",
                "root: CardCoverService.coversRoot",
            ]),
        ]
        for guarded in guardedGrids {
            let source = try SourceLocator.readSource(named: guarded.file)
            let perCardAsks = guarded.rootFreeAsks.filter { source.contains($0) }
            #expect(
                perCardAsks.isEmpty,
                "\(guarded.file) asks the root-free cover door in its per-card path again: \(perCardAsks.joined(separator: ", ")) (= hoist `CardCoverService.coversRoot` once in `body` and thread the value into the per-card door)"
            )
        }

        // 4. THE INSTRUMENT sits in front of the DEBUG override, not
        // behind it. Counting `LibraryBookmark.resolve()` instead would
        // record nothing in this harness, because every measurement site
        // here sets the override - the vacuous-zero trap.
        let active = try SourceLocator.readSource(named: "ActiveLibrary.swift")
        let pathBody = try body(
            of: "nonisolated static var path: String? {",
            in: active,
            file: "ActiveLibrary.swift"
        )
        let counted = pathBody.range(of: "CoverDiskCounting.noteLibraryLookup()")
        let branch = pathBody.range(of: "#if DEBUG")
        #expect(
            counted != nil && branch != nil && counted!.lowerBound < branch!.lowerBound,
            "the library lookup is no longer counted BEFORE the DEBUG override, so the count is blind to the branch production takes: \(pathBody)"
        )
    }

    /// One declaration's body, from its signature to the line that closes
    /// its scope at this family's indentation (= four spaces).
    ///
    /// A MISSING MARKER IS AN ERROR, never an empty string: a guard that
    /// read nothing and passed is the defect this file exists to avoid.
    private func body(of marker: String, in source: String, file: String) throws -> String {
        guard let opened = source.range(of: marker) else {
            throw CoverShapeGuardError.missingDeclaration(marker, in: file)
        }
        let tail = source[opened.upperBound...]
        var lines: [Substring] = []
        for line in tail.split(separator: "\n", omittingEmptySubsequences: false) {
            if line == "    }" {
                break
            }
            lines.append(line)
        }
        guard !lines.isEmpty else {
            throw CoverShapeGuardError.emptyBody(marker, in: file)
        }
        return lines.joined(separator: "\n")
    }
}

/// The ways a source-reading guard can fail to have looked.
private enum CoverShapeGuardError: Error, CustomStringConvertible {
    case missingDeclaration(String, in: String)
    case emptyBody(String, in: String)

    var description: String {
        switch self {
        case let .missingDeclaration(marker, file):
            "the guard did not find `\(marker)` in \(file): the shape it holds moved, so it proved nothing"
        case let .emptyBody(marker, file):
            "`\(marker)` in \(file) opened a body the reader could not close at this family's indentation"
        }
    }
}
