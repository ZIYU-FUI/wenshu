//
//  SpotlightIndexWriter.swift
//
//  The one place a document is put into the system index.
//
//  Before this file there were two: = the single-save path that wrote to
//  the default handle, = and the whole-corpus path, = which did not exist.
//  Both of the things this file is for are things two paths get wrong: =
//  the ceiling on how many documents one call may carry, = and the fact
//  that a write which deletes the same identifier it is writing erases
//  its own content.
//
//  Measured (= macOS 27, = probed 2026-11-25/26), = and asserted nowhere else:
//
//  - Batching is a NAMED-handle capability. `beginBatch()` on the default
//    handle raises `Batching not supported` and aborts the process (= signal 6).
//  - The client state is the server's own cursor, = and it survives the
//    process with no help from the app: a batch that committed
//    `wenshu-donation:1` read back as that value from a second handle built
//    from the name. = The number is what THIS run's batch committed, = not a
//    counter that accumulates across processes (measured: two separate
//    one-document batches each read back `1`).
//  - A never-batched handle reads back EMPTY (= measured), = so "no
//    cursor yet" is a distinguishable state, = not a zero.
//  - A plain write does NOT advance the cursor (= measured), = and
//    neither does a domain-scoped delete. = Hence `SpotlightDonationCursor`
//    records donation progress and nothing about freshness.
//  - A batch's documents are queryable as soon as it commits (= measured:
//    the domain-filtered content predicate returned them with no settle
//    delay), = so readiness is a question about the commit, = not about
//    waiting.
//  - A plain write of 500 and of 2,000 items both succeeded; = a plain
//    write of 75,010 was rejected (`CSIndexErrorDomain` code -1001). = The
//    ceiling is real and sits above 2,000; = `SpotlightIndexBatch.limit`
//    keeps the plan's 500, = which is below the measured failure.
//  - No item carries an `expirationDate`. = Removal is explicit, = and an
//    expiry longer than the app's launch interval would empty the index
//    for a user who has not opened it, = while a shorter one would empty
//    it between sessions.
//

import CoreSpotlight
import Foundation

// MARK: - Documents

/// One document the writer commits.
///
/// Deliberately a value, = not a store call: = enumerating the corpus
/// and writing it are two different kinds of failure, = and keeping
/// them apart is what lets a reader tell "there was nothing to write"
/// from "the writer could not read the library".
struct SpotlightIndexDocument: Equatable, Sendable {
    let docId: String
    let title: String
    let body: String
}

// MARK: - Cursor

/// The batch cursor a donation leaves behind.
///
/// **What it is:** = the number of documents the most recent donation
/// committed, = as the system stored it.
///
/// **What it is not:** = freshness. A single incremental write leaves
/// this count exactly where it was (= measured), = so a non-zero cursor
/// never means "the index matches the library". = It means "a donation
/// ran, = and this many documents went through it". = The card that
/// moves incremental refresh onto the batch path is the one that gives
/// the cursor a second meaning; = until then, = reading it as freshness
/// is the mistake this comment exists to prevent.
struct SpotlightDonationCursor: Equatable, Sendable {
    /// The stored form's marker, = so the writer and the reader cannot
    /// disagree about the prefix by typing it twice.
    static let prefix = "wenshu-donation:"

    let committedCount: Int

    init(committedCount: Int) {
        self.committedCount = committedCount
    }

    /// The stored form, = which the SDK asks to stay under 250 bytes.
    ///
    /// The marker plus a decimal count: = well under the ceiling, = and
    /// legible to a person debugging an index, = which an opaque blob is not.
    var data: Data {
        Data("\(Self.prefix)\(committedCount)".utf8)
    }

    /// Reading it back.
    ///
    /// Anything the app did not write decodes to nil, = including a
    /// state left by a different build: = the count then stays unknown
    /// rather than becoming a guess. = A never-batched handle reads back
    /// empty (= measured), = which also decodes to nil.
    init?(data: Data) {
        guard let text = String(data: data, encoding: .utf8),
              text.hasPrefix(Self.prefix),
              let count = Int(text.dropFirst(Self.prefix.count))
        else { return nil }
        self.init(committedCount: count)
    }
}

// MARK: - Failure

/// Why a write stopped.
///
/// The path this replaces swallowed every completion-handler error
/// (`_ = error`), = so a rejected write was invisible and "the index is
/// empty" could not be told apart from "the index is fine". = A failed
/// write says which stage failed and with what.
enum SpotlightIndexWriteFailure: Error, Equatable, CustomStringConvertible {
    /// Documents were rejected by the index.
    ///
    /// `batched` says whether the rejection happened inside a batch, =
    /// which is the difference between "this corpus is too big for one
    /// call" and "this handle cannot batch at all".
    case rejected(documents: Int, batched: Bool, domain: String, code: Int)
    /// A batch's commit was rejected.
    case commitRejected(chunk: Int, domain: String, code: Int)

    var description: String {
        switch self {
        case let .rejected(documents, batched, domain, code):
            "\(documents) documents rejected (\(batched ? "batched" : "plain")): \(domain) code \(code)"
        case let .commitRejected(chunk, domain, code):
            "commit of chunk \(chunk) rejected: \(domain) code \(code)"
        }
    }
}

// MARK: - The batch's transaction boundary

/// One batch at a time on one handle.
///
/// **Why this exists, = measured.** = `beginBatch()` and `endBatch` are a
/// transaction on a `CSSearchableIndex` instance, = and an `actor`'s
/// isolation does not span a transaction: = the actor yields at every
/// `await`, = so a second caller can reach `beginBatch()` while the
/// first transaction is still open. = When that happened here the second
/// `beginBatch` raised an Objective-C exception, = Swift's `try` cannot
/// catch one, = and the test process aborted with signal 6 (= the raise
/// measured in `SpotlightIndexWriter.write` when the save path was
/// batched, = and again with two donations running concurrently). = So
/// the transaction needs a lock that SUSPENDS, = and it cannot be the
/// actor's own isolation.
///
/// **What it guarantees, = and what it does not.** = Two holders are
/// serialised. = A holder that is cancelled while it holds the gate does
/// not release it, = which would leak the batch open forever; = the
/// release below happens on every path that returns or throws, = and the
/// `defer` in `donate` is what makes that true.
actor SpotlightIndexBatchGate {
    private var held = false
    private var queue: [CheckedContinuation<Void, Never>] = []

    /// Take the gate, = waiting if another transaction is open.
    func acquire() async {
        if held {
            await withCheckedContinuation { queue.append($0) }
        }
        held = true
    }

    /// Give the gate back, = handing it to the next waiter if there is one.
    func release() {
        guard held else { return }
        if queue.isEmpty {
            held = false
        } else {
            let next = queue.removeFirst()
            next.resume()
        }
    }
}

// MARK: - The writer

/// The one place a document is put into the system index.
///
/// Holds the handle rather than taking one per call, = because the SDK
/// makes the caller responsible for keeping a `CSSearchableIndex`
/// instance away from concurrent use (`CSSearchableIndex.h`:78), = and
/// "the caller is responsible" is only a fact if there is one instance
/// to be responsible for. = `actor CSSearchableIndexSearch` owns the
/// only one and is what serialises these calls.
/// `@unchecked Sendable` because `CSSearchableIndex` is an Objective-C
/// class the checker cannot see through, = and the SDK documents the
/// sharing rule for it: = "the client takes responsibility for
/// protecting the `CSSearchableIndex` instance from concurrent access"
/// (`CSSearchableIndex.h`:78). = This port discharges that
/// responsibility by giving the instance to one actor
/// (`CSSearchableIndexSearch`), = which is the only production owner of
/// one, = and every call through it is therefore already serialised. =
/// The exception is the same one `SpotlightQuery` and
/// `SpotlightQueryWait`'s gate make for the read side of this framework.
struct SpotlightIndexWriter: @unchecked Sendable {
    private let index: CSSearchableIndex

    /// The transaction boundary every batch passes through.
    private let gate = SpotlightIndexBatchGate()

    /// - Parameter index: the handle to write through. = Defaulted to
    ///   `SpotlightIndexName.makeHandle()`, = the tree's only creator of
    ///   a handle, = so a test that wants its own index can pass one and
    ///   a production caller cannot make a second handle by accident.
    init(index: CSSearchableIndex = SpotlightIndexName.makeHandle()) {
        self.index = index
    }

    /// Write documents, = in chunks of at most `SpotlightIndexBatch.limit`.
    ///
    /// **This path is plain, = and it is plain on purpose.** = The batch
    /// was here, = and it was removed after it was measured aborting the
    /// test process (signal 6, = the raise inside this function): =
    /// `beginBatch()` and `endBatch` are a transaction on ONE handle, =
    /// and an actor runs another task at every `await`, = so two saves
    /// interleaved their batches on the same handle and the second
    /// `beginBatch` raised an Objective-C exception. = Swift's `try` does
    /// not catch those, = so nothing here could handle it: = a save path
    /// cannot be built on a call that can end the process. = The corpus
    /// path keeps the batch (= `donate`), = because a corpus runs once, =
    /// one after another, = and only a batch carries tens of thousands of
    /// documents at all.
    ///
    /// - Throws: `SpotlightIndexWriteFailure`.
    func write(_ documents: [SpotlightIndexDocument]) async throws {
        for chunk in Self.chunks(of: documents) {
            try await indexItems(chunk, batched: false)
        }
    }

    /// Write a whole corpus in batches, = advancing the cursor per chunk.
    ///
    /// **One donation at a time, = held by `SpotlightIndexBatchGate`.** = A
    /// batch is a transaction on the handle, = and an actor yields at every
    /// `await`, = so isolation alone does not hold one open: = a second
    /// caller that reaches `beginBatch()` while one is open raises
    /// `Batch is already open`, = an Objective-C exception `try` does not
    /// catch (= measured: the process aborts, = signal 6). = This path takes
    /// the gate for its whole duration; = the incremental save path holds no
    /// transaction at all, = so it needs no gate and cannot be poisoned by
    /// one. = `docs/agents/2026-11-26-the-retrieval-w4-acceptance.md` records
    /// which of these is measured and which is a code reading.
    ///
    /// `onCommitted` fires after each chunk's commit: = a chunk, = not a
    /// document, = because a batch has no partial answer between its
    /// `begin` and its `end`, = so a chunk is the smallest unit a resumed
    /// pass could ever trust.
    ///
    /// - Throws: `SpotlightIndexWriteFailure`.
    @discardableResult
    func donate(
        _ documents: [SpotlightIndexDocument],
        onCommitted: (SpotlightDonationCursor) -> Void = { _ in }
    ) async throws -> SpotlightDonationCursor {
        await gate.acquire()
        defer { Task { await self.gate.release() } }
        let slices = Self.chunks(of: documents)
        var committed = 0
        var chunkNumber = 0
        while chunkNumber < slices.count {
            let slice = slices[chunkNumber]
            chunkNumber += 1
            committed += slice.count

            index.beginBatch()
            try await indexItems(slice, batched: true)
            let cursor = SpotlightDonationCursor(committedCount: committed)
            try await commitBatch(cursor: cursor, chunk: chunkNumber)
            onCommitted(cursor)
        }
        return SpotlightDonationCursor(committedCount: committed)
    }

    /// What one whole-corpus donation did.
    struct DonationReport: Equatable, Sendable {
        /// Where this donation's count ended.
        let cursor: SpotlightDonationCursor?
        /// What the system reports holding.
        ///
        /// Kept apart from `cursor` on purpose: = the two are different
        /// claims. = One is what this run wrote, = the other is what the
        /// index kept after the run, = and the W4 acceptance is about the
        /// second one (= a client-state write that no one reads back is a
        /// write nobody has proved). = They should agree; = if they do
        /// not, = something outside this app moved the state.
        let storedCursor: SpotlightDonationCursor?
        /// Whether the last donated document can be read back.
        let readiness: SpotlightIndexReadiness.Answer
        /// Documents the donation committed.
        let documents: Int

        /// Whether the donation both ran and landed.
        var isReady: Bool {
            readiness.isReady
        }

        /// Whether the cursor this donation wrote is the one the system holds.
        var cursorRoundTripped: Bool {
            cursor != nil && cursor == storedCursor
        }
    }

    /// Clear the donated domain, = commit the corpus in batches, = and ask
    /// whether what landed can be read.
    ///
    /// **The clear comes first, = and it is domain-scoped.** = The library
    /// is the truth of this pass, = so a document that left the library
    /// must not stay findable; = `deleteAllSearchableItems()` would clear
    /// other apps' documents as well and reset the client state, = so it
    /// is not what this asks for.
    ///
    /// **An empty corpus is refused before the clear, = not after it.** =
    /// A donation of nothing with a wipe in front of it is a way to empty
    /// the index and report success, = which is the shape of the failure a
    /// caller gets when it could not read the library and passed on an
    /// empty list. = The report says `notChecked` and no cursor, = so the
    /// difference between "nothing to donate" and "could not donate" stays
    /// visible to whoever reads it.
    ///
    /// **Readiness asks about the LAST document, and only when that
    /// document can be named uniquely.** = The donation commits its chunks
    /// in order, = so a token that exists in no other donated document
    /// and answers anyway means the final chunk landed, = which is the
    /// last one that could have been lost. =
    ///
    /// What the check does NOT establish: = the underlying query is a
    /// domain-wide containment test, = so a token shared with any other
    /// document in the domain — including one this donation never wrote —
    /// would answer `found` without this donation having landed. = That is
    /// why `SpotlightReadinessToken.forCorpus` refuses a shared token instead of
    /// reporting a pass, = and why a heading-led corpus reads `notChecked`
    /// rather than `ready`. = A failed check does not undo the donation
    /// (the commits are durable); = it says out loud that what was written
    /// cannot be read back as this document's own.
    ///
    /// - Throws: `SpotlightIndexWriteFailure` from the clear or from a chunk.
    func donateCorpus(
        _ documents: [SpotlightIndexDocument]
    ) async throws -> DonationReport {
        guard !documents.isEmpty else {
            return DonationReport(
                cursor: nil,
                storedCursor: nil,
                readiness: .notChecked,
                documents: 0
            )
        }

        try await removeAllDonatedDocuments()
        let cursor = try await donate(documents)
        let stored = await currentCursor()

        guard let token = SpotlightReadinessToken.forCorpus(documents) else {
            return DonationReport(
                cursor: cursor,
                storedCursor: stored,
                readiness: .notChecked,
                documents: documents.count
            )
        }
        let readiness = await SpotlightIndexReadiness.check(
            token: token,
            timeout: Self.donationReadinessTimeout
        )
        return DonationReport(
            cursor: cursor,
            storedCursor: stored,
            readiness: readiness,
            documents: documents.count
        )
    }

    /// How long a donation waits for the readiness answer.
    ///
    /// Longer than a live search is allowed to take: = the question here
    /// is asked once, = after a whole corpus, = by nobody's typing.
    static let donationReadinessTimeout: Duration = .seconds(10)

    /// The cursor the server holds, = if this app wrote it.
    ///
    /// A decode failure is nil and not a crash: = an unreadable cursor
    /// is a fact about an index this build did not donate, = and the
    /// caller's answer to that is a fresh donation, = not a guess.
    func currentCursor() async -> SpotlightDonationCursor? {
        guard let data = try? await index.fetchLastClientState() else { return nil }
        return SpotlightDonationCursor(data: data)
    }

    /// Remove documents by docId.
    ///
    /// A plain delete, = awaited, = chunked at the same ceiling as a
    /// write. = Not batched, = because delete-inside-a-batch is a shape
    /// this port has not measured, = and an unmeasured claim is not a
    /// reason to change how removal commits.
    func remove(docIds: [String]) async throws {
        for chunk in Self.chunks(of: docIds.map(CSSearchDomain.itemIdentifier(for:))) {
            try await index.deleteSearchableItems(withIdentifiers: chunk)
        }
    }

    /// Remove every document in the app's own domain.
    ///
    /// Domain-scoped, = not `deleteAllSearchableItems()`: = the app's
    /// documents do not own the machine's index, = and a call that clears
    /// everything else in it is a defect waiting for a user who keeps
    /// another app's documents beside these. = It also resets the client
    /// state, = which a donation cursor that other code still holds would
    /// not survive.
    func removeAllDonatedDocuments() async throws {
        try await index.deleteSearchableItems(
            withDomainIdentifiers: [CSSearchDomain.domainIdentifier]
        )
    }

    // MARK: Plumbing

    /// The one item construction, = shared by every path through this
    /// struct, = so a donated document and a document saved one at a
    /// time cannot arrive in the index with different attributes.
    static func item(_ document: SpotlightIndexDocument) -> CSSearchableItem {
        CSSearchableItem(
            uniqueIdentifier: CSSearchDomain.itemIdentifier(for: document.docId),
            domainIdentifier: CSSearchDomain.domainIdentifier,
            attributeSet: SpotlightIndexEntry.attributeSet(
                title: document.title,
                body: document.body
            )
        )
    }

    private func indexItems(
        _ documents: [SpotlightIndexDocument],
        batched: Bool
    ) async throws {
        do {
            try await index.indexSearchableItems(documents.map(Self.item))
        } catch {
            let ns = error as NSError
            throw SpotlightIndexWriteFailure.rejected(
                documents: documents.count, batched: batched, domain: ns.domain, code: ns.code
            )
        }
    }

    private func commitBatch(
        cursor: SpotlightDonationCursor,
        chunk: Int
    ) async throws {
        do {
            try await index.endBatch(withClientState: cursor.data)
        } catch {
            let ns = error as NSError
            throw SpotlightIndexWriteFailure.commitRejected(
                chunk: chunk, domain: ns.domain, code: ns.code
            )
        }
    }

    /// Cut a collection into pieces of at most `SpotlightIndexBatch.limit`.
    ///
    /// `static` and reachable, = because the ceiling is the one rule in
    /// this file a test can check without a live index: = what matters is
    /// where the cuts fall, = and a 12,500-document corpus must never be
    /// handed to one call.
    static func chunks<T>(of items: [T]) -> [[T]] {
        guard !items.isEmpty else { return [] }
        let limit = SpotlightIndexBatch.limit
        var out: [[T]] = []
        var start = items.startIndex
        while start < items.endIndex {
            let end = min(start + limit, items.endIndex)
            out.append(Array(items[start ..< end]))
            start = end
        }
        return out
    }
}

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
    /// Four answers, = not a boolean: = "the document is not there", =
    /// "the index refused the question", = and "the index never answered
    /// it" are three different things a reader has to act on
    /// differently, = and collapsing them into `false` is how a broken
    /// indexer gets reported as an empty library.
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

    /// Ask whether one document's body is in the index.
    ///
    /// The query is the tree's own box (`SpotlightQuery`, = which is why
    /// it gained a second initialiser rather than a second collector), =
    /// and the wait is the tree's own (`SpotlightQueryWait`), = so the
    /// deadline, = the cancellation, = and the one-shot gate that keeps a
    /// continuation from resuming twice are not reinvented here.
    static func check(
        token: String,
        timeout: Duration = SpotlightQueryWait.defaultTimeout
    ) async -> Answer {
        let query = SpotlightQuery(contentToken: token)
        let outcome = await SpotlightQueryWait.awaitOutcome(
            timeout: timeout,
            start: { report in query.start(onAnswer: report) },
            cancel: { query.cancel() }
        )
        switch outcome {
        case .answered: return query.hits.isEmpty ? .absent : .found
        case .failed: return .failed
        case .timedOut: return .timedOut
        case .cancelled: return .cancelled
        }
    }
}
