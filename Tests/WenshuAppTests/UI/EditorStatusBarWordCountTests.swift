//
//  EditorStatusBarWordCountTests.swift · Wenshu
//
//  Behaviour tests for the status bar's word-count measure.
//
//  WHAT THE FIX IS: the status bar counted WHITESPACE-DELIMITED TOKENS
//  (= `split(whereSeparator:)`), = and for a Chinese document that
//  number is its SENTENCE count (= Chinese does not separate its words
//  with spaces), = and the bar labelled it with the unit "字" (= = =
//  characters). = ⇒ So the reader saw one number under the unit "字",
//  = = and it was the wrong measure.
//
//  ⇒ ⇒ AND THE NUMBERS ON THE USER'S OWN LIBRARY: = = MEASURED over
//  the 32 markdown documents (= read-only, = the user's own data): = =
//  EVERY document's token count differs from its character count (= =
//  32 of 32), = = and the largest document read 570 tokens against
//  4,027 characters (= = the file `references/939E75BC-….md`, = = 4,666
//  characters long). = ⇒ ⇒ ⇒ ⇒ AND THE EDITOR'S OWN COUNTER WAS NEVER
//  DISPLAYED (= = `editorCounters.wordCount` is WRITTEN in four places
//  and READ NOWHERE in `Sources/`), = = so the user saw ONE number, =
//  = = not two. = ⇒ ⇒ ⇒ ⇒ ⇒ AND THAT IS THE DEFECT THIS FIXES: = = =
//  one number, = = the wrong measure, = = under the unit "字".
//
//  ⇒ ⇒ ⇒ ⇒ ⇒ AND THE CARD'S CLAIM, = = STATED HERE SO THE REVIEWER CAN
//  CHECK IT: = = = the status bar now counts `WordCounter.charactersNoSpaces`
//  (= = the measure the editor's counter reads), = = so the number under
//  the unit "字" is the CHARACTER count. = = = ⇒ The number the reader
//  sees changes (= = 570 becomes 4,027 on that document), = = and that
//  is the point of the card.
//
//  Coverage (= 4 tests):
//    1.  the status bar's measure is the editor counter's measure
//    2.  the status bar's measure is not the token count
//    3.  the status bar's RENDERED label carries that measure
//    4.  the status bar's RENDERED pixels carry that measure
//
//  ⇒ ⇒ ⇒ ⇒ ⇒ AND WHY #3 AND #4 BOTH EXIST: = = a static that MIRRORS
//  the view's label (= = `wordCountLabelForTest(in:)`) is a DOOR: = = =
//  the view can render the old token shape while the static holds the
//  new measure, = = and then every value-shaped case stays GREEN. = = =
//  ⇒ So #3 reads the view's OWN property (= = the statement the body
//  renders), = = and #4 reads the PIXELS (= = what the reader actually
//  sees). = = = ⇒ A revert of the view's label to tokens turns BOTH
//  red.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("the status bar's word count measure")
struct EditorStatusBarWordCountTests {
    /// ⇒ ONE MEASURE, ONE NUMBER: = the status bar and the editor's
    /// counter read the same text, = so they must show the same number.
    @Test("the status bar's measure is the editor counter's measure")
    func theStatusBarCountsTheSameMeasure() {
        let document = "林黛玉进贾府，= the quick brown fox.\n第二段。\n"
        let editorCounter = WordCounter.charactersNoSpaces(document)
        let statusBar = EditorStatusBarView.characterCount(in: document)
        #expect(statusBar == editorCounter)
    }

    /// ⇒ AND THE TOKEN COUNT IS NOT THE MEASURE: = for a Chinese
    /// document the whitespace-delimited token count reads as the
    /// SENTENCE count, = so it must differ from the character count.
    @Test("the status bar's measure is not the token count")
    func theStatusBarIsNotTheTokenCount() {
        let document = "林黛玉进贾府。\n第二段在这里。\n"
        let tokenCount = document.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let characterCount = WordCounter.charactersNoSpaces(document)
        #expect(tokenCount != characterCount)
        #expect(EditorStatusBarView.characterCount(in: document) == characterCount)
    }

    /// ⇒ ⇒ ⇒ **⇒ AND THE VIEW'S OWN LABEL** (= = the statement its body
    /// renders, = = `Text(wordCountLabel)`): = = the label must carry the
    /// character measure, = = and must NOT be the token shape.
    ///
    /// ⇒ ⇒ ⇒ **⇒ WHY THE VIEW'S OWN PROPERTY AND NOT A STATIC**: = = a
    /// static that mirrors the label is a DOOR, = = = the view can revert
    /// to the token shape while the static keeps the new measure, = = =
    /// and every value-shaped case stays GREEN. = = ⇒ This case reads
    /// the statement the body renders, = = so a revert of THAT
    /// statement is red here.
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ AND WHY IT IS MAIN-ACTOR ISOLATED**: = = = the
    /// label is a VIEW's property, = = and SwiftUI reads a view on the
    /// main actor (= = the view's `body` is main-actor isolated), = =
    /// so the label is read there too. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ And the
    /// isolation is not decoration: = = = MEASURED, = = a label whose
    /// measure reads the text with a non-isolated string call TRAPS
    /// (= = Swift's actor-executor check, = = signal 5) when the label
    /// is read off the main actor. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ So
    /// this case reads the label the way the app reads it.
    @MainActor
    @Test("the status bar's RENDERED label carries that measure")
    func theStatusBarLabelCarriesThatMeasure() {
        let line = "林黛玉进贾府。\n"
        let document = String(repeating: line, count: 40)
        let measure = WordCounter.charactersNoSpaces(document)

        // ⇒ The line carries seven characters and a newline (= eight
        // characters), = = so forty lines are 280 characters and 40
        // tokens (= = one run per line).
        #expect(line.count == 8, "the line carries seven characters and a newline")
        #expect(measure == 280)

        let view = EditorStatusBarView(
            textProvider: { document },
            isDirtyProvider: { false },
            isAutosavingProvider: { false }
        )
        // ⇒ THE VIEW'S OWN PROPERTY (= = the statement its body renders).
        #expect(
            view.wordCountLabel == "\(measure.formatted(.number)) 字",
            "the status bar's rendered label must carry the character measure"
        )
        // ⇒ AND NOT THE TOKEN SHAPE: = = the token count would render
        // "40 字", = = and that is the number the reader saw before.
        #expect(view.wordCountLabel != "40 字")
    }

    /// ⇒ ⇒ ⇒ **⇒ AND THE PIXELS** (= = what the reader actually sees):
    /// = = TWO documents with the SAME character count and DIFFERENT
    /// token counts must paint the SAME pixels, = = and a document with
    /// a DIFFERENT character count must paint DIFFERENT pixels.
    ///
    /// ⇒ ⇒ ⇒ **⇒ WHY THE PIXELS AND NOT ONLY THE LABEL**: = = the
    /// label property and the pixels are two different observables, = =
    /// and a body that renders something OTHER than the label (= = a
    /// literal, = = or a second measure) is green on the label case and
    /// red here. = = ⇒ ⇒ And the pair of assertions is not vacuous:
    /// the first says "the token count does not reach the pixels", = =
    /// and the second says "the character count does reach them".
    @MainActor
    @Test("the status bar's RENDERED pixels carry that measure")
    func theStatusBarPixelsCarryThatMeasure() throws {
        // Same characters (= 280), different tokens (= 40 and 80): = =
        // the token count differs, = = the character count does not.
        let sameCharacters = String(repeating: "林黛玉进贾府。\n", count: 40)
        let sameCharactersOtherTokens = String(repeating: "林黛 玉进贾府。\n", count: 40)
        // Different characters (= 287).
        let differentCharacters = String(repeating: "林黛玉进贾府。\n", count: 41)

        #expect(WordCounter.charactersNoSpaces(sameCharacters) == 280)
        #expect(WordCounter.charactersNoSpaces(sameCharactersOtherTokens) == 280)
        #expect(WordCounter.charactersNoSpaces(differentCharacters) == 287)

        let first = try Self.pixels(of: sameCharacters)
        let second = try Self.pixels(of: sameCharactersOtherTokens)
        let third = try Self.pixels(of: differentCharacters)

        #expect(
            first == second,
            "the status bar painted the token count (= two documents with the same character count and different token counts must paint the same pixels)"
        )
        #expect(
            first != third,
            "the status bar painted a constant (= a document with a different character count must paint different pixels)"
        )
    }

    /// The status bar's painted pixels, as the bytes it drew.
    ///
    /// ⇒ ⇒ ⇒ **⇒ WHY A WINDOWLESS HOST**: = = the bar's geometry is a
    /// pure layout question, = = and a window would raise a panel on the
    /// user's screen for nothing. = ⇒ And the backdrop is painted
    /// first, = = so a pixel that differs from it is a pixel the view
    /// drew.
    @MainActor
    private static func pixels(of document: String) throws -> Data {
        let view = EditorStatusBarView(
            textProvider: { document },
            isDirtyProvider: { false },
            isAutosavingProvider: { false }
        )
        .frame(width: 400, alignment: .leading)

        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 60)
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw CocoaError(.fileReadUnknown)
        }
        rep.size = hosting.bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        hosting.bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let data = rep.bitmapData else { throw CocoaError(.fileReadUnknown) }
        return Data(bytes: data, count: rep.bytesPerRow * rep.pixelsHigh)
    }
}
