//
// RetrievalQualityRankers.swift · Wenshu · the rankers the harness measures
//
// The harness's own machinery: the seven rankers it compares, the corpus
// model it builds over the fixture, and the tokenizations those rankers
// use.
//
// **⇒ THE TWO PRODUCTION ROWS CALL THE APP'S OWN SEARCH** (= =
// `ReferenceLibrarySearch.search` and `MirrorRanking.rank`), = so a change
// to the app's ranking moves the harness's table. = A row that re-declared
// the ranking would measure nothing.
//
// The assertions live in `RetrievalQualityTests.swift`; = the fixture lives
// in `RetrievalQualityCorpus.swift`.
//

import Foundation
import NaturalLanguage
@testable import WenshuApp

// MARK: - The rankers

/// One ranker's result over the fixture.
struct RankerResult: Sendable {
    let name: String
    let recallAt1: Double
    let recallAt3: Double
    let recallAt5: Double
    let bridgeAt1: Double
    let bridgeAt3: Double
}

/// The seven rankers, measured over the same corpus.
struct RankerTable {
    /// The production search the library's own view runs.
    static let libraryName = "wenshu-library"
    /// The production search the mirror falls back to.
    static let mirrorName = "wenshu-mirror"
    static let characterName = "bm25-character"
    static let bigramName = "bm25-bigram"
    static let appleWordName = "bm25-apple-word"
    static let bigramWithTitleName = "bm25-bigram+title"
    static let expanderName = "bm25-apple-word+expander"

    /// The production library search's recorded recall (= the gate a change
    /// to the library's ranking must not cross).
    ///
    /// **⇒ The floor is the number the app's own function produced on this
    /// corpus (= 0.75, = and not the 0.67 a copy of the ranking gave: = the
    /// copy's tie order was the copy's own, = and a tie is exactly where a
    /// ranking's copy stops measuring the ranking).**
    /// **⇒ THE FLOORS ARE FRACTIONS OF THE FIXTURE'S TWELVE QUESTIONS**
    /// (= = and not the rounded numbers the table prints: = = 11 of 12 is
    /// 0.9166..., = = and a floor of 0.92 would sit ABOVE it and fail a
    /// ranking that did not move).
    static let libraryBaselineRecallAt1 = 9.0 / 12.0
    static let libraryBaselineRecallAt3 = 10.0 / 12.0
    static let libraryBaselineRecallAt5 = 11.0 / 12.0
    /// The production mirror search's recorded recall.
    static let mirrorBaselineRecallAt1 = 10.0 / 12.0
    static let mirrorBaselineRecallAt3 = 11.0 / 12.0
    static let mirrorBaselineRecallAt5 = 12.0 / 12.0
    static let expanderBaselineRecallAt1 = 0.41

    let rows: [RankerResult]

    func row(named name: String) -> RankerResult {
        rows.first { $0.name == name }!
    }

    init() {
        let docs = RetrievalQualityCorpus.documents
        let queries = RetrievalQualityCorpus.queries

        // The reference models, each built once over the whole corpus.
        let characterModel = BM25Model(documents: docs, tokenizer: RankerTable.tokenizeCharacter)
        let bigramModel = BM25Model(documents: docs, tokenizer: RankerTable.tokenizeBigram)
        let appleWordModel = BM25Model(documents: docs, tokenizer: RankerTable.tokenizeAppleWord)
        let bigramWithTitleModel = BM25Model(documents: docs, tokenizer: RankerTable.tokenizeBigram, includeTitle: true)

        // The corpus as the app's own search sees it.
        let library = RankerTable.libraryCorpus(docs: docs)
        let mirrorEntries = docs.map {
            MirrorRanking.entry(docId: $0.path, title: $0.title, body: $0.body)
        }

        rows = [
            // The production library search (= what the library's own view
            // runs today): the app's own function, asked for its answer.
            RankerTable.measureOrdered(
                name: RankerTable.libraryName,
                queries: queries
            ) { question in
                ReferenceLibrarySearch.search(
                    query: question,
                    references: library.references,
                    bodyOf: { library.bodyOf($0) }
                ).map { library.pathOf($0.reference.id) }
            },
            // The production mirror search (= what the app answers with when
            // the system index is unavailable): the app's own function.
            RankerTable.measureOrdered(
                name: RankerTable.mirrorName,
                queries: queries
            ) { question in
                MirrorRanking.rank(entries: mirrorEntries, query: question, limit: docs.count)
                    .map(\.docId)
            },
            RankerTable.measure(
                name: RankerTable.characterName,
                docs: docs,
                queries: queries,
                score: { doc, queryTokens in characterModel.score(of: doc, queryTokens: queryTokens) },
                queryTokens: { RankerTable.tokenizeCharacter($0) }
            ),
            RankerTable.measure(
                name: RankerTable.bigramName,
                docs: docs,
                queries: queries,
                score: { doc, queryTokens in bigramModel.score(of: doc, queryTokens: queryTokens) },
                queryTokens: { RankerTable.tokenizeBigram($0) }
            ),
            RankerTable.measure(
                name: RankerTable.appleWordName,
                docs: docs,
                queries: queries,
                score: { doc, queryTokens in appleWordModel.score(of: doc, queryTokens: queryTokens) },
                queryTokens: { RankerTable.tokenizeAppleWord($0) }
            ),
            RankerTable.measure(
                name: RankerTable.bigramWithTitleName,
                docs: docs,
                queries: queries,
                score: { doc, queryTokens in bigramWithTitleModel.score(of: doc, queryTokens: queryTokens) },
                queryTokens: { RankerTable.tokenizeBigram($0) }
            ),
            // The query-time expander: one independent query per term, and
            // the answers interleaved.
            RankerTable.measureExpanded(
                name: RankerTable.expanderName,
                docs: docs,
                queries: queries,
                model: appleWordModel,
                tokenizer: RankerTable.tokenizeAppleWord
            ),
        ]
    }

    // MARK: The corpus as the app's own search sees it

    /// The corpus as `ReferenceLibrarySearch` sees it: one `Reference` per
    /// document, and the body the app would read for it.
    struct LibraryCorpus {
        let references: [Reference]
        private let paths: [UUID: String]
        private let bodies: [UUID: String]

        init(
            references: [Reference],
            paths: [UUID: String],
            bodies: [UUID: String]
        ) {
            self.references = references
            self.paths = paths
            self.bodies = bodies
        }

        /// The corpus document a hit's reference is.
        func pathOf(_ id: UUID) -> String {
            paths[id] ?? ""
        }

        /// The body of one corpus document.
        func bodyOf(_ reference: Reference) -> String? {
            bodies[reference.id]
        }
    }

    /// Build the corpus the app's own library search can search.
    static func libraryCorpus(docs: [RetrievalQualityCorpus.Document]) -> LibraryCorpus {
        var paths: [UUID: String] = [:]
        var bodies: [UUID: String] = [:]
        var references: [Reference] = []
        for doc in docs {
            let reference = Reference(title: doc.title)
            paths[reference.id] = doc.path
            bodies[reference.id] = doc.body
            references.append(reference)
        }
        return LibraryCorpus(references: references, paths: paths, bodies: bodies)
    }

    // MARK: Ranking one corpus

    /// Measure a ranker that answers the way the app answers: it is given
    /// the question and the corpus, and it returns the documents in the
    /// order the app would show them.
    ///
    /// **⇒ The production rows use this (= they ask the app's own search
    /// for its answer), = so a change to the app's ranking moves this
    /// table.**
    static func measureOrdered(
        name: String,
        queries: [RetrievalQualityCorpus.Query],
        answer: (String) -> [String]
    ) -> RankerResult {
        var at1 = 0, at3 = 0, at5 = 0, bridgeAt1 = 0, bridgeAt3 = 0, bridgeTotal = 0
        for query in queries {
            let paths = answer(query.text)
            let rank = paths.firstIndex(of: query.goldPath) ?? -1
            if rank == 0 {
                at1 += 1
            }
            if rank >= 0 && rank < 3 {
                at3 += 1
            }
            if rank >= 0 && rank < 5 {
                at5 += 1
            }
            if query.kind == .bridge {
                bridgeTotal += 1
                if rank == 0 {
                    bridgeAt1 += 1
                }
                if rank >= 0 && rank < 3 {
                    bridgeAt3 += 1
                }
            }
        }
        let n = Double(max(1, queries.count))
        return RankerResult(
            name: name,
            recallAt1: Double(at1) / n,
            recallAt3: Double(at3) / n,
            recallAt5: Double(at5) / n,
            bridgeAt1: Double(bridgeAt1) / Double(max(1, bridgeTotal)),
            bridgeAt3: Double(bridgeAt3) / Double(max(1, bridgeTotal))
        )
    }

    /// Rank every document for every query with a query-time expander: the
    /// question's terms each get their own independent query, and the
    /// per-term answers are interleaved (= a rare term's answer cannot be
    /// crowded out by a common term's).
    ///
    /// This is the shape another project's retriever uses, and it is the
    /// measurement that decides whether the app builds one.
    static func measureExpanded(
        name: String,
        docs: [RetrievalQualityCorpus.Document],
        queries: [RetrievalQualityCorpus.Query],
        model: BM25Model,
        tokenizer: (String) -> [String]
    ) -> RankerResult {
        var at1 = 0, at3 = 0, at5 = 0, bridgeAt1 = 0, bridgeAt3 = 0, bridgeTotal = 0
        for query in queries {
            let terms = tokenizer(query.text)
            // One independent query per term.
            let perTerm: [[RetrievalQualityCorpus.Document]] = terms.map { term in
                docs
                    .map { (doc: $0, value: model.score(of: $0, queryTokens: [term])) }
                    .sorted { $0.value > $1.value }
                    .map(\.doc)
            }
            // The answers interleave (= round robin over the terms).
            var interleaved: [RetrievalQualityCorpus.Document] = []
            var seen = Set<String>()
            var index = 0
            while interleaved.count < docs.count {
                var progressed = false
                for list in perTerm where index < list.count {
                    if seen.insert(list[index].path).inserted {
                        interleaved.append(list[index])
                    }
                    progressed = true
                }
                if !progressed {
                    break
                }
                index += 1
            }
            let paths = interleaved.map(\.path)
            let rank = paths.firstIndex(of: query.goldPath) ?? -1
            if rank == 0 {
                at1 += 1
            }
            if rank >= 0 && rank < 3 {
                at3 += 1
            }
            if rank >= 0 && rank < 5 {
                at5 += 1
            }
            if query.kind == .bridge {
                bridgeTotal += 1
                if rank == 0 {
                    bridgeAt1 += 1
                }
                if rank >= 0 && rank < 3 {
                    bridgeAt3 += 1
                }
            }
        }
        let n = Double(max(1, queries.count))
        return RankerResult(
            name: name,
            recallAt1: Double(at1) / n,
            recallAt3: Double(at3) / n,
            recallAt5: Double(at5) / n,
            bridgeAt1: Double(bridgeAt1) / Double(max(1, bridgeTotal)),
            bridgeAt3: Double(bridgeAt3) / Double(max(1, bridgeTotal))
        )
    }

    /// Rank every document for every query and read the recall off the gold.
    static func measure(
        name: String,
        docs: [RetrievalQualityCorpus.Document],
        queries: [RetrievalQualityCorpus.Query],
        score: (RetrievalQualityCorpus.Document, [String]) -> Double,
        queryTokens: (String) -> [String]
    ) -> RankerResult {
        var at1 = 0, at3 = 0, at5 = 0, bridgeAt1 = 0, bridgeAt3 = 0, bridgeTotal = 0
        for query in queries {
            let tokens = queryTokens(query.text)
            let ranked = docs
                .map { (doc: $0, value: score($0, tokens)) }
                .sorted { $0.value > $1.value }
            let paths = ranked.map { $0.doc.path }
            let rank = paths.firstIndex(of: query.goldPath) ?? -1
            if rank == 0 {
                at1 += 1
            }
            if rank >= 0 && rank < 3 {
                at3 += 1
            }
            if rank >= 0 && rank < 5 {
                at5 += 1
            }
            if query.kind == .bridge {
                bridgeTotal += 1
                if rank == 0 {
                    bridgeAt1 += 1
                }
                if rank >= 0 && rank < 3 {
                    bridgeAt3 += 1
                }
            }
        }
        let n = Double(max(1, queries.count))
        return RankerResult(
            name: name,
            recallAt1: Double(at1) / n,
            recallAt3: Double(at3) / n,
            recallAt5: Double(at5) / n,
            bridgeAt1: Double(bridgeAt1) / Double(max(1, bridgeTotal)),
            bridgeAt3: Double(bridgeAt3) / Double(max(1, bridgeTotal))
        )
    }

    // MARK: Tokenizers

    /// A number as the table prints it.
    static func percent(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Whether the character belongs to a Chinese ideograph run.
    static func isCJK(_ character: Swift.Character) -> Bool {
        let value = character.unicodeScalars.first?.value ?? 0
        return (0x4E00 ... 0x9FFF).contains(value)
            || (0x3400 ... 0x4DBF).contains(value)
            || (0xF900 ... 0xFAFF).contains(value)
    }

    /// The production tokenizer: per character for Chinese, per word for
    /// ASCII.
    static func tokenizeCharacter(_ s: String) -> [String] {
        TokenOverlapRanking.tokenize(s)
    }

    /// Adjacent character pairs for Chinese runs, words for ASCII runs.
    static func tokenizeBigram(_ s: String) -> [String] {
        var out: [String] = []
        var index = s.startIndex
        while index < s.endIndex {
            let character: Swift.Character = s[index]
            if RankerTable.isCJK(character) {
                let next = s.index(after: index)
                if next < s.endIndex, RankerTable.isCJK(s[next]) {
                    out.append(String(s[index ... next]))
                    index = s.index(after: next)
                } else {
                    out.append(String(character))
                    index = next
                }
            } else if character.isASCII, character.isLetter || character.isNumber {
                var word = ""
                var cursor = index
                while cursor < s.endIndex {
                    let c = s[cursor]
                    guard c.isASCII, c.isLetter || c.isNumber else { break }
                    word.append(c)
                    cursor = s.index(after: cursor)
                }
                out.append(word.lowercased())
                index = cursor
            } else {
                index = s.index(after: index)
            }
        }
        return out
    }

    /// Apple's own word tokenizer, run over Simplified Chinese.
    static func tokenizeAppleWord(_ s: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.simplifiedChinese)
        tokenizer.string = s
        var out: [String] = []
        tokenizer.enumerateTokens(in: s.startIndex ..< s.endIndex) { range, _ in
            out.append(String(s[range]))
            return true
        }
        return out
    }
}

// MARK: - BM25 with inverse document frequency

/// BM25 over one corpus (K1 = 1.2, B = 0.75, the usual defaults), with the
/// inverse document frequency computed over the corpus once.
struct BM25Model {
    private let documents: [RetrievalQualityCorpus.Document]
    private let tokens: [[String]]
    private let documentFrequency: [String: Int]
    private let averageLength: Double

    init(
        documents: [RetrievalQualityCorpus.Document],
        tokenizer: (String) -> [String],
        includeTitle: Bool = false
    ) {
        self.documents = documents
        tokens = documents.map { doc in
            tokenizer(includeTitle ? doc.title + "\n" + doc.body : doc.body)
        }
        var frequency: [String: Int] = [:]
        for documentTokens in tokens {
            for token in Set(documentTokens) {
                frequency[token, default: 0] += 1
            }
        }
        documentFrequency = frequency
        let total = tokens.reduce(0) { $0 + $1.count }
        averageLength = Double(total) / Double(max(1, tokens.count))
    }

    /// The BM25 score of one document for one token list.
    func score(of document: RetrievalQualityCorpus.Document, queryTokens: [String]) -> Double {
        guard let index = documents.firstIndex(where: { $0.path == document.path }) else { return 0 }
        let documentTokens = tokens[index]
        let documentLength = Double(documentTokens.count)
        let counts = Dictionary(grouping: documentTokens, by: { $0 }).mapValues(\.count)
        let n = Double(documents.count)
        let k1 = 1.2, b = 0.75
        var total = 0.0
        for token in Set(queryTokens) {
            guard let frequency = counts[token] else { continue }
            let df = Double(documentFrequency[token] ?? 0)
            let idf = log(n + 1) / (df + 1) + 1
            let f = Double(frequency)
            total += idf * (f * (k1 + 1)) / (f + k1 * (1 - b + b * documentLength / averageLength))
        }
        return total
    }
}
