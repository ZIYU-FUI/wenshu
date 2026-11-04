//
//  ReferenceLibrarySearch.swift
//
//  The library's own search, over the library's own documents.
//
//  Why: a document the user imported is a constraint for the writing
//  that follows, and a constraint nobody can FIND is no constraint.
//  The write half was there (= the reference store publishes every
//  document to `CSSearchableIndexSearch`), but the read half was not:
//  nothing in the app could search the library, so the document the
//  user imported yesterday was reachable only by remembering its
//  title.
//
//  What: a search over the references themselves. The corpus is the
//  documents in `.ws/reference-library/<layer>/`, the body of each
//  one is its `.md` file (= the same file the editor opens), and the
//  ranking reuses `TokenOverlapRanking` (= the index's own scorer,
//  so a hit here means what a hit there means).
//
//  This is deliberately NOT the system search index. Two reasons:
//  the system index is a mirror of the session (= it is empty after a
//  relaunch until the documents are written again), and the system
//  index answers by synchronously waiting on Spotlight (= a search
//  that hangs the app when Spotlight is slow). The library's own
//  documents are on disk, so the library can answer without asking.
//
//  Layers: a search covers EVERY layer (= the raw layer holds the
//  imported originals, and those are exactly the documents a user
//  remembers importing), and a hit says which layer it came from
//  (= a hit in the raw layer is a document the user cannot see in the
//  library's grid, and a search that hid that would be a lie).
//

import Foundation

/// Search over the documents in the reference library.
enum ReferenceLibrarySearch {
    /// One document the query matched.
    struct Hit: Identifiable, Equatable {
        /// The document that matched.
        let reference: Reference

        /// A line of the document around the match (= the context the
        /// user needs to recognise it, = and NOT a promise that the
        /// document says this).
        let snippet: String

        /// How well the document matched (= the index's own score).
        let score: Double

        /// Whether the document is in a layer the user can see.
        var isInAVisibleLayer: Bool {
            reference.layer.isUserFacing
        }

        var id: UUID {
            reference.id
        }
    }

    /// The documents a query matched, best first.
    ///
    /// - Parameters:
    ///   - query: What the user typed (= empty means nothing, = and
    ///     returning every document would be a list, = not a search).
    ///   - references: The corpus (= every document in the library).
    ///   - bodyOf: The body of one document (= the caller reads the
    ///     `.md` file; = this type does no IO, = so it can be tested
    ///     without a disk).
    static func search(
        query: String,
        references: [Reference],
        bodyOf: (Reference) -> String?
    ) -> [Hit] {
        let queryTokens = TokenOverlapRanking.tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        var hits: [Hit] = []
        for reference in references {
            guard let hit = match(
                reference: reference,
                queryTokens: queryTokens,
                body: bodyOf(reference)
            ) else { continue }
            hits.append(hit)
        }
        return hits.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            // Two documents of the same score sort by title, so the
            // order does not change between runs (= the list the user
            // reads must not shuffle under them).
            return lhs.reference.title.localizedStandardCompare(rhs.reference.title) == .orderedAscending
        }
    }

    /// Match one document against the query.
    ///
    /// The title counts more than the body: the title is what the
    /// user names the document by, and a document whose title holds
    /// the query is almost certainly the one they meant.
    private static func match(
        reference: Reference,
        queryTokens: [String],
        body: String?
    ) -> Hit? {
        let titleTokens = TokenOverlapRanking.tokenize(reference.title)
        let titleScore = TokenOverlapRanking.score(queryTokens: queryTokens, docTokens: titleTokens)

        let bodyTokens = body.map { TokenOverlapRanking.tokenize($0) } ?? []
        let bodyScore = TokenOverlapRanking.score(queryTokens: queryTokens, docTokens: bodyTokens)

        guard titleScore > 0 || bodyScore > 0 else { return nil }

        let score = titleScore * 2 + bodyScore
        let snippet = self.snippet(
            for: reference,
            queryTokens: queryTokens,
            body: body,
            bodyMatched: bodyScore > 0
        )
        return Hit(reference: reference, snippet: snippet, score: score)
    }

    /// The line of the document that shows why it matched.
    private static func snippet(
        for reference: Reference,
        queryTokens: [String],
        body: String?,
        bodyMatched: Bool
    ) -> String {
        if bodyMatched, let body {
            let highlighted = TokenOverlapRanking.highlight(
                queryTokens: queryTokens,
                body: body,
                contextChars: 60
            )
            if !highlighted.isEmpty {
                return highlighted
            }
        }
        // No body, or the body did not hold the query: the title
        // matched, so the title is what the user needs to recognise
        // the document.
        return reference.title
    }
}
