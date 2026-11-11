//
//  EditorStatusBarWordCountTests.swift · Wenshu
//
//  Behaviour tests for the status bar's word-count measure.
//
//  WHAT THE FIX IS: the status bar counted WHITESPACE-DELIMITED TOKENS
//  (= `split(whereSeparator:)`), = while the editor's counter counted
//  characters, = so the same document showed two different numbers under
//  one unit (= 570 and 4,027 on the user's largest real document), = and
//  for a Chinese document the token count is not a word count at all
//  (= Chinese does not separate its words with spaces, = so the token
//  count reads as the sentence count).
//
//  ⇒ The status bar now counts the SAME MEASURE the editor's counter
//  shows, = and it reads the same text, = so ONE MEASURE, ONE NUMBER.
//
//  Coverage (= 3 tests):
//    1.  the status bar's measure is the editor counter's measure
//    2.  the status bar's measure is not the token count
//    3.  the status bar's label carries that measure
//

import Foundation
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

    /// ⇒ AND THE LABEL CARRIES THAT MEASURE: = the label's number is the
    /// measure, = so a label built from a Chinese document reads the
    /// character count and not the token count. = ⇒ The label's own
    /// formatting (= the Apple HIG comma separator) is untouched.
    @Test("the status bar's label carries that measure")
    func theStatusBarLabelCarriesThatMeasure() {
        let line = "林黛玉进贾府。\n"
        let document = String(repeating: line, count: 40)
        let measure = EditorStatusBarView.characterCount(in: document)
        let label = EditorStatusBarView.wordCountLabelForTest(in: document)
        #expect(label == "\(measure.formatted(.number)) 字")
        // ⇒ The token count would be 40 (= one run per line), = and the
        // character count is the line's own characters (= 7) times the
        // lines (= 280).
        #expect(line.count == 8, "the line carries seven characters and a newline")
        #expect(measure == 280)
        #expect(label != "40 字")
    }
}
