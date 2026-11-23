//
// RetrievalQualityTests.swift · Wenshu · the retrieval quality harness
//
// The library's search layer had no number behind it: the existing suites
// cover the tokenizer, the scorer, the mirror round-trip and the view's
// behaviour, and none of them answers "does the right document come back".
// This harness is that number, over one synthetic corpus with one gold per
// query, and it compares five rankers on the same documents:
//
//   wenshu-token-overlap  the production scorer, as the library runs it today
//                         (per-character tokens, title weighted twice the body,
//                         no inverse document frequency)
//   bm25-character        BM25 with inverse document frequency, over the same
//                         per-character tokens the production tokenizer emits
//   bm25-bigram           BM25 over adjacent character pairs (= a Chinese
//                         bigram tokenizer, which needs no dictionary)
//   bm25-apple-word       BM25 over Apple's own word tokenizer, which knows
//                         Chinese words but no coined proper noun
//   bm25-bigram+title     the same, with the title inside the searched text
//                         (= what an indexed keyword buys)
//
// The corpus is written so the rankers separate: half of it answers a
// question and half speaks the question's own high-frequency words without
// answering it, so a ranker with no inverse document frequency drowns.
//
// The harness runs in-process and reads no system index, so it is stable in
// CI. A system-index probe is a separate instrument, because Core Spotlight
// answers asynchronously and its query latency is its own measurement.
//
// See AGENTS.md 4.6 for the search contract these numbers hold up.
//

import Foundation
import NaturalLanguage
import Testing
@testable import WenshuApp

@Suite("Retrieval quality (the library's ranking, measured)")
struct RetrievalQualityTests {
    // MARK: - The fixture's own soundness

    @Test("every gold path names a document of the corpus")
    func goldPathsResolve() {
        let paths = Set(RetrievalQualityCorpus.documents.map(\.path))
        for query in RetrievalQualityCorpus.queries {
            #expect(paths.contains(query.goldPath),
                    "the gold path of a query must name a document of the corpus")
        }
    }

    @Test("every anchor token occurs in exactly one document")
    func anchorsAreUnique() {
        for query in RetrievalQualityCorpus.queries {
            let holders = RetrievalQualityCorpus.documents.filter {
                $0.title.contains(query.anchor) || $0.body.contains(query.anchor)
            }
            #expect(holders.count == 1,
                    "an anchor token must mark exactly one document, and the gold must be it")
            let gold = RetrievalQualityCorpus.documents.first { $0.path == query.goldPath }
            #expect(gold?.title.contains(query.anchor) == true
                || gold?.body.contains(query.anchor) == true,
                "the gold document must carry the anchor token")
        }
    }

    @Test("the query set carries both direct and bridge questions")
    func querySetHasBothShapes() {
        let direct = RetrievalQualityCorpus.queries.filter { $0.kind == .direct }.count
        let bridge = RetrievalQualityCorpus.queries.filter { $0.kind == .bridge }.count
        #expect(direct >= 6, "the fixture needs enough direct questions to be stable")
        #expect(bridge >= 3, "the fixture needs the bridge shape to be measured at all")
    }

    @Test("the corpus holds enough noise to separate the rankers")
    func corpusHasNoise() {
        #expect(RetrievalQualityCorpus.noise.count >= RetrievalQualityCorpus.answers.count,
                "the corpus needs at least as many noise documents as answering ones, or a ranker without inverse document frequency cannot drown")
    }

    // MARK: - The numbers

    @Test("the corpus's retrieval numbers are printed for the record")
    func reportNumbers() {
        let table = RankerTable()
        print("")
        print("  retrieval quality over \(RetrievalQualityCorpus.documents.count) documents "
            + "(\(RetrievalQualityCorpus.answers.count) answering, "
            + "\(RetrievalQualityCorpus.noise.count) noise) and "
            + "\(RetrievalQualityCorpus.queries.count) questions")
        print("")
        print("  ranker                  recall@1  recall@3  recall@5  bridge@1 bridge@3")
        for row in table.rows {
            let padding = String(repeating: " ", count: max(0, 22 - row.name.count))
            print("  \(row.name)\(padding)"
                + "  \(RankerTable.percent(row.recallAt1))"
                + "  \(RankerTable.percent(row.recallAt3))"
                + "  \(RankerTable.percent(row.recallAt5))"
                + "  \(RankerTable.percent(row.bridgeAt1))"
                + "  \(RankerTable.percent(row.bridgeAt3))")
        }
        print("")
    }

    @Test("the production ranker holds its recorded recall")
    func productionHoldsItsBaseline() {
        let table = RankerTable()
        let production = table.row(named: RankerTable.productionName)
        #expect(production.recallAt1 >= RankerTable.productionBaselineRecallAt1,
                "the production ranker must not fall below its recorded recall@1")
        #expect(production.recallAt3 >= RankerTable.productionBaselineRecallAt3,
                "the production ranker must not fall below its recorded recall@3")
    }

    @Test("the reference ranker with inverse document frequency is ahead of the production scorer")
    func referenceBeatsProduction() {
        let table = RankerTable()
        let production = table.row(named: RankerTable.productionName)
        let reference = table.row(named: RankerTable.bigramName)
        // The corpus is written so a ranker that weighs a term by how rare it
        // is outranks one that only counts how often a query token appears.
        #expect(reference.recallAt1 >= production.recallAt1,
                "the reference ranker must not fall behind the production scorer")
        #expect(reference.bridgeAt1 >= production.bridgeAt1,
                "the reference ranker must not fall behind the production scorer on the bridge shape")
    }

    @Test("the character tokenizer does not outrank the bigram one on this corpus")
    func bigramNotWorseThanCharacter() {
        let table = RankerTable()
        let character = table.row(named: RankerTable.characterName)
        let bigram = table.row(named: RankerTable.bigramName)
        #expect(bigram.recallAt1 >= character.recallAt1,
                "the bigram tokenizer must not rank worse than the character one here")
    }

    @Test("putting the title into the searched text does not lower the ranking")
    func titleInSearchedTextHelps() {
        let table = RankerTable()
        let bodyOnly = table.row(named: RankerTable.bigramName)
        let withTitle = table.row(named: RankerTable.bigramWithTitleName)
        #expect(withTitle.recallAt1 >= bodyOnly.recallAt1,
                "searching the title as well must not lower the ranking")
    }
}

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

/// The five rankers, measured over the same corpus.
struct RankerTable {
    static let productionName = "wenshu-token-overlap"
    static let characterName = "bm25-character"
    static let bigramName = "bm25-bigram"
    static let appleWordName = "bm25-apple-word"
    static let bigramWithTitleName = "bm25-bigram+title"

    /// The production ranker's recorded recall (= the gate a change to the
    /// library's search path must not fall below).
    static let productionBaselineRecallAt1 = 0.66
    static let productionBaselineRecallAt3 = 0.91

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

        rows = [
            // The production ranker, as the library runs it today: the
            // production tokenizer, the production score, the title weighted
            // twice the body, and no inverse document frequency.
            RankerTable.measure(
                name: RankerTable.productionName,
                docs: docs,
                queries: queries,
                score: { doc, queryTokens in
                    let titleTokens = TokenOverlapRanking.tokenize(doc.title)
                    let bodyTokens = TokenOverlapRanking.tokenize(doc.body)
                    let titleScore = TokenOverlapRanking.score(queryTokens: queryTokens, docTokens: titleTokens)
                    let bodyScore = TokenOverlapRanking.score(queryTokens: queryTokens, docTokens: bodyTokens)
                    return titleScore * 2 + bodyScore
                },
                queryTokens: { TokenOverlapRanking.tokenize($0) }
            ),
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
        ]
    }

    // MARK: Ranking one corpus

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
