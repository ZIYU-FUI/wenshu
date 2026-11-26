//
//  RetrievalQualityTests+CorpusSearch.swift · Wenshu · the corpus half, called
//
//  The harness beside this file measures the RANKING (= `RankerTable`'s two
//  production rows), and the ranking is half of the answer the agent gets.
//  The other half is `ReferenceCorpusSearch.search`, and it owns two rules
//  the ranking does not have: the glue list (= the words that carry no
//  question on their own, dropped from the query before anything is ranked)
//  and the held-term rule (= a term is held when a sentence's OWN TOKENS
//  contain it, and a document that holds none is not the answer). Neither
//  rule was held here: a change to either moved the app's answers and left
//  this harness exactly where it was, because the harness never called the
//  thing that owns them.
//
//  **⇒ THESE ROWS CALL `ReferenceCorpusSearch.search`, = = NOT THE RANKING
//  BY PROXY.** = What is asserted is the answer the agent's own tool
//  receives (= the same call `ReferenceLibraryActor+Search` makes), = and
//  not a re-declaration of it. = A row that measured the ranking again would
//  measure what the row above it already measures.
//
//  **⇒ WHY THIS FILE CARRIES ITS OWN TWO DOCUMENTS.** = ADB-0034's held-term
//  rule turns on a term being a PIECE of a longer word, = and a Chinese-only
//  text cannot say that: = the tokenizer cuts CJK one character per token, =
//  so a single character is a substring of a sentence exactly when it is a
//  token of it (= measured: = the fixture's 59 documents hold 0 ASCII letters,
//  = and over all 12 of its questions the token reading and the substring
//  reading return the same sentences). = So the rule is held over two
//  documents that carry a Latin word, = and the fixture's own corpus is
//  untouched: = adding to it would move the measured floor, = which is not
//  what this card is for.
//
//  See AGENTS.md 4.6 for the search contract, ADR-0034 for the split these
//  two rules come from, and `docs/agents/2026-11-26-the-retrieval-corpus-
//  search-arm-acceptance.md` for what each of these rows was measured to do.
//
import Foundation
import Testing
@testable import WenshuApp

extension RetrievalQualityTests {
    // MARK: - The documents the Latin-word rule needs

    /// A document that carries the same word twice, = once whole and once as
    /// the piece of a longer one.
    ///
    /// ⇒ THE TWO SENTENCES ARE THE TEST. = The question asks for `PDF`. = The
    /// first sentence holds it as its own token; = the second holds `PDFs`,
    /// which contains `PDF` as a substring and is NOT the word the ranking
    /// scored. = A citation rule that reads substrings cites both.
    private static let latinTermDocument = RetrievalQualityCorpus.Document(
        path: "08-杂录/银路账目.md",
        title: "银路账目",
        body: "白银的账目存成 PDF。旧的另作 PDFs 处理。"
    )

    /// The one sentence of it the question is allowed to cite.
    private static let latinHeldSentence = "白银的账目存成 PDF"

    /// A document that shares the question's GRAMMAR and none of its content.
    ///
    /// ⇒ THE RANKING NAMES IT. = It speaks the possessive particle, the
    /// copula and the adjective for OLD (= the three characters the question
    /// above also speaks), = so a ranking that counts occurrences puts it in. = **⇒⇒⇒ THE CORPUS SEARCH MUST NOT.** = Neither its body nor its
    /// title holds one word the question carries besides its glue, = and a
    /// document like that is not evidence of anything.
    private static let grammarOnlyDocument = RetrievalQualityCorpus.Document(
        path: "08-杂录/关税旧档.md",
        title: "关税旧档",
        body: "此处的记录是旧的。"
    )

    private static let searchDocuments = [latinTermDocument, grammarOnlyDocument]

    /// The corpus half's own answer, = built the way the library builds it:
    /// one `Reference` per document, = and the file the body was read from.
    private static func corpusAnswer(
        _ query: String,
        docs: [RetrievalQualityCorpus.Document]
    ) -> [ReferenceCorpusHit] {
        let corpus = RankerTable.libraryCorpus(docs: docs)
        return ReferenceCorpusSearch.search(
            query: query,
            references: corpus.references,
            bodyOf: { reference in
                guard let body = corpus.bodyOf(reference) else { return nil }
                return (body, URL(fileURLWithPath: corpus.pathOf(reference.id)))
            },
            indexHits: []
        )
    }

    /// The question's own words, = less the glue the corpus search drops.
    ///
    /// The fold is production's (= `tokenize`, = lowercased, = less both
    /// lists), = because a fixture that re-declares the drop would be testing
    /// its own copy of the rule instead of the rule.
    private static func contentTerms(of query: String) -> Set<String> {
        Set(
            TokenOverlapRanking.tokenize(query)
                .map { $0.lowercased() }
                .filter {
                    !ReferenceCorpusSearch.commonWords.contains($0)
                        && !ReferenceCorpusSearch.commonCharacters.contains($0)
                }
        )
    }

    // MARK: - The glue list

    @Test("a Chinese question made only of glue answers with nothing, and the list is what makes it glue")
    func grammarOnlyChineseQuestionAnswersWithNothing() {
        // **⇒ BOTH HALVES OF THE RULE ARE ASSERTED, = = AND EACH GOES RED ON
        // ITS OWN.** = The first says these characters ARE the list's (= a
        // change to `commonCharacters` reddens it); = the second says the
        // corpus search DOES answer with nothing when a question carries
        // nothing else (= a change to what the list is used for reddens it).
        // = = A row that asserted only the empty answer would stay green over
        // a list that had quietly stopped containing these characters, = and
        // would be asserting the corpus's emptiness instead of the rule.
        let question = "这个是什么"

        #expect(
            ReferenceCorpusSearch.commonCharacters.isSuperset(
                of: Set(TokenOverlapRanking.tokenize(question))
            ),
            "the question's own characters must all be glue, or this row is measuring a corpus that holds nothing"
        )
        #expect(
            Self.contentTerms(of: question).isEmpty,
            "a question made only of glue carries no content word for the library to answer"
        )
        #expect(
            Self.corpusAnswer(question, docs: RetrievalQualityCorpus.documents).isEmpty,
            "a question of pure grammar must answer with nothing, and not with the documents that merely share its grammar"
        )
    }

    @Test("the glue list empties a question the library cannot answer and leaves the ones it can alone")
    func glueListDoesNotDropTheQuestionItself() {
        // **⇒⇒⇒ THE SAME LIST MUST NOT MAKE AN ANSWERABLE QUESTION ANSWER
        // WITH NOTHING.** = The list is a drop of the question's GRAMMAR, =
        // not of its subject, = and a character that can carry a subject
        // (= ADR-0034 names five: = up, = down, = middle, = have, = lack) = is
        // deliberately not in it. = Over the fixture's twelve questions the list leaves every
        // one of them answerable, = and the gold document is named for every
        // one. = **⇒ So this row is the one that goes red if the list is
        // widened** (= = a character that carries a subject is added, = and
        // the question loses the word it was asking with).
        var answered = 0
        var goldNamed = 0
        for query in RetrievalQualityCorpus.queries {
            let hits = Self.corpusAnswer(query.text, docs: RetrievalQualityCorpus.documents)
            if !hits.isEmpty {
                answered += 1
            }
            if hits.contains(where: { $0.path.hasSuffix(query.goldPath) }) {
                goldNamed += 1
            }
        }
        #expect(
            answered == RetrievalQualityCorpus.queries.count,
            "the glue list must not empty a question the library holds the answer to: \(answered) of \(RetrievalQualityCorpus.queries.count) answered"
        )
        #expect(
            goldNamed == RetrievalQualityCorpus.queries.count,
            "the document that holds the answer must be named for every question the fixture asks: \(goldNamed) of \(RetrievalQualityCorpus.queries.count)"
        )

        // **⇒ THE BOUNDARY THE PRODUCTION COMMENT NAMES BY CHARACTER.** = The
        // comment beside the list refuses the five characters it names (= up, =
        // down, = middle, = have, = lack), = and says why: = each of them can
        // carry the subject a question is asking about (= "where", = "have", =
        // "missing"), = so dropping it
        // drops the question with it. = This is the row that catches that
        // edit (= = widening the list past grammar into a subject), = and it
        // is asserted rather than commented because a comment does not stop
        // a character from being added.
        let subjectCarrying = ["上", "下", "中", "有", "缺"]
        let refused = Set(subjectCarrying)
        #expect(
            refused.isDisjoint(with: ReferenceCorpusSearch.commonCharacters),
            "a character that can carry a question's subject must never join the glue list: \(refused.intersection(ReferenceCorpusSearch.commonCharacters))"
        )
    }

    // MARK: - The held-term rule

    @Test("a fragment holds the word the ranking scored, and not a piece of a longer word")
    func termIsHeldByTokenAndNotBySubstring() {
        // **⇒ THE SENTENCE THAT HOLDS `PDFs` IS NOT THE SENTENCE THAT HOLDS
        // `PDF`.** = The fixture's own corpus cannot show this (= = its 59
        // documents carry no Latin word, = and a single CJK character is a
        // substring of a sentence exactly when it is a token of it), = so the
        // pair of sentences lives here.
        let hits = Self.corpusAnswer("白银的 PDF 存在哪里", docs: Self.searchDocuments)
        #expect(
            hits.count == 1,
            "the question carries one document's own word, so exactly one document answers: \(hits.map(\.title))"
        )
        #expect(
            hits.first?.fragments == [Self.latinHeldSentence],
            "only the sentence holding the word itself may be cited, and not the sentence holding it as a piece of a longer word: \(hits.first?.fragments ?? [])"
        )
    }

    @Test("the document that shares only the question's grammar is not the answer")
    func grammarSharingDocumentIsNotNamed() {
        // **⇒ A DOCUMENT THE RANKING NAMED, = = AND THE ANSWER MUST NOT.** =
        // The grammar-only document speaks the possessive particle, the copula
        // and the adjective for OLD (= the question's own grammar and nothing
        // of its subject), = so an occurrence-counting ranking puts
        // it in front of the reader. = The corpus search's fragment step is
        // what keeps it out: = no sentence of it holds a word the question
        // carries besides glue, = and its title holds none either, = so the
        // first-sentence fallback does not save it.
        let hits = Self.corpusAnswer("白银的 PDF 存在哪里", docs: Self.searchDocuments)
        #expect(
            hits.allSatisfy { !$0.path.hasSuffix(Self.grammarOnlyDocument.path) },
            "a document that holds none of the question's content words must not be named, however the ranking scored it: \(hits.map(\.title))"
        )
        let terms = Self.contentTerms(of: "白银的 PDF 存在哪里")
        let heldByGrammarOnlyDocument = terms.intersection(
            Set(TokenOverlapRanking.tokenize(Self.grammarOnlyDocument.body))
        ).union(terms.intersection(Set(TokenOverlapRanking.tokenize(Self.grammarOnlyDocument.title))))
        #expect(
            heldByGrammarOnlyDocument.isEmpty,
            "the document being kept out must genuinely hold no content word of the question, or this row is measuring the rule's absence: \(heldByGrammarOnlyDocument)"
        )
    }

    @Test("every fragment the corpus search cites holds a word of the question")
    func fragmentsHoldAContentWordAcrossTheFixture() {
        // **⇒ THE DURABLE CLAIM ADR-0034 MAKES ABOUT THE ANSWER'S SHAPE, = =
        // READ OFF THE ANSWER ITSELF.** = Every sentence the corpus search
        // cites for every one of the fixture's twelve questions holds at
        // least one of that question's own content words (= measured at this
        // tree: = 0 fragments citing grammar alone, = over every fragment of
        // every answer). = A fragment that held only glue would be the
        // document's first sentence arriving as evidence for nothing.
        var fragments = 0
        var glueOnly = 0
        for query in RetrievalQualityCorpus.queries {
            let terms = Self.contentTerms(of: query.text)
            for hit in Self.corpusAnswer(query.text, docs: RetrievalQualityCorpus.documents) {
                for fragment in hit.fragments {
                    fragments += 1
                    if terms.isDisjoint(with: Set(TokenOverlapRanking.tokenize(fragment))) {
                        glueOnly += 1
                    }
                }
            }
        }
        #expect(fragments > 0, "the sweep must have read fragments at all, or it measured nothing")
        #expect(glueOnly == 0, "no cited fragment may hold nothing of the question besides its grammar: \(glueOnly) of \(fragments) did")
    }
}
