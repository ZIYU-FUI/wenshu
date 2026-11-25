//
//  SpotlightIndexIdentity.swift
//
//  Which Spotlight index the app writes to, and how big one write may
//  be. One file owns both, = because they are the two numbers a reader
//  needs to write the index correctly, = and a second copy of either
//  one is how a write ends up in an index nothing reads.
//
//  The measured facts this file encodes (= macOS 27, probed 2026-11-25):
//
//  - Batching is a named-handle capability only. `beginBatch()` on the
//    shared default handle raises `Batching not supported` and aborts
//    the process (measured: signal 6, rc 134), = so a library of
//    75,000 documents cannot be donated through the default handle at
//    all. A named handle is therefore not an optimisation here, = it is
//    the only handle that can carry a donation.
//  - A named handle is NOT a separate physical store on macOS. A
//    document written through the named handle is found by a query run
//    through the default handle and vice versa, = and a domain-scoped
//    delete through one handle clears a document written through the
//    other (all four measured). So the name is what the SDK header
//    calls it (= CSSearchableIndex.h:42, "a handle for the client state
//    used with the batch API"), = not a second index to keep in sync.
//  - What that means for the migration: documents donated earlier
//    through the default handle are NOT orphaned by writing through a
//    named handle from now on. The full re-donation this change ships
//    is still required, = but for the real reason: it replaces the
//    content the same-ID write-then-delete defect destroyed, = and it
//    puts every document behind the batch path so the client state
//    becomes a single continuous cursor.
//
//  Covers:
//  - the one index name the tree writes through,
//  - the one ceiling on how many documents one write may carry.
//

import CoreSpotlight

// MARK: - The index name

/// The name of the Spotlight index the app donates through.
///
/// The tree's only definition of it. A name typed a second time at a
/// callsite is a second handle with the same name and no owner, = and
/// the next reader cannot tell which of the two the documents are in.
enum SpotlightIndexName {
    /// The app's bundle-scoped index identifier.
    ///
    /// Not `com.wenshu.docs`, = which is the *domain* every document
    /// carries inside an index (= `CSSearchDomain.domainIdentifier`), =
    /// not the name of an index. An index and a domain are different
    /// things, = and a second reader who conflates them asks the
    /// question "which index is this document in" of a string that only
    /// answers "which domain".
    static let rawValue = "com.wenshu.docs.donation"

    /// The handle a donation or a single write goes through.
    ///
    /// Created here and nowhere else: = the batch API documents that
    /// the client is responsible for keeping one `CSSearchableIndex`
    /// instance away from concurrent use (`CSSearchableIndex.h:78`), =
    /// and a handle obtained from two places makes that a convention
    /// rather than a fact. The actor that owns the write path holds the
    /// value this returns.
    static func makeHandle() -> CSSearchableIndex {
        CSSearchableIndex(name: rawValue)
    }
}

// MARK: - The batch ceiling

/// How many documents one Spotlight write may carry.
///
/// 500, = the plan's number, = and here is what was measured against
/// it rather than assumed: a plain (unbatched) write of 500 and of
/// 2,000 items both succeeded, = and a plain write of 75,010 items was
/// rejected with `CSIndexErrorDomain` code -1001. So the ceiling is
/// real, = and it sits somewhere above 2,000 for a plain write.
///
/// 500 is kept anyway, = and deliberately below the measured failure: =
/// the batch path commits its whole run at `endBatch`, = so one chunk
/// is the unit a failed donation can resume from, = and a smaller
/// chunk costs one more commit and buys a shorter retry. The app's own
/// corpus is 75,010 documents, = which is the size that produced the
/// error, = so this is not a hypothetical tail case.
enum SpotlightIndexBatch {
    static let limit = 500
}

/// The token a whole-corpus donation asks the index about, = and the rules
/// that make that question mean something.
///
/// Lives here rather than on the writer because the writer is at the file
/// cap and this is contract, = not procedure: = the name, = the ceiling and
/// the token rule are the three facts a reader needs in order to predict
/// what a donation leaves behind.
enum SpotlightReadinessToken {
    /// A word to ask the index about, chosen so that the answer is about
    /// THIS document and not about the domain. =
    ///
    /// **Why uniqueness is part of the question, = measured.** =
    /// `SpotlightQuery(contentToken:)` is a domain-wide containment test,
    /// so a token two donated documents share answers `found` on either
    /// one of them. = A corpus of markdown whose last body begins with a
    /// heading yields the token `#` — every other document in the domain
    /// answers that too, = including documents this donation never wrote,
    /// and the probe read `found` after both probe documents were deleted.
    /// = So a shared token is reported as "the question could not be
    /// asked" rather than as a pass.
    static func forCorpus(_ documents: [SpotlightIndexDocument]) -> String? {
        guard let last = documents.last else { return nil }
        let token = firstProseWord(in: last.body)
        guard !token.isEmpty else { return nil }
        let shared = documents.dropLast().contains {
            firstProseWord(in: $0.body) == token
        }
        return shared ? nil : token
    }

    /// The body's first word, with leading markdown structure skipped. =
    ///
    /// CJK text has no spaces, = so the first "word" of a Chinese body is
    /// its whole first line: = the match is a containment test, = and a
    /// long token is only a longer thing that has to survive the index's
    /// own normalisation. = Cutting at `readinessTokenLimit` keeps the
    /// question about the document's own opening characters.
    static func firstProseWord(in body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let prose = trimmed.drop(while: { $0.isWhitespace || markdownMarker($0) })
        let firstWord = prose.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first
        let candidate = firstWord.map(String.init) ?? String(prose)
        return String(candidate.prefix(readinessTokenLimit))
    }

    /// Characters that open a markdown structure rather than prose: = an
    /// ATX heading, a quote, a list bullet, a table rule, a code fence.
    /// `Swift.Character`, = spelled so: = this module owns a `Character` of
    /// its own (= a person in a book), = and the bare name would resolve to it.
    static let markdownMarkers: Set<Swift.Character> = ["#", ">", "|", "-", "*", "+", "`", "~", "•", "‣", "◦"]

    static func markdownMarker(_ character: Swift.Character) -> Bool {
        markdownMarkers.contains(character)
    }

    /// How many characters a readiness token may be.
    static let readinessTokenLimit = 24
}
