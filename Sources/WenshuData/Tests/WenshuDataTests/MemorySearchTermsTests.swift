//
//  MemorySearchTermsTests.swift · Wenshu
//
//  The terms of a memory query (= the matcher that replaced the
//  whole-query substring test).
//

import Foundation
import Testing
import WenshuData

@Suite("MemorySearchTerms (= the memory query matcher)")
struct MemorySearchTermsTests {

    @Test("an ASCII word is one term, and it weighs its length")
    func asciiWords() {
        let terms = MemorySearchTerms("tide gauge")
        #expect(terms.terms.count == 2)
        #expect(terms.totalWeight == 9)   // (= 4 + 5)
    }

    @Test("a CJK character is one term")
    func cjkCharacters() {
        // The characters are written as code points so this file
        // stays English-only (= the repo's rule); = the test still
        // runs the CJK path of the matcher.
        let cjk = String(String.UnicodeScalarView([0x7B2C, 0x4E09, 0x5E55].map { Unicode.Scalar($0)! }))
        let terms = MemorySearchTerms(cjk)
        #expect(terms.terms.count == 3)
        #expect(terms.totalWeight == 3)
    }

    @Test("a blank query holds no term")
    func blankQuery() {
        #expect(MemorySearchTerms("").isEmpty)
        #expect(MemorySearchTerms("   ").isEmpty)
        #expect(MemorySearchTerms("!!!").isEmpty)
    }

    @Test("a memory that carries every term scores 1")
    func fullScore() {
        let terms = MemorySearchTerms("tide gauge")
        #expect(terms.score(content: "The tide gauge was read at dawn.") == 1)
    }

    @Test("a memory that carries one term of two scores the share it carries")
    func halfScore() {
        let terms = MemorySearchTerms("tide gauge")
        // The score is the share of the query's WEIGHT the memory
        // carries (= a word weighs its length; = "tide" is 4 of the
        // 9 the two words weigh).
        #expect(terms.score(content: "The tide was high.") == 4.0 / 9.0)
    }

    @Test("a memory that carries no term scores 0")
    func noScore() {
        let terms = MemorySearchTerms("tide gauge")
        #expect(terms.score(content: "A quiet morning in the harbor.") == 0)
    }

    @Test("the score ignores the case of the memory")
    func caseInsensitive() {
        let terms = MemorySearchTerms("Harbor")
        #expect(terms.score(content: "the HARBOR at dawn") == 1)
    }

    @Test("a repeated term counts once")
    func repeatedTerm() {
        let terms = MemorySearchTerms("tide tide tide")
        #expect(terms.terms.count == 1)
        #expect(terms.totalWeight == 4)
    }
}
