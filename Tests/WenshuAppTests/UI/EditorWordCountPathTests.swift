//
//  EditorWordCountPathTests.swift · Wenshu
//
//  Behaviour tests for the word-count fix the performance audit measured.
//
//  WHAT THE FIX IS: the editor's counter read
//  `WordCounter.count(content).charactersNoSpaces`, = and `count`
//  computes SIX fields, = so every keystroke paid for the LINGUISTIC
//  SEGMENTATION (= `enumerateSubstrings(.byWords)`) = and for two
//  regular expressions, = all of it serving fields that have no
//  production consumer.
//
//  ⇒ The production path now reads `WordCounter.charactersNoSpaces`,
//  = which counts the one field the app shows.
//
//  ⇒ AND THE STATUS BAR NOW COUNTS THE SAME MEASURE (= its own file,
//  = `EditorStatusBarWordCountTests.swift`): = it used to count
//  WHITESPACE-DELIMITED TOKENS, = so the same document showed two
//  different numbers under one unit (= 570 and 4,027 on the user's
//  largest real document), = and for a Chinese document the token count
//  is not a word count at all (= Chinese does not separate its words
//  with spaces, = so the token count reads as the sentence count).
//
//  Coverage (= 4 tests):
//    1.  the fast path's value is the full count's value
//    2.  the fast path agrees on the grapheme-cluster boundaries
//    3.  the fast path agrees on a document of the real size
//    4.  the fast path is materially cheaper than the full count
//    5.  the production path does not reach the full count
//
//  ⇒ The status bar's MEASURE has its own file
//  (= `EditorStatusBarWordCountTests.swift`), = because the registry's
//  merge driver keys a row on its SECOND column, = so one test file
//  carries one registry row.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("the editor's word count path")
struct EditorWordCountPathTests {
    // MARK: - The value is the same count

    /// The fast path's value must be the full count's value, = on every
    /// shape the app can hold.
    @Test("the fast path's value is the full count's value")
    func theValueIsTheSameCount() {
        let cases: [String] = [
            "",
            "   \t\n  ",
            "The quick brown fox",
            "林黛玉进贾府",
            "Hello 林黛玉 world",
            "a\tb\nc\r\nd  e",
            "First sentence. Second sentence! Third? 第四句。",
            "line one\nline two\n\nparagraph two",
            "emoji 😀 family 👨‍👩‍👧‍👦 flag 🇨🇳 here",
            "combining é cafe",
            "mixed 中文 with English and 数字 123",
        ]
        for text in cases {
            #expect(
                WordCounter.charactersNoSpaces(text) == WordCounter.count(text).charactersNoSpaces,
                "the fast path disagrees on \(text.debugDescription)"
            )
        }
    }

    /// ⇒ THE UNIT IS THE CHARACTER (= the grapheme cluster), = NOT the
    /// scalar. = ⇒ A scalar scan would read the emoji family as 7 and
    /// the combining sequence as 2, = so the case pins the boundaries
    /// the value has to keep.
    @Test("the fast path agrees on the grapheme-cluster boundaries")
    func theUnitIsTheCharacter() {
        // One emoji family (= several scalars, = one character).
        #expect(WordCounter.charactersNoSpaces("👨‍👩‍👧‍👦") == 1)
        // One combining sequence (= two scalars, = one character).
        #expect(WordCounter.charactersNoSpaces("e\u{0301}") == 1)
        // One regional-indicator flag (= two scalars, = one character).
        #expect(WordCounter.charactersNoSpaces("🇨🇳") == 1)
    }

    /// ⇒ AND ON A REAL-SHAPED DOCUMENT: = the repository's own largest
    /// document is 4,731 characters, = so the value has to survive a
    /// document of that size, = with the whitespace the app's markdown
    /// carries.
    @Test("the fast path agrees on a document of the real size")
    func theValueSurvivesADocumentOfTheRealSize() {
        let paragraph = "林黛玉进贾府，= the quick brown fox jumps over the lazy dog.\n"
        let document = String(repeating: paragraph, count: 100)
        #expect(document.count > 4000)
        #expect(
            WordCounter.charactersNoSpaces(document) == WordCounter.count(document).charactersNoSpaces
        )
    }

    // MARK: - The cost

    /// ⇒ THE COST CONTRACT: = the production path must not pay for
    /// the segmentation. = ⇒ The measurement is a RATIO (= the two
    /// shapes run in the same process, = so the machine's load moves
    /// both), = because a bare timing assertion flutters under load
    /// (= the first branch's audit measured that a load-sensitive
    /// timing assertion fails in a whole-suite run and passes alone).
    ///
    /// ⇒ MEASURED on the user's real library (= the largest document,
    /// 4,731 characters): = the full count 1,992.58us, = the fast path
    /// 137.63us (= 14.5x). = ⇒ The bar is 5x, = so the assertion holds
    /// with room for a busier machine.
    @Test("the fast path is materially cheaper than the full count")
    func theFastPathIsCheaper() {
        let paragraph = "林黛玉进贾府，= the quick brown fox jumps over the lazy dog.\n"
        let document = String(repeating: paragraph, count: 100)

        // Warm up (= the first call pays the Foundation caches).
        _ = WordCounter.count(document)
        _ = WordCounter.charactersNoSpaces(document)

        let fullStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< 20 {
            _ = WordCounter.count(document)
        }
        let fullCost = Double(DispatchTime.now().uptimeNanoseconds - fullStart) / 20.0

        let fastStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< 20 {
            _ = WordCounter.charactersNoSpaces(document)
        }
        let fastCost = Double(DispatchTime.now().uptimeNanoseconds - fastStart) / 20.0

        #expect(
            fullCost / max(fastCost, 1) >= 5,
            "the full count \(fullCost / 1000)us is not materially dearer than the fast path \(fastCost / 1000)us"
        )
    }

    // MARK: - The production path does not pay for the segmentation

    /// ⇒ ⇒ ⇒ **⇒ AND THE COST CASE ALONE CANNOT SEE THE PRODUCTION
    /// PATH.** = The cost case measures the two SHAPES, = so it stays
    /// green when a call site goes back to the dear shape (= the shape
    /// it measures did not change). = ⇒ MEASURED: putting
    /// `WordCounter.count(newValue).charactersNoSpaces` back at the
    /// keystroke call site left all six cases GREEN, = because the cost
    /// case compares two functions and neither of them is the call
    /// site.
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ SO THE CALL SITE IS ASSERTED, = = AND THE REPOSITORY
    /// ALREADY HAS THAT SHAPE** (= the design-system sweeps read the
    /// source through `SourceLocator.repoRoot` and assert what a file
    /// references). = ⇒ So the production path is pinned the same way:
    /// = the call sites that read the counter's value must NOT reach the
    /// full count.
    @Test("the production path does not reach the full count")
    func theProductionPathDoesNotReachTheFullCount() throws {
        let root = SourceLocator.repoRoot
        let sourcesRoot = root.appendingPathComponent("Sources/WenshuApp")

        let callSites: [(String, String)] = [
            ("Features/Editor/View/EditorEditContent.swift", "onWordCountChange(WordCounter.charactersNoSpaces("),
            ("Features/Editor/View/EditorView.swift", "editorCounters.wordCount = WordCounter.charactersNoSpaces("),
        ]

        for (relative, expectedCall) in callSites {
            let path = sourcesRoot.appendingPathComponent(relative)
            let content = try String(contentsOf: path, encoding: .utf8)
            #expect(
                content.contains(expectedCall),
                "\(relative) should read the counter through the fast path"
            )
            #expect(
                !content.contains("WordCounter.count("),
                "\(relative) still reaches the full count (= the segmentation is back on the keystroke path)"
            )
        }
    }
}
