// SearchRanking.swift
//
// The app's own ranking: what a token is, and what a hit with it is
// worth. Extracted from `CSSearchableIndexSearch.swift` (= which is the
// index's write and query path, and does not need to grow every time a
// scoring signal is added).
//
// Two types, one concern:
//   - `MirrorRanking` = the ranking the app answers with when the system
//     index is unavailable or has not caught up, over the mirror's own
//     entries (= `SearchDocMirrorEntry`, written by the index's write path).
//   - `TokenOverlapRanking` = the tokenizer and the scorer both rows use:
//     a term's contribution saturates (= BM25's k1) instead of counting,
//     and a term is worth what it is rare for (= the caller's corpus
//     supplies the weights, because this type scores ONE document).
//
// **⇒ Both stay callable on purpose.** The retrieval-quality harness calls
// `MirrorRanking.rank` and `ReferenceLibrarySearch.search` rather than
// re-declaring them, so a change here moves the harness's table; a harness
// that copies the ranking measures a copy and not the app.

import Foundation

/// The mirror's own ranking (= the half the app answers with when the
/// system index is unavailable, or has not caught up with a document yet).
///
/// **⇒ It is a separate type (= and not a private method of the actor)
/// so the retrieval-quality harness can measure THIS ranking and not a
/// copy of it.** = A harness that re-declares the ranking measures
/// nothing: = a change to the code here leaves the harness's number
/// exactly where it was.
enum MirrorRanking {
    /// The mirror entry for one document (= the production tokenization).
    ///
    /// **⇒ The production tokenization lives HERE (= and not in the actor's
    /// write path) so the harness measures it and not a copy of it.**
    static func entry(docId: String, title: String, body: String) -> SearchDocMirrorEntry {
        SearchDocMirrorEntry(
            docId: docId,
            title: title,
            body: body,
            tokens: TokenOverlapRanking.tokenize(body + " " + title)
        )
    }

    /// Rank the mirror's entries against a query, best first.
    ///
    /// - Parameters:
    ///   - entries: The mirror's documents.
    ///   - query: What the user typed.
    ///   - limit: How many hits the caller wants.
    static func rank(
        entries: [SearchDocMirrorEntry],
        query: String,
        limit: Int
    ) -> [CSSearchResult] {
        let queryTokens = TokenOverlapRanking.tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        // **⇒ The rarity is weighed over the entries the caller handed in**
        // (= the mirror's own set = the documents the user is actually
        // searching). Saturation alone takes the count advantage away from a
        // term that sits in every document; the weight is what gives the rare
        // term back its say. The two are one rule, not two settings.
        let statistics = TokenOverlapRanking.corpusStatistics(
            documents: entries.map(\.tokens),
            queryTokens: queryTokens
        )

        var scored: [(docId: String, snippet: String, rank: Double)] = []
        for entry in entries {
            let score = TokenOverlapRanking.score(
                queryTokens: queryTokens,
                docTokens: entry.tokens,
                statistics: statistics
            )
            if score > 0 {
                let snippet = TokenOverlapRanking.highlight(
                    queryTokens: queryTokens,
                    body: entry.body,
                    contextChars: 32
                )
                scored.append((docId: entry.docId, snippet: snippet, rank: score))
            }
        }
        // Two documents of the same score sort by their id (= the mirror's
        // own order is a dictionary's, = so without this the same query
        // could answer in two different orders).
        scored.sort { lhs, rhs in
            if lhs.rank != rhs.rank {
                return lhs.rank > rhs.rank
            }
            return lhs.docId < rhs.docId
        }
        return scored.prefix(limit).map {
            CSSearchResult(docId: $0.docId, snippet: $0.snippet, rank: $0.rank, line: -1)
        }
    }
}

/// Token-overlap ranking for fallback (= not BM25, = simpler but adequate).
enum TokenOverlapRanking {
    /// Tokenize text (= lowercase + split on non-alphanumeric + CJK char-by-char).
    /// product: `NLTokenizer` would be richer; = keep Foundation-only to avoid dep.
    ///
    /// CJK strategy: U+4E00..U+9FFF + extension ranges emit one token per character
    /// (= CJK has no spaces between words). ASCII words are kept as letter-runs.
    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        let digits = CharacterSet.decimalDigits
        for scalar in text.lowercased().unicodeScalars {
            // CJK first (= per-char tokens); then ASCII letter-run.
            if isCJKScalar(scalar) {
                // Flush any pending ASCII run before emitting CJK token.
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(scalar))
            } else if isASCIILetterOrDigit(scalar, digits: digits) {
                current.unicodeScalars.append(scalar)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    /// ASCII letter or digit check (= exclude CJK which is also "letter" per Unicode).
    private static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar, digits: CharacterSet) -> Bool {
        guard scalar.value < 0x80 else { return false }
        // ASCII letter range = U+0041..U+005A (upper) + U+0061..U+007A (lower).
        let v = scalar.value
        if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) {
            return true
        }
        return digits.contains(scalar)
    }

    /// CJK Unified Ideographs block (= U+4E00..U+9FFF) + extension A (= U+3400..U+4DBF).
    /// product: NLTokenizer.hebrew / .japanese use different per-language ranges;
    /// = wenshu's primary authoring language is zh-Hans per AGENTS.md baseline.
    private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
            (v >= 0x3400 && v <= 0x4DBF) ||
            (v >= 0xF900 && v <= 0xFAFF) // CJK Compatibility Ideographs
    }

    /// What the corpus says about the terms a query asked for, and about the
    /// size of the documents it holds.
    ///
    /// **⇒ BM25's term-frequency term has TWO parts, and a ranking that
    /// implements only one of them is capping, not saturating.** The rarity
    /// of the term (the weight) and the length of the document that holds it
    /// (the norm): a document ten times the size of the others had ten times
    /// the chance to mention the term, and that is not evidence of relevance.
    struct CorpusStatistics {
        let weights: [String: Double]
        let averageLength: Double

        /// No rarity and no length normalisation (= the shape for the tests
        /// that ask about the overlap contract itself, over one document).
        static let unweighted = CorpusStatistics(weights: [:], averageLength: 0)
    }

    /// Score doc against query tokens (= token overlap, = where each term's
    /// contribution is weighed by how rare it is in the corpus and by how
    /// long this document is next to it).
    ///
    /// The statistics come from the caller's corpus (= this type scores ONE
    /// document and has none): `corpusStatistics` builds them.
    static func score(
        queryTokens: [String],
        docTokens: [String],
        statistics: CorpusStatistics = .unweighted
    ) -> Double {
        guard !queryTokens.isEmpty, !docTokens.isEmpty else { return 0 }
        let queryTerms = Set(queryTokens).sorted()
        let docCounts = Dictionary(grouping: docTokens, by: { $0 }).mapValues(\.count)
        var hits = 0.0
        var totalWeight = 0.0
        for qt in queryTerms {
            let weight = statistics.weights[qt] ?? 1
            totalWeight += weight
            if let count = docCounts[qt] {
                hits += weight * termContribution(
                    occurrences: count,
                    docLength: Double(docTokens.count),
                    averageLength: statistics.averageLength
                )
            }
        }
        // Normalize by the query's total weight (= longer queries are less
        // specific, = and a rare term counts for more than a common one).
        guard totalWeight > 0 else { return 0 }
        return hits / totalWeight
    }

    /// One term's contribution to a document's score (= BM25's tf term).
    ///
    /// **⇒ THE CONTRIBUTION SATURATES.** A term seen once is worth seeing,
    /// and seeing it nine more times adds a little; the length term says a
    /// document twice the size of the corpus's average had twice the chance to
    /// see the term at all. The two halves are needed together: saturation
    /// alone leaves a long document that lists many of the query's terms
    /// unpaid for its size, and `lengthNormalisation` pins that half.
    ///
    /// With `averageLength` 0 there is no corpus to compare against and the
    /// document is taken at its own size (`norm` = 1).
    static func termContribution(
        occurrences: Int,
        docLength: Double,
        averageLength: Double
    ) -> Double {
        let k1 = 1.2
        let b = 0.75
        let f = Double(occurrences)
        let norm = averageLength > 0 ? 1 - b + b * (docLength / averageLength) : 1
        return (f * (k1 + 1)) / (f + k1 * norm)
    }

    /// How rare each of the query's terms is in the corpus, and how long its
    /// documents are on average (= the statistics `score` needs).
    ///
    /// - Parameters:
    ///   - documents: Each document's tokens.
    ///   - queryTokens: The question's tokens (= only these get a weight).
    static func corpusStatistics(
        documents: [[String]],
        queryTokens: [String]
    ) -> CorpusStatistics {
        let n = Double(documents.count)
        guard n > 0 else { return .unweighted }

        var documentFrequency: [String: Int] = [:]
        let wanted = Set(queryTokens)
        for document in documents {
            for token in Set(document) where wanted.contains(token) {
                documentFrequency[token, default: 0] += 1
            }
        }
        var weights: [String: Double] = [:]
        for token in wanted {
            let df = Double(documentFrequency[token] ?? 0)
            weights[token] = log((n + 1) / (df + 1)) + 1
        }
        let total = documents.reduce(0) { $0 + $1.count }
        return CorpusStatistics(weights: weights, averageLength: Double(total) / n)
    }

    /// The average number of tokens per document (= what the length
    /// normalisation divides by).
    ///
    /// **⇒ A FIELD'S AVERAGE IS NOT THE DOCUMENT'S AVERAGE.** = = A title is
    /// a handful of tokens and a body is hundreds, so normalising the title's
    /// term against the whole document's length would read "this title is
    /// unusually short" as evidence and inflate every title. Each field is
    /// measured against the same field across the corpus.
    static func averageLength(of documents: [[String]]) -> Double {
        guard !documents.isEmpty else { return 0 }
        return Double(documents.reduce(0) { $0 + $1.count }) / Double(documents.count)
    }

    /// Build a snippet with `<mark>`-wrapped query token matches (= + context chars).
    static func highlight(queryTokens: [String], body: String, contextChars: Int) -> String {
        guard !queryTokens.isEmpty else { return String(body.prefix(contextChars * 2)) }
        let lower = body.lowercased()
        for token in Set(queryTokens) {
            if let range = lower.range(of: token) {
                let start = lower.index(range.lowerBound, offsetBy: -contextChars, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: contextChars, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(body[start ..< end])
                return "<mark>\(token)</mark> \(snippet)"
            }
        }
        return String(body.prefix(contextChars * 2))
    }
}
