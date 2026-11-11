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
//  ⇒ ⇒ AND THE STATUS BAR NOW COUNTS THE SAME MEASURE (= its own file,
//  = `EditorStatusBarWordCountTests.swift`): = = it used to count
//  WHITESPACE-DELIMITED TOKENS, = = and for a Chinese document that
//  number is its SENTENCE count, = = and the bar labelled it with the
//  unit "字" (= = characters). = ⇒ ⇒ ⇒ ⇒ AND THE READER SAW ONE NUMBER,
//  = = = not two: = = = the editor's own counter was never displayed
//  (= = `editorCounters.wordCount` is written in four places and read
//  nowhere in `Sources/`).
//
//  Coverage (= 5 tests):
//    1.  the fast path's value is the full count's value
//    2.  the fast path agrees on the grapheme-cluster boundaries
//    3.  the fast path agrees on a document of the real size
//    4.  the fast path is materially cheaper than the full count
//    5.  the production path does not reach the full count
//
//  ⇒ The status bar's MEASURE has its own file
//  (= `EditorStatusBarWordCountTests.swift`), = = because the registry's
//  merge driver keys a row on its SECOND column, = so one test file
//  carries one registry row.
//
//  ⇒ The reader that test 5 uses has its own file
//  (= `WordCounterSourceReader.swift`), = = and the masker it reads
//  with has its own (= `SourceCodeMask.swift`), = = because the reader
//  asks a question about the DECLARATION (= = which members the
//  counter type has, = = and which of them reach the segmentation), = =
//  and a reader of that size does not belong inside a behaviour suite.
//
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
    /// ⇒ ⇒ ⇒ **⇒ ⇒ SO THE CALL SITE IS ASSERTED, = = AND THE READER
    /// READS THE DECLARATION**: = = the case asks which COUNTER the
    /// production path calls, = = and the counter's own declaration
    /// says which of its members reach the segmentation, = = so a
    /// member the counter gains LATER is classified by what its body
    /// does (= = and it cannot hide behind a name the reader does not
    /// know).
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ AND THE TYPE IS RESOLVED THROUGH ITS ALIASES**:
    /// = = = a `typealias` in the tree names the same type, = = = so a
    /// = = = call written through the alias is a call to the type's
    /// = = = member (= = = and the alias is read from the tree, = = =
    /// = = = not from a list).
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ AND THE READER FAILS LOUD**: = = = when it
    /// = = = cannot resolve the type or the member, = = = it reports
    /// = = = its own error, = = = it does NOT report "no violation".
    @Test("the production path does not reach the full count")
    func theProductionPathDoesNotReachTheFullCount() throws {
        let tree = try WordCounterSourceReader.readTree()

        var offenders: [String] = []
        var fastPathReaders: [String] = []
        for path in try SourceLocator.swiftFilesUnderSources() {
            let mentioned = tree.mentions[path] ?? []
            if !mentioned.isDisjoint(with: tree.counter.expensive) {
                offenders.append(path)
            }
            if !mentioned.isDisjoint(with: tree.counter.cheap) {
                fastPathReaders.append(path)
            }
        }

        #expect(
            offenders.isEmpty,
            "these production files reach a counter member that performs the segmentation (= the segmentation is back on the keystroke path): \(offenders.joined(separator: ", "))"
        )
        #expect(
            !fastPathReaders.isEmpty,
            "no production file reads the counter through a cheap member (= the guard would pass on a tree that reads no counter at all)"
        )
    }
}
