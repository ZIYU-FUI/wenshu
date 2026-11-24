//
// RetrievalQualityTests.swift · Wenshu · the retrieval quality harness
//
// The library's search layer had no number behind it: the existing suites
// cover the tokenizer, the scorer, the mirror round-trip and the view's
// behaviour, and none of them answers "does the right document come back".
// This harness is that number, over one synthetic corpus with one gold per
// query, and it compares eight rankers on the same documents:
//
//   wenshu-library            the production search the library's own view
//                             runs (= `ReferenceLibrarySearch.search`),
//                             called
//   wenshu-mirror             the production search the mirror falls back
//                             to (= `MirrorRanking.rank`), called
//   wenshu-union              the production merge of the two above (= the
//                             agent's corpus answer), called
//   bm25-character            BM25 with inverse document frequency, over the
//                             same per-character tokens the production
//                             tokenizer emits
//   bm25-bigram               BM25 over adjacent character pairs (= a Chinese
//                             bigram tokenizer, which needs no dictionary)
//   bm25-apple-word           BM25 over Apple's own word tokenizer, which
//                             knows Chinese words but no coined proper noun
//   bm25-bigram+title         the same, with the title inside the searched text
//                             (= what an indexed keyword buys)
//   bm25-apple-word+expander  one independent query per term, and the
//                             answers interleaved (= the shape another
//                             project's retriever uses)
//
// **⇒ THE TWO PRODUCTION ROWS CALL THE APP'S OWN SEARCH.** = The first
// version of this harness re-declared the production ranking in the test
// file, = and a change to the app's ranking left this table exactly where
// it was: = the table measured the copy and not the app. = A row that
// re-declares the ranking measures nothing, = so the production rows ask
// the app's own functions for their answer.
//
// The corpus is written so the rankers separate: 19 of its 59 documents
// answer a question and 40 speak the question's own high-frequency words
// without answering it, so a ranker with no inverse document frequency
// drowns.
//
// The harness runs in-process and reads no system index, so it is stable in
// CI. A system-index probe is a separate instrument, because Core Spotlight
// answers asynchronously and its query latency is its own measurement.
//
// See AGENTS.md 4.6 for the search contract these numbers hold up.
//

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

    @Test("the production library search holds its recorded recall")
    func libraryHoldsItsBaseline() {
        let table = RankerTable()
        let library = table.row(named: RankerTable.libraryName)
        #expect(library.recallAt1 >= RankerTable.libraryBaselineRecallAt1,
                "the production library search must not fall below its recorded recall@1")
        #expect(library.recallAt3 >= RankerTable.libraryBaselineRecallAt3,
                "the production library search must not fall below its recorded recall@3")
        #expect(library.recallAt5 >= RankerTable.libraryBaselineRecallAt5,
                "the production library search must not fall below its recorded recall@5")
    }

    @Test("the production mirror search holds its recorded recall")
    func mirrorHoldsItsBaseline() {
        let table = RankerTable()
        let mirror = table.row(named: RankerTable.mirrorName)
        #expect(mirror.recallAt1 >= RankerTable.mirrorBaselineRecallAt1,
                "the production mirror search must not fall below its recorded recall@1")
        #expect(mirror.recallAt3 >= RankerTable.mirrorBaselineRecallAt3,
                "the production mirror search must not fall below its recorded recall@3")
        // **⇒ The floor holds every recall the table prints, = = because a
        // ranking can lose the SECOND and THIRD hit without losing the
        // first.** = = A floor on one column is a floor on one column.
        #expect(mirror.recallAt5 >= RankerTable.mirrorBaselineRecallAt5,
                "the production mirror search must not fall below its recorded recall@5")
    }

    @Test("the union of the two rankings holds its recorded recall")
    func unionHoldsItsBaseline() {
        let table = RankerTable()
        let union = table.row(named: RankerTable.unionName)
        #expect(union.recallAt1 >= RankerTable.unionBaselineRecallAt1,
                "the union must not fall below its recorded recall@1")
        #expect(union.recallAt3 >= RankerTable.unionBaselineRecallAt3,
                "the union must not fall below its recorded recall@3")
        #expect(union.recallAt5 >= RankerTable.unionBaselineRecallAt5,
                "the union must not fall below its recorded recall@5")
    }

    @Test("the corpus half names more documents than the answer can carry")
    func corpusHalfNamesMoreDocumentsThanTheAnswerCarries() throws {
        // The shape the merge rule exists for (= ADR-0034 and the fusion
        // file both cite it, = so it is measured here rather than quoted).
        let counts = RankerTable.corpusHalfNameCounts()
        print("  corpus half names per question: \(counts.map { String($0) }.joined(separator: " ")) (= the answer carries at most \(ReferenceCorpusSearch.defaultLimit))")
        let fewest = try #require(counts.min(), "twelve questions must give twelve counts")
        let most = try #require(counts.max(), "twelve questions must give twelve counts")
        #expect(
            fewest > ReferenceCorpusSearch.defaultLimit,
            "if the corpus half ever names no more than the answer carries, a merge that lets its order lead is no longer losing anything, and the rule needs re-arguing: \(counts)"
        )
        #expect(
            fewest >= 19 && most <= 41,
            "the range the records cite is 19 to 41; if the measurement moved, the records move with it: \(counts)"
        )
    }

    @Test("the union is neither half's order")
    func unionIsNeitherHalfsOrder() {
        // **⇒ A MERGE THAT COPIES ONE HALF MEASURES NOTHING.** = The
        // first version of the merge kept the corpus half's order, = and
        // the union row then printed the library row's own numbers (= 0.75
        // / 0.92 / 1.00 / 0.67) = = and every floor was green over a row
        // that was a copy of another row. = **⇒ So the gate is the merge
        // ITSELF: = the union's order must be its own**, = and it must be
        // the index half's order just as little (= a merge that copied
        // the index half would bury the corpus half the same way).
        var sameAsCorpus = 0
        var sameAsIndex = 0
        for query in RetrievalQualityCorpus.queries {
            let orders = RankerTable.mergeOrders(question: query.text)
            if orders.union == orders.corpus {
                sameAsCorpus += 1
            }
            if orders.union == orders.index {
                sameAsIndex += 1
            }
        }
        #expect(sameAsCorpus == 0,
                "the union's order must not be the corpus half's order (= a merge that keeps one half's order is that half's answer with a name on it)")
        #expect(sameAsIndex == 0,
                "the union's order must not be the index half's order (= the corpus half answers every question, = so an order that ignores it is not an answer)")
    }

    @Test("the index half's documents reach the answer")
    func indexHalfReachesTheAnswer() {
        // **⇒ THE INDEX HALF MUST NOT BE READ AND THEN DROPPED.** = The
        // merge's job is to put a document the corpus half's terms never
        // met into the answer, = and a merge that kept the corpus half's
        // order put every one of them behind the corpus half's own
        // (= 19 to 41) documents, = which is past the answer's limit.
        // = **⇒ So the answer must hold documents the corpus half's own
        // first eight did not hold.**
        var questionsWithAnIndexOnlyDocument = 0
        for query in RetrievalQualityCorpus.queries {
            let orders = RankerTable.mergeOrders(question: query.text)
            let corpusTop = Set(orders.corpus.prefix(ReferenceCorpusSearch.defaultLimit))
            let answer = orders.union.prefix(ReferenceCorpusSearch.defaultLimit)
            if answer.contains(where: { !corpusTop.contains($0) }) {
                questionsWithAnIndexOnlyDocument += 1
            }
        }
        // **⇒ THE FLOOR IS A COUNT OF THE FIXTURE'S TWELVE QUESTIONS**,
        // (= and the number measured is ten: = = the two questions where
        // it does not hold are the two whose gold document both halves
        // rank first).
        #expect(questionsWithAnIndexOnlyDocument >= 10,
                "the answer must hold documents the corpus half's own first eight did not hold, = on at least ten of the fixture's twelve questions")
    }

    @Test("the union is not worse than the app's own ranking")
    func unionNotWorseThanLibrary() {
        let table = RankerTable()
        let union = table.row(named: RankerTable.unionName)
        let library = table.row(named: RankerTable.libraryName)
        // **⇒ THE UNION MAY NOT COST THE AGENT WHAT ONE HALF GAVE IT.**
        // = The merge adds the index's documents, = and a merge that
        // ranked the corpus half's own documents below the corpus
        // half's order would take away a rank the corpus half earned.
        // = So the union's first hit is at least as good as the corpus
        // half's, = and its first three are at least as good.
        //
        // **⇒ AND THE MERGE MAY NOT REPLACE THE CORPUS HALF EITHER.**
        // = Measured: the union's order equals the corpus half's order
        // on none of the fixture's twelve questions, = and that is what
        // the test beside this one says. = **⇒ So this assertion is not
        // the one that catches a merge that copied a half** (= the one
        // beside it is), = and it is here because the number the corpus
        // half earned is the corpus half's to keep.
        #expect(union.recallAt1 >= library.recallAt1,
                "the union must not rank the first hit worse than the app's own ranking does")
        #expect(union.recallAt3 >= library.recallAt3,
                "the union must not rank the first three hits worse than the app's own ranking does")
    }

    @Test("the reference ranker with inverse document frequency is ahead of the production library search")
    func referenceBeatsProduction() {
        let table = RankerTable()
        let library = table.row(named: RankerTable.libraryName)
        let reference = table.row(named: RankerTable.bigramName)
        // The corpus is written so a ranker that weighs a term by how rare it
        // is outranks one that only counts how often a query token appears.
        #expect(reference.recallAt1 >= library.recallAt1,
                "the reference ranker must not fall behind the production library search")
        #expect(reference.bridgeAt1 >= library.bridgeAt1,
                "the reference ranker must not fall behind the production library search on the bridge shape")
    }

    @Test("the character tokenizer does not outrank the bigram one on this corpus")
    func bigramNotWorseThanCharacter() {
        let table = RankerTable()
        let character = table.row(named: RankerTable.characterName)
        let bigram = table.row(named: RankerTable.bigramName)
        #expect(bigram.recallAt1 >= character.recallAt1,
                "the bigram tokenizer must not rank worse than the character one here")
    }

    @Test("the query-time expander holds its recorded recall")
    func expanderHoldsItsBaseline() {
        let table = RankerTable()
        let expander = table.row(named: RankerTable.expanderName)
        #expect(expander.recallAt1 >= RankerTable.expanderBaselineRecallAt1,
                "the expander must not fall below its recorded recall@1")
    }

    @Test("one weighted query outranks the expander on this corpus")
    func referenceOutranksExpander() {
        let table = RankerTable()
        let reference = table.row(named: RankerTable.appleWordName)
        let expander = table.row(named: RankerTable.expanderName)
        // One query per term, interleaved, gives every term the same weight,
        // = so a common term's top answers take the front rows. = The
        // weighted single query is ahead, = and this assertion is the one
        // that says so; = a change that closes the gap asks for the decision
        // to be made again, = not for the gap to be absorbed.
        #expect(reference.recallAt1 > expander.recallAt1,
                "the weighted query must stay ahead of the expander until the decision is made again")
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
