//
//  ReferenceSentenceExcerpt.swift
//
//  The sentences of a document's body, = and the ones a query names.
//
//  Why: a document-level answer tells the caller WHICH document holds
//  the answer, = and not the answer. = The caller then has to open the
//  document and read it, = and the reading is the part that costs. =
//  So the retrieval has to carry the sentences themselves.
//
//  **⇒ THE GRANULARITY IS THE SENTENCE, = = AND THE RULE IS THE
//  HOUSE'S OWN.** = `WordCounter` counts a sentence at a full stop, a question mark or an exclamation mark, = and their full-width forms,
//  = and this file cuts at the same punctuation, = so a fragment here
//  and a sentence count in the editor agree about where a sentence
//  ends. = A second, different rule would make the two disagree about
//  the same text.
//
//  What: `sentences(in:)` cuts a body into sentences, = and
//  `excerpt(for:)` picks the ones a query's terms name. = The
//  selection is by TERM, = and not by position: = the sentence that
//  says the thing is the one that holds the term.
//
//

import Foundation

/// One sentence of a document's body.
struct ReferenceSentence: Equatable, Sendable {
    /// The sentence's own text (= without the trailing punctuation).
    let text: String
    /// The terms of the query this sentence holds (= the empty set =
    /// the sentence names nothing the query asked for).
    let matchedTerms: Set<String>
}

/// The sentences of a document's body.
enum ReferenceSentenceExcerpt {
    /// The house sentence boundary (= the one `WordCounter` counts at).
    ///
    /// **⇒ THE CHARACTERS ARE `Swift.Character`, = = AND THE QUALIFIER
    /// IS NOT OPTIONAL.** = The library's own model has a `Character`
    /// type (= a person in a story), = and it shadows the built-in one
    /// for every file in this target. = A bare `Character` here would
    /// be that model, = and the sentence boundary would be a type
    /// error rather than a rule.
    private static let terminators: Set<Swift.Character> = [
        "。", ".", "!", "?", "！", "？",
    ]

    /// Cut a body into its sentences.
    ///
    /// **⇒ A BODY THAT ENDS WITHOUT A PUNCTUATION STILL HAS ITS LAST
    /// SENTENCE.** = A document's last line usually has no full stop,
    /// = and dropping it would drop the document's own ending.
    ///
    /// - Parameters:
    ///   - body: The document's body (= markdown).
    ///   - terms: The query's terms (= the ones a sentence is asked
    ///     about).
    /// - Returns: The sentences, = each with the terms it holds.
    static func sentences(in body: String, terms: Set<String> = []) -> [ReferenceSentence] {
        guard !body.isEmpty else { return [] }
        var out: [ReferenceSentence] = []
        var current = ""
        for character in body {
            if terminators.contains(character) {
                let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    out.append(ReferenceSentence(text: text, matchedTerms: termsHeld(in: text, terms: terms)))
                }
                current = ""
            } else {
                current.append(character)
            }
        }
        // The tail after the last terminator (= the document's own
        // last sentence, = when it has no full stop).
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            out.append(ReferenceSentence(text: tail, matchedTerms: termsHeld(in: tail, terms: terms)))
        }
        return out
    }

    /// The sentences a query names, = and the ones it does not.
    ///
    /// **⇒ THE ORDER IS THE DOCUMENT'S OWN.** = The sentences that
    /// hold the query's terms come first, = and they keep the order
    /// they have in the document, = because a reader follows the
    /// document. = **⇒ A DOCUMENT WITH NO MATCHING SENTENCE STILL
    /// ANSWERS**, = with its first sentence: = a title match is
    /// evidence too, = and returning nothing would hide the document
    /// the caller must open.
    ///
    /// - Parameters:
    ///   - body: The document's body.
    ///   - terms: The query's terms.
    ///   - limit: How many sentences to return at most.
    /// - Returns: The matching sentences, = then the document's first
    ///   sentence when none matched.
    static func excerpt(
        for body: String,
        terms: Set<String>,
        title: String? = nil,
        limit: Int = 2
    ) -> [String] {
        let sentences = self.sentences(in: body, terms: terms)
        guard !sentences.isEmpty else { return [] }
        let matching = sentences.filter { !$0.matchedTerms.isEmpty }
        guard !matching.isEmpty else {
            // **⇒ THE FIRST SENTENCE IS EVIDENCE ONLY WHEN THE TITLE
            // HELD A WORD OF THE QUESTION.** = A title match is
            // evidence, = and the document's first sentence is what the
            // reader needs to recognise it. = But a document whose
            // title holds NONE of the question's words was named by a
            // coincidence (= the ranking's own terms, = and the
            // ranking's terms include the question's glue), = and its
            // first sentence is evidence of nothing. = So the caller
            // says whether the title matched: = nil means "it did" (=
            // the older callers), = and a title that is checked here
            // means the document is only evidence if IT holds a word.
            let titleHeld: Bool
            if let title {
                titleHeld = !termsHeld(in: title, terms: terms).isEmpty
            } else {
                titleHeld = true
            }
            guard titleHeld else { return [] }
            return [sentences[0].text]
        }
        return matching.prefix(max(1, limit)).map(\.text)
    }

    /// The terms of the query that a text holds.
    ///
    /// **⇒ THE MATCH IS THE SAME TOKENIZER THE RANKING SCORED WITH, = =
    /// AND NOT A SUBSTRING OF THE TEXT.** = A term is held when the text's
    /// own tokens contain it (= = `TokenOverlapRanking.tokenize`, = = the
    /// same fold, = = the same character-level CJK rule).
    /// ⇒⇒⇒ WHY THIS IS THE RULE: = = a substring match lights a sentence up
    /// for a word the ranking never scored (= = the term "ass" held by
    /// "assembly", = = the term "min" held by "dominion"), = = and the
    /// fragment then cites evidence the answer did not use. = **⇒ A TERM
    /// THAT IS ONLY A PIECE OF A LONGER WORD IS NOT HELD, = = AND A CHINESE
    /// TERM IS HELD AS THE SINGLE CHARACTER THE RANKING NAMED.**
    private static func termsHeld(in text: String, terms: Set<String>) -> Set<String> {
        guard !terms.isEmpty else { return [] }
        return terms.intersection(TokenOverlapRanking.tokenize(text))
    }
}
