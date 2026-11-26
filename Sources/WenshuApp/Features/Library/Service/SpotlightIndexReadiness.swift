//
//  SpotlightIndexReadiness.swift
//
//  Whether what the writer committed can be read back.
//
//  Cut out of `SpotlightIndexWriter.swift` on 2026-11-26 when the visibility
//  bound pushed that file past the 600-LOC cap. The seam is the concern, not
//  the line count: the writer is the write transaction, this is the read that
//  reports on it, and a caller asking "did my write land" needs a different
//  instrument from a caller asking "did my delete land".
//
//  Measured (macOS 27, probed 2026-11-26), and asserted nowhere else:
//
//  - The metadata containment face `contentDescription == "*token*"c` sees a
//    batch's own write. The user-query-string face answered 0 for the same
//    token after twelve retries, so a readiness check built on that face
//    reports "not ready" for an index that was ready.
//  - Core Spotlight makes a committed write readable a little later: the
//    first readable answer landed at p50 9 ms and worst case 130 ms after the
//    write's own completion (60 rounds). It drops a replaced body on the same
//    asynchronous schedule, which is why the two questions need two loops and
//    not one `absent` that means whichever way the wind blew.
//  - An answer is per document: the containment query's hits carry each hit's
//    own `uniqueIdentifier`, so a check can insist that the document it asks
//    about is in the answer rather than some other document that happens to
//    share the word.
//
//  Related: `SpotlightIndexWriter.swift` (the write side),
//  `SpotlightIndexIdentity.swift` (the token rule and the identifier),
//  `docs/agents/2026-11-26-the-retrieval-w4-acceptance.md` (item 6).
//

import CoreSpotlight
import Foundation

// MARK: - Readiness

/// Whether what the writer committed can be read back.
///
/// **Why this is not the production read.** = `CSSearchableIndexSearch`
/// asks `CSUserQuery(userQueryString:)`, = which is a natural-language
/// question, = and that is the right face for a person typing one. = It
/// is the wrong face for "did my commit land": = for the same token
/// written through a batch, = the user-query-string face answered 0 and
/// the metadata predicate below answered 1 (= measured 2026-11-26, = after
/// twelve retries on the first face). = A readiness check built on the
/// first face would report "not ready" for an index that was ready, = and
/// that is the exact failure this file exists to remove.
///
/// **The face that is measured to see a batch's own write** is a
/// containment predicate on `contentDescription`, = the attribute the
/// entry seam fills with the document's body.
enum SpotlightIndexReadiness {
    /// How a readiness check ended.
    ///
    /// Six answers, = not a boolean: = "the document is not there", = "the index
    /// refused the question", = "the index never answered it" are three of the
    /// six, = and a reader has to act on each of them differently, = and
    /// collapsing them into `false` is how a broken indexer gets reported as an
    /// empty library.
    enum Answer: Equatable, Sendable {
        /// The index held a document whose text carries the token.
        case found
        /// The index answered, = and nothing in this domain matched.
        case absent
        /// The index refused the question.
        case failed
        /// The index did not answer in time.
        case timedOut
        /// The caller gave up before the index answered.
        case cancelled

        /// The question was not asked, = because there was nothing to ask
        /// it about (= an empty body, = or an empty corpus). = Kept apart
        /// from `.absent`, = which is an answer the index actually gave: =
        /// a reader who is told "absent" will go looking for a missing
        /// document, = and a reader who is told "not asked" will look at
        /// the corpus.
        case notChecked

        var isReady: Bool {
            self == .found
        }
    }

    /// How long either visibility loop may spend before it lets its answer
    /// stand.
    ///
    /// **Why a bound at all, = measured.** = `SpotlightQueryWait` ends on
    /// the FIRST answer the index gives, = and an index that has not
    /// finished ingesting a committed write answers "no hits" rather than
    /// "not yet". = Sixty rounds of one plain write followed by one
    /// containment read put the first readable answer at p50 9 ms and worst
    /// case 130 ms after the write's own completion. = So an `absent` read
    /// milliseconds after a successful write is a fact about the ingest
    /// queue, = not about the donation, = and the suite charged it as one:
    /// the arms `donatedCorpusIsReadable` and `emptyCorpusDoesNotWipe`, = and the
    /// control in `reIndexReplacesContent`, = went red in 5 of 25 whole-suite runs
    /// measured on the tree at `a95222dde8`, = each isolated green 10/10. = Two
    /// seconds is 15x the worst measured latency.
    ///
    /// **What the bound is not.** = It is not a retry of a refusal: =
    /// `.failed`, = `.timedOut` and `.cancelled` are the index's own
    /// answers and they come back as they arrive. = The loop retries only
    /// the one answer a queue can be behind.
    static let visibilityBound: Duration = .seconds(2)

    /// The gap between two asks inside a bound.
    static let visibilityPoll: Duration = .milliseconds(100)

    /// Ask until the document is readable, = and report `absent` only once
    /// the bound has been spent saying so.
    ///
    /// - Parameter docId: when given, = the answer is about THIS document
    ///   and not merely about the domain: = a hit counts only when its own
    ///   `uniqueIdentifier` is the one this app wrote for that docId (=
    ///   `CSSearchDomain.itemIdentifier(for:)`). = Without it the question
    ///   is a containment test, = and any other document in the domain that
    ///   carries the token answers `found` for a donation that never
    ///   landed.
    static func check(
        token: String,
        docId: String? = nil,
        timeout: Duration = SpotlightQueryWait.defaultTimeout,
        visibilityBound bound: Duration = visibilityBound
    ) async -> Answer {
        await loop(
            token: token,
            docId: docId,
            timeout: timeout,
            bound: bound,
            waitingFor: .appearing
        )
    }

    /// Ask until the token has STOPPED being readable, = and report `found`
    /// only once the bound has been spent saying so.
    ///
    /// **Why this is a separate face.** = `check` re-asks while the answer
    /// is `absent`, = which is the right loop for a write and the wrong one
    /// for a delete or a replacement: = an index that has not got round to
    /// dropping a body it committed itself to removing answers `found`, =
    /// and a loop waiting for `absent` takes that `found` as its own first
    /// word. = The question decides the loop; = the loop does not decide the
    /// answer.
    static func checkGone(
        token: String,
        docId: String? = nil,
        timeout: Duration = SpotlightQueryWait.defaultTimeout,
        visibilityBound bound: Duration = visibilityBound
    ) async -> Answer {
        await loop(
            token: token,
            docId: docId,
            timeout: timeout,
            bound: bound,
            waitingFor: .disappearing
        )
    }

    /// Which way a loop is waiting.
    enum WaitingFor {
        case appearing
        case disappearing
    }

    /// The one ask, = with no loop in it. = An arm that means to take the
    /// index's first word uses this, = and pays for the honesty.
    static func ask(
        token: String,
        docId: String? = nil,
        timeout: Duration = SpotlightQueryWait.defaultTimeout
    ) async -> Answer {
        let identifier = docId.map(CSSearchDomain.itemIdentifier(for:))
        let query = SpotlightQuery(contentToken: token)
        let outcome = await SpotlightQueryWait.awaitOutcome(
            timeout: timeout,
            start: { report in query.start(onAnswer: report) },
            cancel: { query.cancel() }
        )
        switch outcome {
        case .answered:
            if let identifier {
                return query.hits.contains { $0.uniqueIdentifier == identifier }
                    ? .found : .absent
            }
            return query.hits.isEmpty ? .absent : .found
        case .failed: return .failed
        case .timedOut: return .timedOut
        case .cancelled: return .cancelled
        }
    }

    /// Both faces are this one loop, = with the unsettled answer spelled by
    /// `waitingFor`: = `.appearing` re-asks while the index says `absent`, =
    /// `.disappearing` while it says `found`. = Every other answer ends it where
    /// it stands, = and the bound caps every ask AFTER the first ask rather than
    /// that ask itself, = so a caller's `timeout` is spent once and the bound on
    /// top of it, = and a slow queue cannot multiply it.
    private static func loop(
        token: String,
        docId: String?,
        timeout: Duration,
        bound: Duration,
        waitingFor expectation: WaitingFor
    ) async -> Answer {
        let deadline = ContinuousClock.now + bound
        var answer = await ask(token: token, docId: docId, timeout: timeout)
        while isUnsettled(answer, expectation), ContinuousClock.now < deadline {
            try? await Task.sleep(for: visibilityPoll)
            let left = deadline - ContinuousClock.now
            answer = await ask(
                token: token,
                docId: docId,
                timeout: left < timeout ? left : timeout
            )
        }
        return answer
    }

    /// The one difference between the two faces, = spelled once.
    private static func isUnsettled(_ answer: Answer, _ expectation: WaitingFor) -> Bool {
        switch expectation {
        case .appearing: return answer == .absent
        case .disappearing: return answer == .found
        }
    }
}
