//
//  InspectorStylePreviewVoiceTests.swift · Wenshu
//
//  What the style table shows in place of its numbers: = the face, = the
//  size and = the line height the ENGINE gives each role.
//
//  WHY THIS IS A SUITE OF ITS OWN
//
//  It reads a MODEL, = not a window: = the voice is a number, = and a
//  number is checked by arithmetic, = not by pixels (= a screenshot
//  cannot tell 16 pt from 16.4 pt, = nor a leading of 21 from one of
//  20). = The page's own suite renders a page and reads its
//  accessibility tree, = which is a different instrument on a different
//  layer, = and the two files together hold AGENTS.md 6.6's ceiling.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Inspector style table, in the engine's own voice", .serialized)
struct InspectorStylePreviewVoiceTests {
    /// Each row is shown in the voice the ENGINE gives that role, = not
    /// in the sheet's one multiple read eleven times.
    ///
    /// WHY THE NUMBERS ARE PINNED
    ///
    /// A preview is a drawing, = and a drawing cannot be told from a
    /// wrong one by looking at it: = 16 pt looks like 16 pt whether it
    /// came from the ladder or from a bug. = So what is pinned here is
    /// the arithmetic the preview publishes (= cited in
    /// `InspectorStylePreview`), = measured in this app's own process,
    /// = and the rule that makes a heading NOT a shrunken body.
    @Test("each row is shown in the voice the engine gives it")
    func eachRowIsShownInTheVoiceTheEngineGivesIt() throws {
        let sheet = BookStyleSheet(
            bodySize: .medium,
            lineSpacing: .standard,
            firstLineIndent: .twoCharacters,
            segmentSpacing: .none,
            bodyFamily: .songti,
            quoteFamily: .kai,
            headingLadder: .printStandard,
            headingFamily: .heiti
        )
        let model = InspectorStylePageModel(sheet: sheet)

        func shown(_ role: InspectorStyleRole) throws -> InspectorStylePreview {
            try #require(model.rows.first { $0.role == role }?.preview, "the \(role) row carries a voice")
        }

        //  The body: the sheet's own grid, = and the grid is the size
        //  times the multiple, = ROUNDED UP (= MarkdownASTStyler.swift:42-44).
        let body = try shown(.body)
        #expect(body.size == 13, "the body is the sheet's body size")
        #expect(body.lineHeight == 21, "the body runs on 13 × 1.55 rounded up (= not on 20.15)")
        #expect(body.extraLeading > 0, "the face's own height is shorter than the grid")

        //  A heading is NOT on that grid: = it takes its own face's
        //  height at its own size, rounded up, plus a point
        //  (= MarkdownASTStyler.swift:676-680). = A preview that read
        //  the book's multiple here would show 25 pt (= ceil(16 × 1.55)),
        //  = a leading the book never sets.
        let heading = try shown(.headingOne)
        #expect(heading.size == 16, "the heading's size comes from the ladder")
        #expect(heading.lineHeight == 18, "the heading takes its own face's height, not the book's grid")
        #expect(heading.faceName != body.faceName, "the heading is drawn in the heading's face")
        #expect(
            heading.faceName != NSFont(name: "Heiti SC", size: 16)?.fontName,
            "the bold a heading carries is the BOLD FACE's name, = not the family's (= a `.bold()` on top of that would double it)"
        )

        //  A quote keeps the grid PER POINT at its own size and adds its
        //  own extra (= MarkdownASTStyler.swift:913-917).
        let quote = try shown(.quote)
        #expect(quote.size == 12.5, "the quote is set at the sheet's quote size")
        #expect(
            abs(quote.lineHeight - 21 * (12.5 / 13)) < 0.01,
            "the quote's height is the body's grid read at the quote's size, = plus the quote's own extra, = which the mapped sheet leaves at 0 (= BlockquoteStyle.swift:611)"
        )

        //  A note and a caption: the same rule, = without the extra
        //  (= MarkdownASTStyler.swift:736-739).
        let note = try shown(.note)
        #expect(note.size == 11, "the note is set at the sheet's note size")
        #expect(
            abs(note.lineHeight - 21 * (11 / 13)) < 0.01,
            "a small role does not run on the body's grid (= its lines would fall apart)"
        )
        #expect(
            try shown(.figureCaption).lineHeight == note.lineHeight,
            "a caption takes the note's rule (= the same own-size paragraph style)"
        )

        //  A code block: the highlighter's face at 85 % of the body, on a
        //  whole-point height of its own (= MarkdownASTStyler.swift:49-51).
        //  The sheet names no face for it (= its cells hold a dash),
        //  = which is exactly why this row needs a voice and not words.
        let code = try shown(.monospace)
        #expect(code.size == 11, "the code is the body's 85 %, rounded")
        #expect(code.lineHeight == code.lineHeight.rounded(.up), "the code's height is whole points")
        #expect(code.faceName != body.faceName, "the code is not set in the book's prose face")

        //  A role the book sets in no type has no voice (= the picture,
        //  = the rule: = they show the dash and nothing else).
        #expect(model.rows.first { $0.role == .image }?.preview == nil, "a picture has no face to show")
        #expect(model.rows.first { $0.role == .rule }?.preview == nil, "a rule has no face to show")

        //  And every name a preview carries is a FACE the system can
        //  draw by that name (= `.font(.custom(_:size:))` reaches the
        //  face a name names, = and nothing else).
        for row in model.rows {
            guard let voice = row.preview else { continue }
            #expect(
                NSFont(name: voice.faceName, size: voice.size)?.fontName == voice.faceName,
                "the \(row.role.rawValue) row names a face that cannot be drawn: \(voice.faceName)"
            )
        }
    }

    /// The code faces the preview mirrors are the highlighter's own list.
    ///
    /// `InspectorStylePreview` cannot ASK the bridge for its font (= to
    /// construct the bridge is to read `NSApp`, = which a measured page
    /// does not have), = so it carries the list. = This is what stops the
    /// copy from going stale the day the engine's list moves.
    @Test("the preview's code faces are the highlighter's own list")
    func thePreviewsCodeFacesAreTheHighlightersOwnList() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // View
            .deletingLastPathComponent() // Editor
            .deletingLastPathComponent() // WenshuAppTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // the worktree's root
            .appendingPathComponent(
                "Vendor/MarkdownEngine/Sources/MarkdownEngineCodeBlocks/HighlighterSwiftBridge.swift"
            )
        let bridge = try InspectorAXTree.code(of: String(contentsOf: url, encoding: .utf8))
        let spelled = InspectorStylePreview.codeFaceNames
            .map { "\"" + $0 + "\"" }
            .joined(separator: ", ")
        #expect(
            bridge.contains(spelled),
            "the preview tries \(InspectorStylePreview.codeFaceNames), = which is not the list the bridge tries: \(spelled)"
        )
    }
}
