//
//  LoadingPlaceholderTests.swift · Wenshu
//
//  The project's ONE loading placeholder (= the skeleton mechanism every
//  zone that waits for content asks). Tests = source-level (= per the
//  wenshu test convention): the shape vocabulary is a value type, so it
//  is built directly, and the wiring is read off the source.
//
//  Coverage (= 13 tests, = = and the list below is derived from the
//  file, = = so a test added here and not there is visible):
//      1.  the shape vocabulary is exactly four shapes (= rows / cards /
//          groups / block) = = and no zone invents its own
//      2.  a row shape carries its count and its unit
//      3.  the two row anatomies are DIFFERENT (= the inspector's card
//          and the sidebar's tree row)
//      4.  a group shape carries its count (= the board's own groups)
//      5.  a card shape carries the zone's own grid and the card count
//      6.  the motion is Apple's phase animator (= not a hand-rolled
//          timer)
//      7.  the placeholder draws no glyph and no text
//      8.  every zone whose content arrives draws this component
//      9.  the zone-level spinners are gone (= = the base's four are
//          gone, = = and one zone that had no loading state has one)
//      10. the board's read captures the book before its yield
//      11. an inline activity indicator stays Apple's (= = it is not a
//          zone)
//      12. the placeholder's metrics are tokens (= = not literals)
//      13. the placeholder's own tokens are defined
//

import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("LoadingPlaceholder (= the project's one loading skeleton)")
@MainActor
struct LoadingPlaceholderTests {
    // MARK: - The shape vocabulary

    @Test("The placeholder has exactly four shapes (= rows / cards / groups / block)")
    func shapeVocabulary() throws {
        // The shapes are the ones the workspace's zones actually hold:
        // a list of rows, a grid of cards, a list of groups (= the board's
        // status groups), and a pane with no shape yet.
        // ⇒ The shape is not Equatable (= a card shape carries the
        // zone's own grid), = = so the census counts the CASES.
        var rows = 0
        var cards = 0
        var groups = 0
        var blocks = 0
        var censusNames: [String] = []
        for shape in LoadingPlaceholder.Shape.shapeCases {
            switch shape {
            case .rows: rows += 1; censusNames.append("rows")
            case .cards: cards += 1; censusNames.append("cards")
            case .groups: groups += 1; censusNames.append("groups")
            case .block: blocks += 1; censusNames.append("block")
            }
        }
        #expect(rows == 1)
        #expect(cards == 1)
        #expect(groups == 1)
        #expect(blocks == 1)

        // ⇒ ⇒ ⇒ AND THE CENSUS COVERS THE ENUM: = = the census is a
        // list of examples, = = so nothing forces a new case into it.
        // The enum is read from the SOURCE, = = so a shape the census
        // forgot IS caught here (= = and that is what the component's
        // own doc block promises).
        let source = try String(
            contentsOf: SourceLocator.repoRoot.appendingPathComponent(
                "Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift"
            ),
            encoding: .utf8
        )
        let enumCases = Self.shapeCaseNames(in: source)
        // ⇒ ⇒ ⇒ AND THE CENSUS COVERS THE ENUM (= = not merely "the
        // enum has four cases"): = = the census's own names are compared
        // with the enum's, = = so a census that forgot a shape IS caught
        // here.
        #expect(Set(censusNames) == Set(enumCases))
        #expect(Set(enumCases) == ["rows", "cards", "groups", "block"])
        #expect(enumCases.count == 4)
    }

    /// The enum's case names, read from the source.
    ///
    /// ⇒ ⇒ ⇒ AND WHY IT IS READ FROM THE SOURCE: = = the census is a
    /// list of examples the component carries, = = so nothing in the
    /// compiler ties the enum's cases to it. = = ⇒ ⇒ ⇒ The source is
    /// what makes the pair checkable.
    private static func shapeCaseNames(in source: String) -> [String] {
        // ⇒ ⇒ ⇒ AND THE BODY IS BOUNDED: = = the enum's closing brace
        // ends it (= = none of its cases carries one), = = so the switch
        // arms in the view's own body (= = which also start with "case ")
        // stay out.
        guard let enumBody = source.components(separatedBy: "enum Shape {").last?
            .components(separatedBy: "}").first
        else { return [] }
        return enumBody
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("case ") else { return nil }
                let rest = trimmed.dropFirst("case ".count)
                return rest.prefix { $0.isLetter }.description
            }
    }

    @Test("A row shape carries its count (= the list's own count) and its unit")
    func rowShapeCarriesCount() {
        guard case let .rows(count, unit) = LoadingPlaceholder.Shape.rows(
            count: 5,
            unit: .inspectorCard
        ) else {
            Issue.record("the row shape must carry its count")
            return
        }
        #expect(count == 5)
        #expect(unit.leadingWidth == DesignTokens.inspectionMarkerColumnWidth)
    }

    @Test("The two row anatomies are DIFFERENT (= the inspector's card and the sidebar's row)")
    func theTwoRowAnatomiesAreDifferent() {
        // ⇒ ⇒ ⇒ The two rows the app has are NOT the same shape: = = the
        // inspector's card leads with a 16 PT marker column and
        // carries two text rows, = = and the sidebar's tree row
        // leads with an 18 PT icon and carries one title. = = ⇒ ⇒
        // One hard-wired row would match neither, = = and the
        // reserved row would be the wrong height.
        #expect(LoadingPlaceholder.Row.inspectorCard.leadingWidth
            != LoadingPlaceholder.Row.sidebarRow.leadingWidth)
        #expect(LoadingPlaceholder.Row.inspectorCard.bars.count
            != LoadingPlaceholder.Row.sidebarRow.bars.count)
    }

    @Test("A group shape carries its count (= the board's own group count)")
    func groupShapeCarriesCount() {
        guard case let .groups(count) = LoadingPlaceholder.Shape.groups(count: 8) else {
            Issue.record("the group shape must carry its count")
            return
        }
        #expect(count == 8)
    }

    @Test("A card shape carries the zone's own grid and the card count")
    func cardShapeCarriesGridAndCount() {
        guard case let .cards(columns, count) = LoadingPlaceholder.Shape.cards(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            count: 4
        ) else {
            Issue.record("the card shape must carry its grid and its count")
            return
        }
        #expect(columns.count == 2)
        #expect(count == 4)
    }

    // MARK: - The motion (= Apple's own primitive)

    @Test("The motion is Apple's phase animator (= not a hand-rolled timer)")
    func motionIsApplesPhaseAnimator() throws {
        let source = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift"
        )
        #expect(source.contains("phaseAnimator"),
                "the placeholder's motion must be Apple's phase animator")
        #expect(!source.contains("Timer"),
                "the placeholder must not hand-roll a timer")
        #expect(!source.contains("LinearGradient") && !source.contains("RadialGradient"),
                "the placeholder must not hand-roll a shimmer gradient")
    }

    // MARK: - The placeholder carries no message

    @Test("The placeholder draws no glyph and no text")
    func placeholderCarriesNoMessage() throws {
        let source = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift"
        )
        #expect(!source.contains("Text("),
                "a placeholder carries no text (= a skeleton with a label is a spinner)")
        #expect(!source.contains("Image("),
                "a placeholder carries no glyph")
        #expect(!source.contains("SFIcon"),
                "a placeholder carries no glyph")
    }

    // MARK: - The zones ask this component

    /// The zones whose content ARRIVES (= a tree, a document list, a task
    /// list, a plan, a board). Each must draw the project's placeholder.
    private static let zoneLoadingSites = [
        "Sources/WenshuApp/Features/Library/View/AppleSidebarView.swift",
        "Sources/WenshuApp/Features/Editor/View/PreviewPaneScopeViews.swift",
        "Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift",
        "Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift",
        "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
    ]

    @Test("Every zone whose content arrives draws the project's placeholder")
    func zonesDrawThePlaceholder() throws {
        for path in Self.zoneLoadingSites {
            let source = try SourceLocator.read(path)
            #expect(source.contains("LoadingPlaceholder("),
                    "\(path) must draw the project's one loading placeholder")
        }
    }

    @Test("The zone-level spinners are gone (= the zones share one picture)")
    func zoneSpinnersAreGone() throws {
        for path in Self.zoneLoadingSites {
            let source = try SourceLocator.read(path)
            #expect(!source.contains("ProgressView()"),
                    "\(path) must not draw its own spinner (= one door for the loading state)")
        }
    }

    // MARK: - The board's read cannot answer for the wrong book

    @Test("The board's read captures the book before its yield (= so a second read owns the write)")
    func theBoardCapturesTheBookBeforeItsYield() throws {
        let source = try SourceLocator.read(
            "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift"
        )
        // ⇒ ⇒ ⇒ The book is read BEFORE the yield: = = a read that read
        // the book after its yield would answer for the book the
        // user has already switched to.
        let bookRead = try #require(source.range(of: "let bookID = focusedBookID?.rawValue"))
        let yield = try #require(source.range(of: "await Task.yield()"))
        #expect(bookRead.lowerBound < yield.lowerBound,
                "the board must capture the book BEFORE its yield")
        // ⇒ ⇒ ⇒ AND THE WRITE IS GUARDED: = = the read that started
        // first can land second (= = and it must not write). = = ⇒ ⇒ ⇒
        // The invariant is the ORDER (= = the guard before the write),
        // = = not the guard's presence (= = the error branch carries the
        // same guard, = = so its presence alone would pass on a board
        // whose write is unguarded).
        let guardRange = try #require(
            source.range(of: "guard loadCounter.isCurrent(generation) else { return }")
        )
        let writeRange = try #require(source.range(of: "cardsByStatus = buckets"))
        #expect(guardRange.lowerBound < writeRange.lowerBound,
                "the board's write must be guarded (= so a stale read cannot answer for the wrong book)")
    }

    // MARK: - The inline activity indicators stay Apple's own

    @Test("An inline activity indicator stays Apple's (= it is not a zone)")
    func inlineIndicatorsStayApples() throws {
        // A badge, a diagnostics row and an import row are small
        // activities inside a surface, = = not zones whose content
        // arrives. = = Apple's indeterminate indicator is the right
        // answer there (= the progress-indicators article's own case).
        let inlineSites = [
            "Sources/WenshuApp/Features/Editor/View/ChapterFocusLockBadge.swift",
            "Sources/WenshuApp/Features/Settings/View/NetworkDiagnosticsPane.swift",
            "Sources/WenshuApp/Features/Agent/View/ImportSheetHelpers.swift",
        ]
        for path in inlineSites {
            let source = try SourceLocator.read(path)
            #expect(source.contains("ProgressView("),
                    "\(path) keeps Apple's own inline activity indicator")
            #expect(!source.contains("LoadingPlaceholder("),
                    "\(path) is an inline activity, = = not a zone whose content arrives")
        }
    }

    // MARK: - The tokens

    @Test("The placeholder's metrics are tokens (= not literals in the view)")
    func metricsAreTokens() throws {
        let source = try SourceLocator.read(
            "Sources/WenshuApp/Shared/UI/LoadingPlaceholder.swift"
        )
        #expect(!source.contains("cornerRadius: 8")
            && !source.contains("cornerRadius: 10")
            && !source.contains("cornerRadius: 16"),
            "the placeholder's corner radii must come from DesignTokens")
        #expect(source.contains("DesignTokens.skeletonTextBarHeight"),
                "the placeholder's bar height must come from DesignTokens")
        #expect(source.contains("DesignTokens.textPlaceholder"),
                "the placeholder's ink must come from DesignTokens")
    }

    @Test("The placeholder's own tokens are defined")
    @MainActor
    func tokensAreDefined() {
        #expect(DesignTokens.skeletonTextBarHeight == 10)
        #expect(DesignTokens.skeletonTextBarHeightLarge == 12)
        #expect(DesignTokens.inspectionMarkerColumnWidth == 16)
    }
}
