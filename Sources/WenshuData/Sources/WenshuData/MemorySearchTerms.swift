//
//  MemorySearchTerms.swift
//
//  The terms of a memory query, and the score of a memory against them.
//
//  Why: the memory retrieval used to ask whether the WHOLE query
//  string was a literal substring of the memory. A question such as
//  "what did the third scene of this chapter say?" shares no
//  substring with the memory that holds the answer, so the retrieval
//  answered nothing every time, and the constraints never reached
//  the context. A query is a SET of terms, and a memory answers it
//  when it carries the terms.
//
//  The matcher lives in the data layer because the dependency runs the
//  other way (= the app's search layer cannot be reached from here),
//  and because the ranking has to be testable without the app.
//

import Foundation

/// The terms of a memory query.
///
/// A word weighs its length (= "tide" says more than "t") and a CJK
/// character weighs one (= CJK has no spaces between words, so the
/// characters are the words).
public struct MemorySearchTerms: Sendable {

    /// A term of the query, with the weight it carries.
    public struct Term: Sendable, Equatable {
        /// The term itself (= lowercase).
        public let text: String
        /// What the term is worth (= its length for a word, = one for
        /// a CJK character).
        public let weight: Double
    }

    /// The distinct terms of the query.
    public let terms: [Term]

    /// The weight of the whole query (= the denominator of a score).
    public let totalWeight: Double

    /// Build the terms of a query.
    public init(_ query: String) {
        var seen = Set<String>()
        var terms: [Term] = []
        var total: Double = 0
        for term in Self.tokenize(query) where seen.insert(term.text).inserted {
            terms.append(term)
            total += term.weight
        }
        self.terms = terms
        self.totalWeight = total
    }

    /// Whether the query holds no term at all (= a blank query, = a
    /// punctuation-only query).
    public var isEmpty: Bool { terms.isEmpty }

    /// The score of a memory against the query.
    ///
    /// 0 = the memory carries none of the terms; 1 = it carries all
    /// of them. The score ranks the memories; = the caller decides
    /// how many of them it wants.
    public func score(content: String) -> Double {
        guard totalWeight > 0 else { return 0 }
        let haystack = content.lowercased()
        var matched: Double = 0
        for term in terms where haystack.contains(term.text) {
            matched += term.weight
        }
        return matched / totalWeight
    }

    /// The terms of a text (= lowercase; = an ASCII word is one term,
    /// a CJK character is one term).
    static func tokenize(_ text: String) -> [Term] {
        var terms: [Term] = []
        var current = ""
        for scalar in text.lowercased().unicodeScalars {
            if isCJK(scalar) {
                // A CJK character ends the ASCII run before it.
                if !current.isEmpty {
                    terms.append(Term(text: current, weight: Double(current.count)))
                    current = ""
                }
                terms.append(Term(text: String(scalar), weight: 1))
            } else if isASCIILetterOrDigit(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                terms.append(Term(text: current, weight: Double(current.count)))
                current = ""
            }
        }
        if !current.isEmpty {
            terms.append(Term(text: current, weight: Double(current.count)))
        }
        return terms
    }

    /// An ASCII letter or digit (= the CJK ranges are handled first).
    private static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        guard scalar.value < 0x80 else { return false }
        let value = scalar.value
        if (value >= 0x41 && value <= 0x5A) || (value >= 0x61 && value <= 0x7A) { return true }
        return value >= 0x30 && value <= 0x39
    }

    /// The CJK ranges (= Unified Ideographs + Extension A +
    /// Compatibility Ideographs).
    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (value >= 0x4E00 && value <= 0x9FFF) ||
               (value >= 0x3400 && value <= 0x4DBF) ||
               (value >= 0xF900 && value <= 0xFAFF)
    }
}
