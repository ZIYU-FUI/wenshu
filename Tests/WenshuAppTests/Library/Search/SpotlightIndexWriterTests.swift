//
//  SpotlightIndexWriterTests.swift
//
//  What the named-handle write path owes the library, = measured
//  against the system index and not against the app's own mirror.
//
//  The mirror is why this file has to be careful. `search(query:)`
//  answers from the mirror AND the system index (= see
//  `CSSearchableIndexSearch.search`), so a test that asks it "is this
//  document findable" can get a yes out of the mirror while the system
//  write failed completely. That is the exact blind spot the defect this
//  branch fixes lived in: the upsert deleted a document's content in the
//  system index and nothing said so, because every read path still had
//  the copy. = So the assertions below go to `SpotlightIndexReadiness`,
//  which asks the system index and nothing else.
//
//  Covers:
//  - re-indexing a docId replaces its content in the system index and
//    leaves the document there (= the upsert defect's fix, with its
//    reverse arm),
//  - a corpus written through the batch path is readable from it,
//  - the batch ceiling cuts where the plan says it cuts,
//  - the cursor's arms, = and the empty-corpus guard that keeps a wipe
//    from happening when there is nothing to write,
//  - the index name is defined once in the tree.
//

import Foundation
import Testing
@testable import WenshuApp

/// Serialized, because of a property of the system index rather than of these
/// tests: = the arms share ONE physical named index, = and a batch is a
/// TRANSACTION on it. = A plain write issued while another arm holds a batch
/// open is not late, = it is invisible until that batch commits, = and no wait
/// can shorten that. = Measured with a 501-document batch arm in this suite: =
/// 5 of 12 runs failed, = every one of them an arm reading a token another arm
/// had written inside its open batch; = serialized, = 12 of 12 pass. = The
/// visibility bound stays for what a bound is about (= ingest latency after a
/// commit), = and does not substitute for ordering.
@Suite("Spotlight index writer", .serialized)
struct SpotlightIndexWriterTests {
    /// A word no other document holds (= the marker keeps a hit here
    /// from being satisfied by anything but this test's own document).
    private static func marker() -> String {
        "zephyrine\(UUID().uuidString.prefix(8).lowercased())"
    }

    private static func document(_ docId: String, _ body: String, title: String = "Harbor survey") -> SpotlightIndexDocument {
        SpotlightIndexDocument(docId: docId, title: title, body: body)
    }

    /// A docId this test owns, = so the cleanup below cannot reach a
    /// real document.
    private static func probeDocId() -> String {
        "spotlight-writer-probe-\(UUID().uuidString)"
    }

    // MARK: - The upsert

    /// The defect: `index(docId:title:body:)` queued a delete of the very
    /// identifier it was writing, = so re-indexing a saved document
    /// destroyed it. Measured on macOS 27 before the fix: the new text
    /// was unreadable and the document was gone from the system index.
    @Test("re-indexing a docId replaces its content instead of deleting it")
    func reIndexReplacesContent() async throws {
        let docId = Self.probeDocId()
        let older = Self.marker()
        let newer = Self.marker()
        defer { Self.clean(docIds: [docId]) }

        try await CSSearchableIndexSearch.shared.index(
            docId: docId, title: "Harbor survey", body: "The \(older) tide gauge."
        )
        #expect(
            await SpotlightIndexReadiness.check(token: older, docId: docId).isReady,
            "the first write must be readable (= the control arm: if this fails, nothing below means anything)"
        )

        try await CSSearchableIndexSearch.shared.index(
            docId: docId, title: "Harbor survey", body: "The \(newer) tide gauge."
        )

        // One docId answers with one body: the newest one written.
        #expect(
            await SpotlightIndexReadiness.check(token: newer, docId: docId).isReady,
            "re-indexing a docId must put the new body into the system index"
        )
        // The old body is the one that went away (= a replacement, not an
        // addition, and not a disappearance of the document).
        //
        // The DISAPPEARING face, not the appearing one: = an index that has
        // not got round to dropping the stale body yet answers `found`, =
        // and a loop waiting for `absent` would take that `found` as its own
        // first word. = Two seconds of the same answer is the most `absent`
        // this will accept.
        let stale = await SpotlightIndexReadiness.checkGone(token: older, docId: docId)
        #expect(
            !stale.isReady,
            "a replaced body must not stay findable under the same docId (= got \(stale))"
        )
    }

    // MARK: - The batch path

    @Test("a corpus written through the batch path is readable from it")
    func donatedCorpusIsReadable() async throws {
        let first = Self.probeDocId()
        let last = Self.probeDocId()
        let token = Self.marker()
        // The token is planted in the LAST document alone. = A marker in
        // the first one too would let a read of the first chunk answer for
        // the last, = and the arm would go green either way.
        let documents = [
            Self.document(first, "harbour notes"),
            Self.document("spotlight-writer-probe-mid", "customs board"),
            Self.document(last, "lighthouse log \(token)"),
        ]
        defer { Self.clean(docIds: documents.map(\.docId)) }

        let cursor = try await CSSearchableIndexSearch.shared.writer.donate(documents)
        #expect(cursor.committedCount == documents.count)

        // Readiness is asked of the LAST document, = and asked OF IT: = the
        // token is only in its body, = and the answer is filtered to its
        // own identifier. = Three documents against a 500-item ceiling is
        // ONE chunk, = so this arm proves the batch commit is readable
        // through the production handle at the document the run finished
        // with; = the ceiling itself is `chunksRespectTheLimit`, = and what
        // a second chunk would do is `theLastChunkOfARunIsTheChunkThe
        // DonationReportsOn`.
        let answer = await SpotlightIndexReadiness.check(
            token: token,
            docId: last,
            timeout: SpotlightIndexWriter.donationReadinessTimeout
        )
        #expect(answer.isReady, "a batch commit must be readable (= got \(answer))")
    }

    @Test("the cursor a donation commits is the cursor the system holds")
    func cursorRoundTripsThroughTheIndex() async throws {
        let ids = (1 ... 3).map { _ in Self.probeDocId() }
        let documents = ids.map { Self.document($0, "harbour \(Self.marker()) measured") }
        defer { Self.clean(docIds: ids) }

        let written = try await CSSearchableIndexSearch.shared.writer.donate(documents)
        let held = await CSSearchableIndexSearch.shared.writer.currentCursor()

        // The claim W4 makes about the client state: = the value handed to
        // `endBatch` is the value the index keeps. Measured here rather
        // than asserted from the SDK's prose, = and through the production
        // handle rather than a probe's.
        #expect(written.committedCount == documents.count)
        #expect(
            held == written,
            "the cursor the batch committed must be the one `fetchLastClientState` returns (= held \(String(describing: held)), wrote \(written))"
        )
    }

    @Test("a token that was never written is reported absent, not found")
    func readinessNegativeArm() async {
        // The no-loop face, = deliberately: = this token was never written,
        // so waiting can only cost time, = and the question the arm asks is
        // "does an unwritten token read as ready", = not "when does it stop
        // doing so".
        let answer = await SpotlightIndexReadiness.ask(token: Self.marker())
        #expect(!answer.isReady, "an unwritten token must not read as ready (= got \(answer))")
    }

    // MARK: - Which document answers

    /// The containment hole, and the predicate that closes it.
    ///
    /// `SpotlightQuery(contentToken:)` is a domain-wide test: it answers
    /// "some document in this domain carries this word", and it has no way
    /// to mean "this one". A donation whose readiness rests on that answer
    /// reports ready on a document it never wrote. The closure is the hit's
    /// own identifier: the token gets the answer, and
    /// `CSSearchDomain.itemIdentifier(for:)` decides whose answer it is.
    ///
    /// The arm therefore plants the SAME token in a second document that
    /// this donation does not delete. The domain still says "found", the
    /// document says "absent", and only a check that reads identifiers can
    /// tell those two apart.
    @Test("a foreign document carrying the token cannot answer for the subject")
    func aForeignDocumentCarryingTheTokenCannotAnswerForTheSubject() async throws {
        let subject = Self.probeDocId()
        let foreign = Self.probeDocId()
        let token = Self.marker()
        let documents = [
            Self.document(subject, "harbour master \(token)"),
            Self.document(foreign, "harbour deputy \(token)"),
        ]
        defer { Self.clean(docIds: [subject, foreign]) }

        try await CSSearchableIndexSearch.shared.writer.donate(documents)

        // Both documents are in, so both faces agree.
        #expect(
            await SpotlightIndexReadiness.check(token: token, docId: subject).isReady,
            "the subject's own identifier must be in the answer"
        )

        // Take the subject out and leave the foreign one behind. The
        // domain-wide face still answers `found`, because a document that
        // carries the token is still in the domain: that is the whole of
        // the hole. The document-scoped face must not.
        try await CSSearchableIndexSearch.shared.writer.remove(docIds: [subject])

        // The foreign document's own appearance question, = and the
        // subject's disappearance question: = two loops, = because the two
        // assertions are waiting for opposite things to settle.
        let domain = await SpotlightIndexReadiness.check(token: token, docId: foreign)
        let scoped = await SpotlightIndexReadiness.checkGone(token: token, docId: subject)
        #expect(
            domain == .found,
            "the surviving foreign document must still answer the containment question (= got \(domain))"
        )
        #expect(
            scoped == .absent,
            "a token another document carries is not this document being readable (= got \(scoped))"
        )
    }

    /// Item 4's other half: full and incremental share the write path, and
    /// the donation reports on the document the run ENDED with.
    ///
    /// A 501-document corpus is two chunks (500 and 1), and the token lives
    /// in the 501st document alone, so this arm reads the final chunk: a
    /// donation that committed the first 500 and lost the last one reports
    /// `absent`. An arm that plants its marker in more than one document
    /// cannot tell those two states apart, because either of them answers
    /// the question.
    @Test("the last chunk of a run is the chunk the donation reports on")
    func theLastChunkOfARunIsTheChunkTheDonationReportsOn() async throws {
        let marker = Self.marker()
        let ids = (1 ... 501).map { _ in Self.probeDocId() }
        let documents: [SpotlightIndexDocument] = ids.enumerated().map { index, docId in
            Self.document(
                docId,
                index == ids.count - 1
                    ? "quayside manifest \(marker)"
                    : "quayside ledger \(index)"
            )
        }
        defer { Self.clean(docIds: ids) }

        let cursor = try await CSSearchableIndexSearch.shared.writer.donate(documents)
        #expect(cursor.committedCount == 501, "the run must report both chunks")

        let last = ids[ids.count - 1]
        #expect(
            await SpotlightIndexReadiness.check(
                token: marker,
                docId: last,
                timeout: SpotlightIndexWriter.donationReadinessTimeout
            ).isReady,
            "the document in the final chunk must be readable (= got the first chunk's answer instead)"
        )
    }

    // MARK: - The ceiling

    @Test("the batch ceiling cuts a corpus at 500 and never hands one call more")
    func chunksRespectTheLimit() {
        let limit = SpotlightIndexBatch.limit
        #expect(limit == 500, "the plan's ceiling is the code's ceiling")

        let pieces = SpotlightIndexWriter.chunks(of: Array(0 ..< 12501))
        #expect(pieces.count == 26)
        #expect(pieces.allSatisfy { $0.count <= limit })
        #expect(pieces.dropLast(1).allSatisfy { $0.count == limit })
        #expect(pieces.last?.count == 1)
        #expect(pieces.reduce(0) { $0 + $1.count } == 12501)

        // The edges a real corpus walks into: = nothing, = one, = exactly
        // one batch, = one over it.
        #expect(SpotlightIndexWriter.chunks(of: [Int]()).isEmpty)
        #expect(SpotlightIndexWriter.chunks(of: [1]).count == 1)
        #expect(SpotlightIndexWriter.chunks(of: Array(0 ..< limit)).count == 1)
        #expect(SpotlightIndexWriter.chunks(of: Array(0 ... limit)).count == 2)
    }

    // MARK: - The cursor

    @Test("the cursor round-trips, and what it cannot read stays unknown")
    func cursorArms() {
        #expect(SpotlightDonationCursor(committedCount: 75010).data.count < 250)
        let round = SpotlightDonationCursor(data: SpotlightDonationCursor(committedCount: 42).data)
        #expect(round?.committedCount == 42)

        // A never-batched handle reads back empty, = and a state left by
        // another build is not this app's count either: = both must decode
        // to nil, = not to zero, = because zero would claim a donation of
        // nothing ran when nothing ran at all.
        #expect(SpotlightDonationCursor(data: Data()) == nil)
        #expect(SpotlightDonationCursor(data: Data("someone-elses-state".utf8)) == nil)
        #expect(SpotlightDonationCursor(data: Data("\(SpotlightDonationCursor.prefix)".utf8)) == nil)
    }

    /// The claim this guard exists to keep false: = that an unreadable
    /// library can be reported as an empty one.
    @Test("an empty corpus is not donated, and what was there stays there")
    func emptyCorpusDoesNotWipe() async throws {
        let docId = Self.probeDocId()
        let token = Self.marker()
        defer { Self.clean(docIds: [docId]) }
        try await CSSearchableIndexSearch.shared.writer.donate([
            Self.document(docId, "quayside ledger \(token)"),
        ])

        let report = try await CSSearchableIndexSearch.shared.donate(corpus: [])
        #expect(report.documents == 0)
        #expect(report.cursor == nil, "no donation ran, so no cursor may be reported")
        #expect(report.readiness == .notChecked)
        #expect(!report.isReady)

        // The point of the refusal, = measured: = an empty list leaves the
        // content that was already there findable. = The assertions above
        // would also pass for a pass that cleared the domain and then
        // reported `0`, = and this one is what tells the two apart.
        let after = await SpotlightIndexReadiness.check(
            token: token,
            timeout: SpotlightIndexWriter.donationReadinessTimeout
        )
        #expect(after.isReady, "an empty corpus must not clear the index (= got \(after))")
    }

    /// Item 2's boundary, = measured: = the readiness question is about a
    /// document, = not about the domain.
    @Test("a token two documents share cannot answer for either one")
    func aSharedReadinessTokenIsRefused() {
        // The shape the real corpus has: = markdown bodies that all open with
        // an ATX heading, = so "the last document's first word" is not the
        // last document's at all.
        let headingLed = [
            SpotlightIndexDocument(docId: "a", title: "A", body: "# Harbour\nnotes"),
            SpotlightIndexDocument(docId: "b", title: "B", body: "# Customs\nboard"),
        ]
        #expect(
            SpotlightReadinessToken.forCorpus(headingLed) == "Customs",
            "the token is the LAST document's prose, = with leading markdown skipped"
        )

        let shared = [
            SpotlightIndexDocument(docId: "a", title: "A", body: "neap tide rises"),
            SpotlightIndexDocument(docId: "b", title: "B", body: "neap tide falls"),
        ]
        #expect(
            SpotlightReadinessToken.forCorpus(shared) == nil,
            "a token the previous document also answers must not report ready"
        )

        let unique = [
            SpotlightIndexDocument(docId: "a", title: "A", body: "seawall repairs"),
            SpotlightIndexDocument(docId: "b", title: "B", body: "neap tide falls"),
        ]
        #expect(SpotlightReadinessToken.forCorpus(unique) == "neap")

        // An empty body yields nothing to ask about, = which the report reads
        // as `notChecked` rather than as a pass or a failure.
        let blank = [SpotlightIndexDocument(docId: "a", title: "A", body: "# \n\n")]
        #expect(SpotlightReadinessToken.forCorpus(blank) == nil)
    }

    // MARK: - The name

    /// The tree's one creator of a `CSSearchableIndex` handle.
    ///
    /// Item 1 of `docs/agents/2026-11-26-the-retrieval-w4-acceptance.md`:
    /// one index handle, defined once, no second call site with a different
    /// name. = A second `CSSearchableIndex(name:)` typed at a callsite is a
    /// second handle with a name nobody owns, = and the failure it causes is
    /// invisible until the index is queried: = the documents went somewhere,
    /// = just not where the reader looks.
    ///
    /// The arm that makes this more than a formality: = write a second
    /// handle at any callsite in `Sources/` and this goes red.
    @Test("the index handle is created in exactly one place in Sources")
    func indexHandleHasOneCreator() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // .../Search
            .deletingLastPathComponent() // .../Library
            .deletingLastPathComponent() // .../WenshuAppTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // the repository root
        let sources = repoRoot.appendingPathComponent("Sources", isDirectory: true)
        let walked = try #require(
            FileManager.default.enumerator(
                at: sources,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ),
            "no Sources directory at \(sources.path) (= the test's own path arithmetic is wrong)"
        )
        var creators: [String] = []
        var scanned = 0
        for case let url as URL in walked where url.pathExtension == "swift" {
            scanned += 1
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("CSSearchableIndex(name:") {
                creators.append(url.lastPathComponent)
            }
        }
        #expect(scanned > 100, "the sweep saw \(scanned) files (= it is not walking the tree)")
        #expect(
            creators == ["SpotlightIndexIdentity.swift"],
            "the handle must be created by `SpotlightIndexName.makeHandle()` and nowhere else (= saw \(creators))"
        )
    }

    // MARK: - Cleanup

    /// Remove this test's documents from the index.
    ///
    /// Best-effort. = A failure here leaves a row behind, = and nothing
    /// expires it (= deliberately: see `SpotlightIndexWriter.swift`'s
    /// note on `expirationDate`), = which is why the docIds and the
    /// markers are both unique per run. = A leftover row can never
    /// satisfy a later run's query, = because no later run asks about
    /// this run's marker; = what it costs is a document in the system
    /// index whose title says nothing to anyone.
    private static func clean(docIds: [String]) {
        let writer = SpotlightIndexWriter()
        let gate = DispatchSemaphore(value: 0)
        Task {
            try? await writer.remove(docIds: docIds)
            gate.signal()
        }
        _ = gate.wait(timeout: .now() + 20)
    }
}
