//
//  ReferenceRankFusion.swift
//
//  How two rankings of the same documents become one ranking.
//
//  Why: the agent's corpus answer has two halves = the app's own
//  ranking (= which documents the corpus holds and how well they
//  match) = and the system index's ranking (= which documents the
//  app indexed, = and how Apple's own relevance ranked them). = **⇒
//  The two halves are MERGED, = and the merge is one rule, = because a
//  merge rule written twice is a merge rule that drifts.** = So the
//  rule lives here, = and both the agent's answer and the
//  retrieval-quality harness call it.
//
//  **⇒ THE MERGE IS BY RANK, = = AND NOT BY SCORE.** = The app's
//  score is a token-overlap sum (= a number the app computes) = and
//  the index's score is Apple's relevance (= a number the system
//  computes, = and a number the app cannot read at all = the index
//  hands back positions, = not scores). = **⇒ A rule that added the
//  two scores would be adding a number to a number that does not
//  exist**, = so the merge reads RANKS, = and a rank is the one thing
//  both halves speak.
//
//  **⇒ THE RULE IS: = A DOCUMENT TAKES THE BEST PLACE EITHER HALF
//  GAVE IT.** = The two halves are two opinions about the same
//  documents, = and a document one half put first has not been shown
//  wrong by the other half's silence.
//
//  **⇒ AND A TIE GOES TO THE DOCUMENT THE OTHER HALF ALSO RANKED.**
//  = Two documents can claim the same best place (= the corpus half's
//  first and the index half's first are different documents). = **⇒
//  The document the other half also ranked comes first, = because a
//  document two rankings name is a document two rankings agree
//  about.** = A document only one half named has no second opinion
//  to offer, = so it loses that tie to one both halves named.
//
//  **⇒ AND THE LAST TIE IS THE INDEX HALF'S OWN ORDER.** = One case
//  is left: = two documents, = the corpus half's first and the index
//  half's first, = each the other's sixth. = **⇒ Nothing in the two
//  rankings separates them, = and the index half's order is the
//  tie's answer** (= the index half is the system's own relevance
//  ranking, = and it is the half that reaches a document the app's
//  own terms never met = which is the whole reason the agent asks
//  it).
//
//  **⇒ THE CORPUS HALF'S ORDER MAY NOT LEAD THE ANSWER.** = Measured
//  on the retrieval-quality harness's own fixture, = and the measurement
//  is IN the tree as a case (= `the corpus half names more documents
//  than the answer can carry`, = which prints the twelve counts): = the
//  corpus half names every document it matched (= 19 to 41 of them) = while the
//  answer names at most eight, = so a merge that keeps the corpus
//  half's order puts every document the index half named behind all
//  of them, = and none of them reaches the agent (= measured: no
//  document only the index half named is in the answer's eight).
//  = **⇒ So the union's order has to be read off both halves' places
//  and not off one half's order**, = and the harness's union row
//  (= which calls this function) = is what holds that to a number.
//
//  **⇒ AND BOTH HALVES' DOCUMENTS MUST BE IN THE ANSWER.** = Measured
//  on that same fixture, over the answer's eight documents (= 96 slots
//  over the twelve questions): = 91% of them are documents the index
//  half named, = and 85% are documents the corpus half's own first
//  eight held. = **⇒ A rule that put one half's documents past the
//  answer's limit would not be a merge** = it would be that half's
//  answer with the other half's names appended.
//
//

import Foundation

/// The merge of two rankings of the same documents.
enum ReferenceRankFusion {
    /// Merge two rankings of the same documents into one.
    ///
    /// - Parameters:
    ///   - corpus: The app's own ranking (= best first).
    ///   - index: The system index's ranking (= best first). = A
    ///     document it does not name simply contributes nothing.
    /// - Returns: The documents of both halves, best first.
    ///
    /// **⇒ A DOCUMENT TAKES THE BEST PLACE EITHER HALF GAVE IT** (= and
    /// a tie goes to the document the other half also ranked, = and the
    /// last tie to the index half's own order). = The rule is one
    /// sentence, = and the harness measures it.
    static func merge<DocID: Hashable>(
        corpus: [DocID],
        index: [DocID]
    ) -> [DocID] {
        var corpusRank: [DocID: Int] = [:]
        var indexRank: [DocID: Int] = [:]
        for (rank, id) in corpus.enumerated() where corpusRank[id] == nil {
            corpusRank[id] = rank
        }
        for (rank, id) in index.enumerated() where indexRank[id] == nil {
            indexRank[id] = rank
        }

        // Every document either half named.
        var documents: [DocID] = []
        var seen = Set<DocID>()
        for id in corpus where seen.insert(id).inserted {
            documents.append(id)
        }
        for id in index where seen.insert(id).inserted {
            documents.append(id)
        }

        // **⇒ THE THREE KEYS ARE THE THREE PARTS OF THE RULE**, = and
        // each one is a rank (= so a document the other half did not
        // name has no rank there, = and it loses the tie to one both
        // halves named).
        return documents.sorted { lhs, rhs in
            let leftCorpus = corpusRank[lhs] ?? Int.max
            let leftIndex = indexRank[lhs] ?? Int.max
            let rightCorpus = corpusRank[rhs] ?? Int.max
            let rightIndex = indexRank[rhs] ?? Int.max

            // The best place either half gave it.
            let leftBest = min(leftCorpus, leftIndex)
            let rightBest = min(rightCorpus, rightIndex)
            if leftBest != rightBest {
                return leftBest < rightBest
            }

            // The other half's opinion of it (= the worse of its two
            // places).
            let leftOther = max(leftCorpus, leftIndex)
            let rightOther = max(rightCorpus, rightIndex)
            if leftOther != rightOther {
                return leftOther < rightOther
            }

            // The index half's own order.
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return leftCorpus < rightCorpus
        }
    }
}
