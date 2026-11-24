//
//  ReferenceCorpusSearch.swift
//
//  The corpus answer the agent gets, = and the two halves it is made of.
//
//  Why: the app's own search answers from the corpus it holds, = and
//  the system index answers from the documents it was given. = Each
//  half alone loses something: = the corpus half cannot name a
//  document it holds no term for, = and the index half cannot answer
//  at all until something has been written. = **⇒ So the answer is the
//  union of the two halves, = and the merge is one rule** (=
//  `ReferenceRankFusion`).
//
//  **⇒ WHAT EACH HALF CONTRIBUTES.** = The corpus half contributes the
//  documents the library holds and how well they match its terms. = The
//  index half contributes the documents the app indexed in an EARLIER
//  session (= the corpus reads the disk, = so it has them too, = but the
//  index ranks them by Apple's own relevance, = which bridges a
//  question to a document the app's own terms never met). = **⇒ So the
//  union's ORDER is where the two halves meet, = and the merge decides
//  it.** = **⇒ AND THE ORDER IS THE MERGE'S WORK, = = NOT THE CORPUS
//  HALF'S.** = Measured on the retrieval-quality harness's own fixture:
//  = the corpus half names every document it matched (= 19 to 41) = while
//  the answer names at most eight, = so a merge that kept the corpus
//  half's order put every document the index half named behind all of
//  them, = and none of them reached the agent.
//
//  **⇒ THE FRAGMENT IS THE APP'S OWN TEXT, = = AND NOT THE INDEX'S
//  SNIPPET.** = The index's snippet is a marked-up 64-character
//  prefix (= an HTML artefact of a UI that renders it), = and a
//  fragment at the sentence granularity the agent needs is not a
//  prefix. = So the index contributes WHICH documents and in WHAT
//  order, = and the app contributes the sentences themselves (= read
//  from the document's own body).
//
//  What: `search(...)` answers one question for the agent: = which
//  documents hold what the question asked for, = with the sentences
//  that hold it, = and where each document's body lives.
//
//

import Foundation

/// One document the corpus answer names, = with the evidence in it.
struct ReferenceCorpusHit: Equatable, Sendable {
    /// The document's id (= the reference's id).
    let id: UUID
    /// The document's title.
    let title: String
    /// The document's layer (= where in the reference library it lives).
    let layer: ReferenceLayer
    /// Where the document's body is on disk (= the file the fragments
    /// were read from).
    let path: String
    /// The sentences that hold the answer (= the evidence).
    let fragments: [String]
}

/// The corpus answer, = and the two halves it is made of.
enum ReferenceCorpusSearch {
    /// How many documents an answer names at most.
    ///
    /// **⇒ THE ANSWER IS FOR A READER, = = NOT A DUMP.** = An agent
    /// that asked one question wants the documents that answer it, = and
    /// a list long enough to bury the answer is a list the agent reads
    /// instead of the answer. = **⇒ So the answer is short, = and the
    /// documents are whole sentences, = not whole documents.**
    static let defaultLimit = 8

    /// Answer one question over the corpus.
    ///
    /// - Parameters:
    ///   - query: The question.
    ///   - references: The corpus (= the documents the library holds).
    ///   - bodyOf: The body of one document, = and the file it was read
    ///     from (= read off the main actor, = because a corpus of
    ///     documents is a corpus of files, = and the files are read
    ///     where the files are). = **⇒ The file comes with the text,
    ///     so the path reported is the file the fragments came from.**
    ///   - indexHits: The documents the system index named (= its own
    ///     answer, = which the corpus half may not have found).
    ///   - limit: How many documents to name at most.
    /// - Returns: The documents that hold the answer, = the two halves
    ///   merged into one order.
    /// The words a question is made of besides its content.
    ///
    /// **⇒ THE LIST IS EXPLICIT, = = AND IT IS SMALL.** = A stopword
    /// list is a judgement call, = and a judgement call that hides in
    /// a tokenizer cannot be checked. = So the words that carry no
    /// question on their own are written down here, = and the harness
    /// and the tool's own tests are what say the list is enough.
    static let commonWords: Set<String> = [
        "a", "about", "all", "an", "and", "any", "are", "as", "at", "be",
        "been", "but", "by", "can", "could", "did", "do", "does", "for",
        "from", "had", "has", "have", "he", "her", "here", "him", "his",
        "how", "i", "if", "in", "into", "is", "it", "its", "may", "might",
        "more", "must", "my", "no", "not", "of", "on", "or", "our", "out",
        "over", "she", "should", "so", "some", "such", "than", "that",
        "their", "them", "then", "there", "these", "they", "this", "the",
        "those", "to", "up", "was", "we", "were", "what", "when", "where",
        "which", "who", "why", "will", "with", "would", "you", "your",
    ]

    /// The Chinese characters that carry no question on their own.
    ///
    /// **⇒ THE SAME RULE HAS TO REACH THE APP'S OWN LANGUAGE, = = OR IT
    /// IS NOT A RULE.** = The tokenizer is character-level for CJK (= = one
    /// token per character), = = so a Chinese question arrives as a bag of
    /// single characters, = = and the glue list above drops NONE of them: =
    /// the Chinese copula and the possessive particle are glue in the same way
    /// "the" and "is" are, = = and they sit
    /// in every sentence of every document the library holds. = **⇒⇒⇒ So
    /// WITHOUT THIS LIST, = = A CHINESE QUESTION WAS ANSWERED BY THE
    /// DOCUMENT THAT MERELY SHARES ITS GRAMMAR.** = Measured with the list
    /// absent: = a question about bronze-bell casting, = against a library
    /// about land tax, = named the land tax document. = The two cases in
    /// the tool's own suite carry that reading.
    ///
    /// The list is function characters only. = A character that can carry
    /// a subject (= "up", = "down", = "middle", = "have", = "lack") = is NOT
    /// here, = because
    /// dropping it would drop the question with it: = this list makes an
    /// unanswerable question answer with nothing, = and it must not make a
    /// answerable one answer with nothing too.
    static let commonCharacters: Set<String> = [
        "的", "了", "是", "在", "和", "与", "及", "或", "也", "都",
        "很", "更", "最", "被", "把", "让", "向", "对", "为", "以",
        "于", "之", "其", "该", "这", "那", "些", "个", "么", "什",
        "怎", "样", "呢", "吗", "吧", "啊", "呀", "就", "才", "又",
        "再", "还", "并", "而", "且", "但", "如", "若",
    ]

    static func search(
        query: String,
        references: [Reference],
        bodyOf: (Reference) -> (body: String, url: URL)?,
        indexHits: [CSSearchResult],
        limit: Int = defaultLimit
    ) -> [ReferenceCorpusHit] {
        // **⇒ A FRAGMENT MUST HOLD A WORD THAT MEANS SOMETHING.** = A
        // question is mostly glue (= "the metallurgy of bronze bells in
        // the Zhou"), = and the glue is in every document. = So the
        // glue is dropped here, = and a fragment is a sentence that
        // holds a word of the QUESTION's content. = A question whose
        // content words are nowhere in the library therefore answers
        // with nothing, = which is the honest answer (= the library
        // holds nothing that answers it), = and not with a document
        // that merely shares its articles.
        let terms = Set(
            TokenOverlapRanking.tokenize(query)
                .map { $0.lowercased() }
                .filter { !Self.commonWords.contains($0) && !Self.commonCharacters.contains($0) }
        )
        guard !terms.isEmpty else { return [] }

        // The corpus half's own answer (= the ranking the harness
        // measures).
        let corpusHits = ReferenceLibrarySearch.search(
            query: query,
            references: references,
            bodyOf: { reference in bodyOf(reference)?.body }
        )

        // The index half's answer, = by document id.
        //
        // **⇒ A HIT THE INDEX NAMED IS A DOCUMENT OF THE CORPUS ONLY
        // IF THE CORPUS HOLDS IT.** = The index is the app's own
        // writing, = but a document the user deleted since leaves its
        // entry behind for a while, = and the corpus is what the
        // library holds NOW. = A hit the corpus does not hold is not
        // named back, = because the caller cannot open what the
        // library does not have.
        let byID = Dictionary(references.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var indexOrder: [UUID] = []
        var seen = Set<UUID>()
        for hit in indexHits {
            guard let id = Self.referenceID(ofDocID: hit.docId), byID[id] != nil else { continue }
            guard seen.insert(id).inserted else { continue }
            indexOrder.append(id)
        }

        // The union, = by the one merge rule.
        let merged = ReferenceRankFusion.merge(
            corpus: corpusHits.map(\.reference.id),
            index: indexOrder
        )

        var hits: [ReferenceCorpusHit] = []
        for id in merged.prefix(max(1, limit)) {
            guard let reference = byID[id] else { continue }
            guard let source = bodyOf(reference), !source.body.isEmpty else { continue }
            let fragments = ReferenceSentenceExcerpt.excerpt(
                for: source.body,
                terms: terms,
                title: reference.title
            )
            guard !fragments.isEmpty else { continue }
            hits.append(
                ReferenceCorpusHit(
                    id: reference.id,
                    title: reference.title,
                    layer: reference.layer,
                    path: source.url.path,
                    fragments: fragments
                )
            )
        }
        return hits
    }

    /// The reference id a system-index docId names.
    ///
    /// **⇒ THE PREFIX IS THE DOCID SCHEME'S OWN, = = READ FROM THE
    /// PLACE THAT WRITES IT.** = `CSSearchDomain` builds the id, = so
    /// the reading of it lives beside the building of it, = and the two
    /// cannot drift apart. = A docId without the prefix names a
    /// chapter, = not a reference, = and this answer is about
    /// references.
    static func referenceID(ofDocID docID: String) -> UUID? {
        guard docID.hasPrefix(CSSearchDomain.referenceDocIdPrefix) else { return nil }
        let uuidText = String(docID.dropFirst(CSSearchDomain.referenceDocIdPrefix.count))
        return UUID(uuidString: uuidText)
    }
}
