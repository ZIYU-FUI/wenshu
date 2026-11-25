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

@Suite("Spotlight index writer")
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
            await SpotlightIndexReadiness.check(token: older).isReady,
            "the first write must be in the system index (= the control arm: if this fails, nothing below means anything)"
        )

        try await CSSearchableIndexSearch.shared.index(
            docId: docId, title: "Harbor survey", body: "The \(newer) tide gauge."
        )

        // One docId answers with one body: the newest one written.
        #expect(
            await SpotlightIndexReadiness.check(token: newer).isReady,
            "re-indexing a docId must put the new body into the system index"
        )
        // The old body is the one that went away (= a replacement, not an
        // addition, and not a disappearance of the document).
        let stale = await SpotlightIndexReadiness.check(token: older)
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
        let documents = [
            Self.document(first, "harbour notes \(token)"),
            Self.document("spotlight-writer-probe-mid", "customs board"),
            Self.document(last, "lighthouse log \(token)"),
        ]
        defer { Self.clean(docIds: documents.map(\.docId)) }

        let cursor = try await CSSearchableIndexSearch.shared.writer.donate(documents)
        #expect(cursor.committedCount == documents.count)

        // Readiness is asked of the LAST document, = which is the arm that
        // proves the whole run committed and not only its first chunk.
        let answer = await SpotlightIndexReadiness.check(
            token: token,
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
        let answer = await SpotlightIndexReadiness.check(
            token: Self.marker(),
            timeout: SpotlightIndexWriter.donationReadinessTimeout
        )
        #expect(!answer.isReady, "an unwritten token must not read as ready (= got \(answer))")
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
