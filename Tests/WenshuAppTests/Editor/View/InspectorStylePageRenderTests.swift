//
//  InspectorStylePageRenderTests.swift · Wenshu
//
//  The inspector column's style page, rendered.
//
//  The style page is the BOOK's style sheet: = the eleven styles a
//  novel uses, = and the five knobs the book is fine-tuned with. = This
//  suite renders the real page and reads the rendered accessibility tree
//  back, so the facts a source read cannot reach are measured on the
//  page itself:
//
//  1. The page carries the eleven roles and the five knobs.
//  2. Each row shows the face, = the size and = the leading the book's
//     own sheet gives that role.
//  3. The knobs show the SELECTED BOOK's positions, = and two books
//     with different sheets show their own.
//  4. Changing the book changes what the page shows.
//  5. The commands a book sets once (= the strike, = the inline code,
//     = the headings, = the lists, = the quote, = the code block, = the
//     rule and = the link) = are gone from the page.
//  6. The page renders the style rows, = and they come from the
//     model's own rows (= the rows are NOT in the accessibility tree,
//     = so they are held by the page's own source, = with two anchors:
//     = the call site and the binding).
//  7. Each row is shown in the VOICE the engine gives that role (= the
//     face, = the size, = the line height), = and the voice is the
//     engine's own arithmetic, = not the sheet's one multiple read
//     eleven times.
//  8. The page paints each position ONCE (= the drop-down's own AppKit
//     title is transparent: = the one thing a screenshot of the
//     rendered page cannot see, = so it is read off the button).
//  9. The set the book is at is marked, = and the two sets are rows and
//     not drop-downs (= a `Button` publishes nothing to the offscreen
//     tree, = so the mark is proven by the ink it draws).
//
//  The tree is read through the ACCESSIBILITY SYSTEM (= the route the
//  layout probe reads a running app's tree through), because a SwiftUI
//  button publishes itself to that system and never appears in AppKit's
//  view hierarchy.
//
//  swift test --filter InspectorStylePageRenderTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector column style page, rendered", .serialized)
struct InspectorStylePageRenderTests {
    /// The page carries the eleven roles and the five knobs.
    @Test("the page carries the eleven styles and the five knobs")
    func thePageCarriesTheStylesAndTheKnobs() {
        let model = InspectorStylePageModel(sheet: .default)
        #expect(
            model.rows.count == 11,
            "the style table names the eleven roles a novel uses"
        )
        #expect(
            model.rows.map(\.role) == [
                .body, .quote, .note,
                .headingOne, .headingTwo, .headingThree,
                .figureCaption, .tableCaption,
                .image, .rule, .monospace,
            ],
            "the style table names the eleven roles in the order a book is made of"
        )
        #expect(
            InspectorStyleRole.allCases.count == 11,
            "the role enum carries the eleven roles (= the book's own name is not one of them)"
        )
        #expect(
            model.knobs.map(\.id) == [
                "bodySize", "lineSpacing", "firstLineIndent", "segmentSpacing", "bodyFamily",
            ],
            "the page carries the five knobs a book is set with"
        )
    }

    /// Each row shows what the sheet gives it.
    @Test("each row shows the face, the size and the leading the sheet gives it")
    func eachRowShowsWhatTheSheetGivesIt() {
        let sheet = BookStyleSheet(
            bodySize: .large,
            lineSpacing: .loose,
            firstLineIndent: .none,
            segmentSpacing: .halfCharacter,
            bodyFamily: .kai,
            quoteFamily: .heiti,
            headingLadder: .generous,
            headingFamily: .kai
        )
        let model = InspectorStylePageModel(sheet: sheet)
        let body = model.rows.first { $0.role == .body }
        #expect(body?.family == .kai, "the body is set in the body's own face")
        #expect(body?.size == 14, "the body's size is the sheet's body size")
        #expect(body?.spacing == 1.70, "the body runs at the sheet's leading")
        let quote = model.rows.first { $0.role == .quote }
        #expect(quote?.family == .heiti, "the quote is set in the quote's own face")
        #expect(quote?.size == 12.5, "the quote's size is the sheet's quote size")
        let heading = model.rows.first { $0.role == .headingOne }
        #expect(
            heading?.family == .kai,
            "the headings follow the body's own heading face (= the sheet names it)"
        )
        #expect(heading?.size == 18, "the heading's size comes from the sheet's ladder")
        let image = model.rows.first { $0.role == .image }
        #expect(image?.family == nil, "the sheet names no face for the image")
        #expect(
            image?.cells == [InspectorAXTree.unsetName],
            "a role the sheet names nothing for shows a dash (= the print standard's own table writes one)"
        )
    }

    /// The knobs show the selected book's own positions.
    @Test("the knobs show the selected book's own positions")
    func theKnobsShowTheSelectedBooksPositions() throws {
        let (store, plain, _) = try makeStore()
        let workspace = makeWorkspace()
        store.selectedBookId = plain.id
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let labels = rendered.menuLabels()
        #expect(
            labels.count == 5,
            "the page carries the five knobs and nothing else drops down (= the three places are segments, = not menus): \(labels)"
        )
        let positions = rendered.selectedPositions()
        for key in [
            "inspector.style.bodySize.medium",
            "inspector.style.lineSpacing.standard",
            "inspector.style.firstLineIndent.twoCharacters",
            "inspector.style.segmentSpacing.none",
            "inspector.style.family.songti",
        ] {
            #expect(
                positions.contains(InspectorAXTree.positionName(key)),
                "the knob for \(key) must show the book's own position (= the button shows \(positions))"
            )
        }
    }

    /// Each position is painted by exactly one thing: = the button.
    ///
    /// THE DEFECT THIS HOLDS
    ///
    /// The knob used to be a drawn block with the position inside it and a
    /// borderless `Menu` laid over it, = and the AppKit button under that
    /// menu painted the same position a SECOND time (= `.opacity(0)` on the
    /// SwiftUI layer left the button's own title at alpha 0.85, = measured
    /// in this app's process). = The doubled words the boss sent back were
    /// that second painter.
    ///
    /// THE LINE NOW HELD
    ///
    /// Nothing here paints a position at all: = the system's button holds
    /// the only copy, = so its own title must be PAINTED (= a zero alpha
    /// now means the value went invisible, = which is the other half of the
    /// same defect), = and the knob's file must not silence a control to
    /// make room for a drawing of one.
    ///
    /// WHY THIS IS NOT A PIXEL TEST
    ///
    /// The offscreen cache a pixel test reads does NOT contain the AppKit
    /// title (= measured), = so a screenshot of the rendered page cannot
    /// see either copy at all. = The guard reads the button's own title and
    /// colour.
    @Test("the page paints each position once")
    func thePagePaintsEachPositionOnce() throws {
        let (store, plain, _) = try makeStore()
        let workspace = makeWorkspace()
        store.selectedBookId = plain.id
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let popups = rendered.popupButtons()
        #expect(
            popups.count == 5,
            "the five knobs are the page's only drop-downs (= got \(popups.count))"
        )
        #expect(
            Set(popups.map { String(describing: type(of: $0)) }) == ["NSPopUpButton"],
            "the knobs are AppKit's own pop-up buttons (= got \(Set(popups.map { String(describing: type(of: $0)) })))"
        )
        for popup in popups {
            let title = popup.attributedTitle
            #expect(
                title.length > 0,
                "a knob whose button shows no position is a knob a reader cannot see the state of"
            )
            let colour = title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            let alpha = colour?.usingColorSpace(.sRGB)?.alphaComponent ?? 1
            #expect(
                alpha > 0,
                "the button's own title is painted out (alpha \(alpha)) (= something else is drawing it, = which is the doubled word again)"
            )
        }
        let knobCode = try InspectorAXTree.code(of: String(
            contentsOf: Self.knobSourceURL(),
            encoding: .utf8
        ))
        #expect(
            !knobCode.contains(".foregroundStyle(.clear)") && !knobCode.contains(".opacity(0)"),
            "the knob silences a control to make room for a drawing of one (= the inversion that painted every position twice)"
        )
    }

    /// PRESSING A SEGMENT MOVES THE BOOK, = AND THE LIT SEGMENT FOLLOWS.
    ///
    /// THE DEFECT THIS HOLDS
    ///
    /// The boss's report: = "the Print and General switch changed nothing
    /// below it, = and the open document did not change either". = A
    /// switcher that repaints itself and writes nothing is exactly that, =
    /// and it is invisible to every test that only reads what the page
    /// SHOWS (= those all pass on a control that never writes). = So this
    /// case presses the real control and reads the real book.
    ///
    /// WHY THE LIT SEGMENT IS READ BACK TOO
    ///
    /// The segment is not stored anywhere: = it is derived from the book's
    /// sheet (= `BookStyleSelection.select`), = so a lit segment that moved
    /// proves the write reached the book the page is looking at, = and not
    /// only the control's own state.
    @Test("pressing a segment moves the book")
    func pressingASegmentMovesTheBook() throws {
        let (store, plain, _) = try makeStore()
        let workspace = makeWorkspace()
        store.selectedBookId = plain.id
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let control = try #require(rendered.segmentedSwitcher())
        let general = try #require(
            BookStyleSelection.choices.firstIndex(of: .preset(.general))
        )
        #expect(
            control.selectedSegment != general,
            "the fixture must not already be on the segment this case presses"
        )
        //  The press is AppKit's own: = the control's action is what a
        //  reader's click fires, = and the callback chain under it
        //  (= `Binding.set` -> `onChoose` -> the write-back) is what is
        //  being tested.
        control.selectedSegment = general
        let action = try #require(control.action)
        let target = try #require(control.target)
        #expect(
            NSApp.sendAction(action, to: target, from: control),
            "the switcher's control carries no action (= so a click could not reach the book)"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let written = try #require(store.books.first { $0.id == plain.id })
        #expect(
            BookStyleSelection.select(sheet: written.effectiveStyleSheet) == .preset(.general),
            "the book the page is showing must be at the set that was pressed"
        )
        #expect(
            control.selectedSegment == general,
            "the lit segment must be the one the book ended at"
        )
    }

    /// Two books with different sheets show their own.
    @Test("two books with different sheets show their own")
    func twoBooksWithDifferentSheetsShowTheirOwn() throws {
        let (store, plain, other) = try makeStore()
        let workspace = makeWorkspace()
        store.selectedBookId = plain.id
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let plainLabels = rendered.selectedPositions()
        store.selectedBookId = other.id
        let otherLabels = rendered.selectedPositions()
        #expect(
            plainLabels != otherLabels,
            "two books with different sheets must show their own positions: \(plainLabels) vs \(otherLabels)"
        )
        for key in [
            "inspector.style.bodySize.large",
            "inspector.style.lineSpacing.loose",
            "inspector.style.firstLineIndent.none",
            "inspector.style.segmentSpacing.halfCharacter",
            "inspector.style.family.kai",
        ] {
            #expect(
                otherLabels.contains(InspectorAXTree.positionName(key)),
                "the second book's own position must show: \(key)"
            )
        }
    }

    /// Changing the book changes what the page shows.
    @Test("changing the book changes what the page shows")
    func changingTheBookChangesWhatThePageShows() throws {
        let (store, plain, other) = try makeStore()
        let workspace = makeWorkspace()
        store.selectedBookId = plain.id
        let rendered = renderPage(store: store, workspace: workspace)
        defer { rendered.close() }
        let before = rendered.selectedPositions()
        #expect(
            before.contains(InspectorAXTree.positionName("inspector.style.bodySize.medium")),
            "the first book's own body size must show"
        )
        store.selectedBookId = other.id
        let after = rendered.selectedPositions()
        #expect(
            after.contains(InspectorAXTree.positionName("inspector.style.bodySize.large")),
            "the second book's own body size must show after the selection changes"
        )
        #expect(
            before != after,
            "the page must follow the selection"
        )
    }

    /// The commands a book sets once are not on the page.
    @Test("the commands a book sets once are not on the page")
    func theCommandsABookSetsOnceAreNotOnThePage() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.formatPageSourceURL(),
            encoding: .utf8
        ))
        let styleCode = try InspectorAXTree.code(of: String(
            contentsOf: Self.stylePageSourceURL(),
            encoding: .utf8
        ))
        // The commands that are left are the three a novel uses inline.
        let dropped = EditorFormatAction.allCases.filter {
            $0 != .bold && $0 != .italic && $0 != .highlight
        }
        let offenders = dropped.filter { action in
            Self.names(action, in: code) || Self.names(action, in: styleCode)
        }
        #expect(
            offenders.isEmpty,
            "these commands are still on the page (= a book sets them once, = in its style sheet): \(offenders.map(\.rawValue))"
        )
    }

    /// Whether the code names the command (= `.heading` and = not
    /// `.headingSize`, = because the command's own name ends there).
    private static func names(_ action: EditorFormatAction, in code: String) -> Bool {
        code.range(of: "\\.\(action.rawValue)\\b", options: .regularExpression) != nil
    }

    /// THE RENDERED STYLE ROWS ARE HELD.
    ///
    /// The eleven rows are the page's other half, = and they are NOT
    /// in the accessibility tree (= a bare `Text` publishes nothing:
    /// = the reviewer measured `Text`, = `.accessibilityElement(children:
    /// .combine)` and = `.accessibilityElement(children: .ignore)` +
    /// `.accessibilityLabel`, = and none of them publishes; = only a
    /// `Menu` does, = which is why the knobs are observable and the
    /// rows are not). = So the rows are held by the page's own source,
    /// and the source is checked with TWO anchors:
    ///
    /// 1. = THE CALL SITE: = the page's body renders `stylesGroup`.
    ///    (= without it the page renders NO style rows at all, = and
    ///    the `ForEach` line is still in the file, = so the second
    ///    anchor alone would not catch it.)
    /// 2. = THE BINDING: = the rows come from `model.rows`.
    ///    (= without it the rendered rows read a sheet of their own
    ///    (= `.default`) = while the knobs read the selected book's, =
    ///    and the call site is still in the file, = so the first anchor
    ///    alone would not catch it.)
    ///
    /// One anchor is not enough: = both arms were measured, = and each
    /// one left the suite GREEN with only one anchor in place.
    @Test("the page renders the style rows, = and they come from the model's own rows")
    func thePageRendersTheStyleRows() throws {
        let code = try InspectorAXTree.code(of: String(
            contentsOf: Self.stylePageSourceURL(),
            encoding: .utf8
        ))
        #expect(
            code.contains("ForEach(Array(model.rows.enumerated())"),
            "the rendered rows must come from the model's own rows (= not a sheet of their own)"
        )
        #expect(
            code.contains("\n            stylesGroup\n"),
            "the page's body must render the style group (= not an empty view)"
        )
        //  The table comes LAST on the page (= see OOB.md #2026-11-19),
        //  = because it is the group a reader looks at after they have
        //  set the book, = and it is the long one.
        #expect(
            code.contains("tuningGroup\n            stylesGroup\n"),
            "the fine tuning must be rendered above the style table"
        )
    }

    /// Every role and knob name is in the catalog.
    @Test("every role, knob and position is in the catalog")
    func everyRoleKnobAndPositionIsInTheCatalog() throws {
        let catalog = try InspectorAXTree.catalog(at: Self.catalogURL())
        var missing: [String] = []
        for role in InspectorStyleRole.allCases {
            missing.append("inspector.style.role.\(role.rawValue)")
        }
        for key in [
            "inspector.style.group.styles",
            "inspector.style.group.tuning",
            "inspector.style.knob.bodySize",
            "inspector.style.knob.lineSpacing",
            "inspector.style.knob.firstLineIndent",
            "inspector.style.knob.segmentSpacing",
            "inspector.style.knob.bodyFamily",
            "inspector.style.bodySize.small",
            "inspector.style.bodySize.medium",
            "inspector.style.bodySize.large",
            "inspector.style.lineSpacing.tight",
            "inspector.style.lineSpacing.standard",
            "inspector.style.lineSpacing.loose",
            "inspector.style.firstLineIndent.none",
            "inspector.style.firstLineIndent.twoCharacters",
            "inspector.style.segmentSpacing.none",
            "inspector.style.segmentSpacing.halfCharacter",
            "inspector.style.family.songti",
            "inspector.style.family.heiti",
            "inspector.style.family.kai",
            "inspector.style.family.pingFang",
            "inspector.style.size",
            "inspector.style.leading",
            "inspector.style.unset",
            "inspector.style.preview.sample",
        ] {
            missing.append(key)
        }
        #expect(
            missing.filter { catalog[$0] == nil }.isEmpty,
            "these names are not in the catalog: \(missing.filter { catalog[$0] == nil })"
        )
    }

    // MARK: - The fixture

    /// The fixture, = the hosted page and = the reader that walks its view
    /// tree live in `InspectorStylePageFixture.swift` (= the suite passed
    /// the 600-line ceiling with them inside it = AGENTS.md 6.6). = The
    /// three calls below are the only door.
    private func makeStore() throws -> (BookStore, Book, Book) {
        try InspectorStylePageFixture.makeStore()
    }

    private func makeWorkspace() -> WorkspaceUIState {
        InspectorStylePageFixture.makeWorkspace()
    }

    private func renderPage(
        store: BookStore,
        workspace: WorkspaceUIState
    ) -> RenderedPage {
        InspectorStylePageFixture.renderPage(store: store, workspace: workspace)
    }


    /// The knob's own source file (= where its control is chosen).
    private static func knobSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorStyleKnobView.swift")
    }

    /// The format page's own source file (= where its rows are written).
    private static func formatPageSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorFormatPageView.swift")
    }

    /// The style page's own source file (= where its rows are written).
    private static func stylePageSourceURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Features/Editor/View/InspectorStylePageView.swift")
    }

    /// The string catalog (= where the names live).
    private static func catalogURL() -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
        return root
            .appendingPathComponent("Sources/WenshuApp/Resources/Localizable.xcstrings")
    }

}
