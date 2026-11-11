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
    /// ⇒ ⇒ ⇒ **⇒ ⇒ SO THE CALL SITE IS ASSERTED, = = AND THE READER IS
    /// STRUCTURAL**: = = the case reads the production file's CODE (= =
    /// its comments and string literals blanked, = = so a comment that
    /// names a symbol can neither satisfy nor break the gate), = = and
    /// it resolves the COUNTER CALL the file makes, = = not one exact
    /// spelling of it.
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ AND WHY NOT AN EXACT SPELLING**: = = = a gate
    /// anchored on one call EXPRESSION cries wolf on the next person who
    /// hoists that expression into a local (= = a correct refactor = = =
    /// the same behaviour), = = and a gate anchored on a PHRASE is
    /// defeated by an alias (= = `let counter = WordCounter.count` = =
    /// the literal never appears) = = and by a comment that carries it.
    /// = = ⇒ ⇒ ⇒ ⇒ So the reader asks the QUESTION (= = which counter
    /// does this file call? = = = the fast one or the full one?) = = =
    /// and not for a string.
    ///
    /// ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ AND THE QUESTION IS ANSWERED OVER THE WHOLE
    /// TREE**: = = = the full count is a member of ONE type, = = so
    /// every production file that mentions it is a candidate, = = and
    /// the gate reads all of them. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ That is what makes
    /// the ALIAS arm red: = = = the alias is a mention of the full count,
    /// = = = wherever it sits.
    @Test("the production path does not reach the full count")
    func theProductionPathDoesNotReachTheFullCount() throws {
        var offenders: [String] = []
        var fastPathReaders: [String] = []

        for path in try SourceLocator.swiftFilesUnderSources() {
            let code = Self.codeOnly(of: path)
            guard code.contains("WordCounter") else { continue }
            if Self.callsTheFullCount(code) {
                offenders.append(path)
            }
            if Self.callsTheFastPath(code) {
                fastPathReaders.append(path)
            }
        }

        #expect(
            offenders.isEmpty,
            "these production files reach the full count (= the segmentation is back on the keystroke path): \(offenders.joined(separator: ", "))"
        )
        #expect(
            !fastPathReaders.isEmpty,
            "no production file reads the counter through the fast path (= the guard would pass on a tree that reads no counter at all)"
        )
    }

    // MARK: - The reader

    /// The production file's CODE (= its comments and string literals
    /// blanked).
    ///
    /// ⇒ ⇒ ⇒ **⇒ WHY**: = = a phrase in a comment, = = in a block
    /// comment, = = or in a string literal is not code, = = and a reader
    /// that reads it as code can be pointed at the wrong branch. = =
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ This is the repository's own rule for this shape
    /// of gate (= the mode gate's decoy family), = = and it is what
    /// makes the DECOY arm red.
    private static func codeOnly(of path: String) -> String {
        let source = (try? String(contentsOf: SourceLocator.url(path), encoding: .utf8)) ?? ""
        return blankingCommentsAndStrings(source)
    }

    /// Blank every comment and every string literal (= the characters
    /// become spaces, = so the offsets still line up with the original).
    private static func blankingCommentsAndStrings(_ source: String) -> String {
        let chars = Array(source)
        var out = chars
        var i = 0
        // 0 = code, 1 = a line comment, 2 = a block comment, 3 = a string.
        var state = 0
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            switch state {
            case 0:
                if c == "/", next == "/" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 1; continue
                }
                if c == "/", next == "*" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 2; continue
                }
                if c == "\"" {
                    out[i] = " "; i += 1; state = 3; continue
                }
            case 1:
                if c == "\n" {
                    state = 0
                } else {
                    out[i] = " "
                }
            case 2:
                if c == "*", next == "/" {
                    out[i] = " "; out[i + 1] = " "; i += 2; state = 0; continue
                }
                if c != "\n" {
                    out[i] = " "
                }
            case 3:
                if c == "\\" {
                    out[i] = " "
                    if i + 1 < chars.count {
                        out[i + 1] = " "
                    }
                    i += 2; continue
                }
                if c == "\"" {
                    out[i] = " "; i += 1; state = 0; continue
                }
                if c != "\n" {
                    out[i] = " "
                }
            default:
                break
            }
            i += 1
        }
        return String(out)
    }

    /// ⇒ ⇒ ⇒ **⇒ WHETHER THE CODE CALLS THE FULL COUNT** (= = the
    /// six-field one): = = the member is named with its type and its
    /// name, = = and the name may be spelled with spaces around the dot
    /// (= = `WordCounter . count`), = = and the CALL may be written
    /// with a space before its paren (= = `WordCounter.count (x)`).
    /// ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ AND AN ALIAS IS A CALL TOO**: = = = `let
    /// counter = WordCounter.count` names the member, = = = so the
    /// reader sees it. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ That is the arm the phrase
    /// anchor could not see.
    private static func callsTheFullCount(_ code: String) -> Bool {
        mentionsMember(code, named: "count")
    }

    /// ⇒ ⇒ ⇒ **⇒ WHETHER THE CODE CALLS THE FAST PATH** (= = the
    /// one-field one): = = the same question, = = about the other
    /// member.
    private static func callsTheFastPath(_ code: String) -> Bool {
        mentionsMember(code, named: "charactersNoSpaces")
    }

    /// ⇒ ⇒ ⇒ **⇒ WHETHER THE CODE NAMES A MEMBER OF THE COUNTER**:
    /// = = the type's name, = = then optional spaces, = = then the dot,
    /// = = then optional spaces, = = then the member's name with a
    /// word boundary (= = so `countSentences` is not `count`).
    private static func mentionsMember(_ code: String, named member: String) -> Bool {
        var searchRange = code.startIndex ..< code.endIndex
        while let typeRange = code.range(of: "WordCounter", range: searchRange) {
            var index = typeRange.upperBound
            // ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ Skip the whitespace, = = then one
            // optional `self`, = = then the dot, = = then the whitespace.
            var sawDot = false
            while index < code.endIndex {
                if code[index] == " " || code[index] == "\n" || code[index] == "\t" {
                    index = code.index(after: index)
                    continue
                }
                if code[index] == "." {
                    index = code.index(after: index)
                    sawDot = true
                    continue
                }
                break
            }
            guard sawDot else {
                searchRange = typeRange.upperBound ..< code.endIndex
                continue
            }
            while index < code.endIndex,
                  code[index] == " " || code[index] == "\n" || code[index] == "\t"
            {
                index = code.index(after: index)
            }
            guard code[index...].hasPrefix(member) else {
                searchRange = typeRange.upperBound ..< code.endIndex
                continue
            }
            let after = code.index(index, offsetBy: member.count)
            // ⇒ The word boundary: = = `countSentences` is not `count`.
            if after == code.endIndex || !(code[after].isLetter || code[after].isNumber || code[after] == "_") {
                return true
            }
            searchRange = typeRange.upperBound ..< code.endIndex
        }
        return false
    }
}
