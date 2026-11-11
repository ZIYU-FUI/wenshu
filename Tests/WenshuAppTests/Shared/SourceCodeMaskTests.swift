//
//  SourceCodeMaskTests.swift · WenshuAppTests
//
//  Behaviour tests for the masker the word-count reader reads the
//  production tree with.
//
//  WHAT THE MASK DOES: = = it blanks every comment and every string
//  literal's contents, = = and keeps everything else (= = the CODE),
//  = = so a reader that scans the tree for a call is pointed at code
//  and at nothing else.
//
//  ⇒ ⇒ AND THE MASK IS THE READER'S FOUNDATION: = = a phrase in a
//  comment, = = in a block comment, = = or in a string literal is not
//  code, = = and a reader that reads it as code can be pointed at the
//  wrong branch.
//
//  ⇒ ⇒ ⇒ **⇒ AND IT IS ONE PASS, = = = so the two cannot swallow each
//  other:** = = = a `//` inside a string literal is not a comment, = =
//  = = and a quote inside a comment is not the start of a literal.
//
//  ⇒ ⇒ ⇒ **⇒ ⇒ AND AN INTERPOLATION IS CODE:** = = = the `\(...)`
//  = = = inside a string literal is an EXPRESSION, = = = so it stays
//  = = = (= = = a call inside an interpolation is a call).
//
//  Coverage (= 8 tests):
//    1.  a comment is blanked
//    2.  a string literal's contents are blanked
//    3.  a raw string literal's contents are blanked
//    4.  a multi-line string literal's contents are blanked
//    5.  an interpolation's expression survives
//    6.  a `//` inside a string literal is not a comment
//    7.  a quote inside a comment is not a literal
//    8.  the line count is kept
//

import Foundation
import Testing

@Suite("the source masker")
struct SourceCodeMaskTests {
    /// ⇒ A COMMENT IS NOT CODE: = = the reader must not see a call that
    /// = = lives in one.
    @Test("a comment is blanked")
    func aCommentIsBlanked() {
        let masked = SourceCodeMask.code(of: """
        let kept = 1
        // let hidden = WordCounter.count(text)
        let alsoKept = 2
        """)
        #expect(masked.contains("let kept = 1"))
        #expect(masked.contains("let alsoKept = 2"))
        #expect(!masked.contains("WordCounter"))
        #expect(!masked.contains("hidden"))
    }

    /// ⇒ ⇒ A BLOCK COMMENT IS NOT CODE EITHER: = = and the code after
    /// = = it survives (= = = the block ends where it ends).
    @Test("a block comment is blanked")
    func aBlockCommentIsBlanked() {
        let masked = SourceCodeMask.code(of: """
        /* let hidden = WordCounter.count(text) */
        let kept = 1
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
    }

    /// ⇒ ⇒ ⇒ A STRING LITERAL'S CONTENTS ARE NOT CODE: = = = so a
    /// = = = reader is not pointed at a call that only appears as
    /// = = = TEXT (= = = a documentation string, = = = a log line).
    @Test("a string literal's contents are blanked")
    func aStringLiteralsContentsAreBlanked() {
        let masked = SourceCodeMask.code(of: """
        let kept = 1
        let text = "WordCounter.count(content)"
        let alsoKept = 2
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
        #expect(masked.contains("let alsoKept = 2"))
    }

    /// ⇒ ⇒ ⇒ AND A RAW STRING LITERAL: = = = its `#`s are part of its
    /// = = = delimiter, = = = so the reader must see the closer and not
    /// = = = run past it.
    @Test("a raw string literal's contents are blanked")
    func aRawStringLiteralsContentsAreBlanked() {
        let masked = SourceCodeMask.code(of: """
        let kept = 1
        let pattern = #"WordCounter\\.count"#
        let alsoKept = 2
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
        #expect(masked.contains("let alsoKept = 2"))
    }

    /// ⇒ ⇒ ⇒ AND A MULTI-LINE STRING LITERAL: = = = its body runs
    /// = = = across lines, = = = so the reader must blank every line
    /// = = = of it.
    @Test("a multi-line string literal's contents are blanked")
    func aMultiLineStringLiteralsContentsAreBlanked() {
        let masked = SourceCodeMask.code(of: """
        let kept = 1
        let text = \"\"\"
        WordCounter.count(content)
        \"\"\"
        let alsoKept = 2
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
        #expect(masked.contains("let alsoKept = 2"))
    }

    /// ⇒ ⇒ ⇒ ⇒ AND AN INTERPOLATION IS CODE: = = = the expression
    /// = = = inside it stays, = = = because a call inside an
    /// = = = interpolation is a call.
    @Test("an interpolation's expression survives")
    func anInterpolationsExpressionSurvives() {
        let masked = SourceCodeMask.code(of: """
        let text = "count: \\(WordCounter.count(content))"
        """)
        #expect(masked.contains("WordCounter.count"))
    }

    /// ⇒ ⇒ ⇒ ⇒ ⇒ AND THE TWO CANNOT SWALLOW EACH OTHER: = = = a `//`
    /// = = = inside a string literal is not a comment, = = = so the
    /// = = = code after the literal survives.
    @Test("a `//` inside a string literal is not a comment")
    func aSlashSlashInsideAStringIsNotAComment() {
        let masked = SourceCodeMask.code(of: """
        let text = "http://example.com/WordCounter.count"
        let kept = 1
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
    }

    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ AND A QUOTE INSIDE A COMMENT IS NOT A LITERAL:
    /// = = = so the code after the comment survives.
    @Test("a quote inside a comment is not a literal")
    func aQuoteInsideACommentIsNotALiteral() {
        let masked = SourceCodeMask.code(of: """
        // a "quoted" phrase with WordCounter.count inside
        let kept = 1
        """)
        #expect(!masked.contains("WordCounter"))
        #expect(masked.contains("let kept = 1"))
    }

    /// ⇒ ⇒ AND THE LINE COUNT IS KEPT: = = = a reader that reports
    /// ⇒ ⇒ ⇒ WHERE a call is needs the lines to mean the same thing
    /// ⇒ ⇒ ⇒ ⇒ after masking.
    @Test("the line count is kept")
    func theLineCountIsKept() {
        let source = """
        let a = 1
        // a comment
        let b = "a string"
        let c = 3
        """
        let masked = SourceCodeMask.code(of: source)
        #expect(masked.components(separatedBy: "\n").count == source.components(separatedBy: "\n").count)
    }
}
