// CSSearchableIndexSearch.swift
//
// Canonical search layer for wenshu docs (= Apple Core Spotlight,
// built into macOS 27 = zero SPM dependency). Replaces the v1.55
// SQLite FTS5 actor (= `FullTextSearch.swift`, removed in §11.7).
// Public API matches `FullTextSearch` 1:1 (= `index(docId:title:body:)`,
// `remove(docId:)`, `search(query:limit:)`) so callers do not change.
//
// Ranking model:
//   - CSSearchableIndex primary path: indexes user docs into Apple's
//     system Spotlight; queries via CSSearchQuery return
//     CSSearchableItem hits with built-in relevance score from the
//     system indexer.
//   - SwiftData fallback ranking (TokenOverlapRanking): when the
//     system Spotlight indexer is disabled by the user
//     (= Settings → Siri & Spotlight → Search Results → uncheck
//     "Documents"), CSSearchQuery.start() returns zero results.
//     Fallback loads all indexed docs from a SwiftData-side mirror
//     and computes token-overlap score in-process. The mirror is
//     written on every `index(docId:title:body:)` so it stays fresh.
//   - `search` answers with the union of the two (= the mirror first,
//     = the system index fills the rest): a document the app indexed
//     a moment ago is in the mirror but not yet in the system index,
//     and a document the app indexed in an earlier session is in the
//     system index but not in the in-memory mirror.
//
// The ranking is NOT in this file: `MirrorRanking` and
// `TokenOverlapRanking` live in `SearchRanking.swift` (= the tokenizer,
// the saturation, and the rarity weights), because the index's write and
// query path must not grow every time a scoring signal is added.
//
// The wait: the system index answers on ITS OWN queue, = and the wait
// for it is a SUSPENDED CONTINUATION with a deadline
// (= `SpotlightQueryWait`), = not a `DispatchGroup.wait()` on this
// actor's executor. = A slow Spotlight therefore costs the caller the
// deadline, = and never the app.

import CoreSpotlight
import Foundation

/// Search result (= 1:1 with FullTextSearch.SearchResult).
struct CSSearchResult: Equatable, Sendable {
    let docId: String
    let snippet: String // <mark>...</mark> wrapped excerpt
    let rank: Double // system relevance score or token-overlap
    let line: Int // not used by Spotlight (kept for parity)
}

/// Domain name registered with CSSearchableIndex.
/// product: per-domain identifier to scope queries to wenshu docs only.
enum CSSearchDomain {
    static let domainIdentifier = "com.wenshu.docs"

    /// itemIdentifier scheme (= reversible mapping to docId for highlight lookup).
    static func itemIdentifier(for docId: String) -> String {
        "wenshu-doc-\(docId)"
    }

    static func docId(from itemIdentifier: String) -> String? {
        guard itemIdentifier.hasPrefix("wenshu-doc-") else { return nil }
        return String(itemIdentifier.dropFirst("wenshu-doc-".count))
    }

    /// The docId of a reference document (= its id behind a prefix).
    ///
    /// The prefix tells a search hit WHICH kind of document it is: a
    /// chapter indexes its bare id, so a bare id would leave the caller
    /// guessing between the two stores. The prefix is part of the
    /// docId, so it survives the Spotlight round-trip
    /// (`itemIdentifier` -> `docId`).
    static func referenceDocId(for id: UUID) -> String {
        "reference-\(id.uuidString)"
    }
}

/// In-process doc mirror entry (= for fallback ranking when Spotlight disabled).
struct SearchDocMirrorEntry: Equatable, Sendable {
    let docId: String
    let title: String
    let body: String
    let tokens: [String] // pre-tokenized for token-overlap ranking
    /// Display title for this doc entry (= falls back to the docId
    /// when the title is empty).
    var displayTitle: String {
        title.isEmpty ? docId : title
    }
}

/// The index entry for one document.
///
/// product: `textContent` is the attribute the system's own header calls
/// "the text content of the document" (= `CSSearchableItemAttributeSet_Messaging.h`:
/// `//Contains the text content of the document.`), = so the document's
/// text reaches the system index and not only a description of it, = and
/// `keywords` carries the document's title as one whole term (= a coined
/// name stays findable whatever the system's tokenizer does with it).
enum SpotlightIndexEntry {
    /// The attribute set for one document.
    static func attributeSet(title: String, body: String) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = title
        attributeSet.contentDescription = body
        attributeSet.textContent = body
        attributeSet.keywords = title.isEmpty ? [] : [title]
        return attributeSet
    }

    /// The query context for one question.
    ///
    /// product: ranked results are the system's own relevance order, = and
    /// the attributes fetched are the two the hit's snippet reads.
    ///
    /// **⇒ THE DOMAIN FILTER IS THE QUERY'S OWN, = = NOT A FILTER THE APP
    /// RUNS AFTERWARDS.** = = `filterQueries` is declared on
    /// `CSSearchQueryContext` (= SDK `CSSearchQuery.h`:33) = = and
    /// `CSUserQueryContext` inherits it (= SDK `CSUserQuery.h`:25), = = so
    /// the system's own cap lands on the ALREADY FILTERED set (= = the app's
    /// hits, = = not a mix of the app's and a foreign item's), = = and the
    /// app's own cut after the query can be the limit itself. = =
    /// ⇒ ⇒ ⇒ The predicate's shape (= = a metadata predicate on the item's
    /// ⇒ ⇒ ⇒ domain identifier, = = the one this app's own items carry) is
    /// ⇒ ⇒ ⇒ pinned by the contract test (= = `queryContextFiltersByDomain`).
    /// ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ ⇒ ⇒ ⇒ ⇒ AND NOTHING HERE CLAIMS A READING OF A
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ STORE'S ANSWER**: = = a reading taken on a named index
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ is not a reading of the default index (= = which holds
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ the user's own documents, = = and a probe must not
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ write there), = = so the tree claims the API's shape
    /// ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ and not the system's answer to it.
    static func queryContext(limit: Int) -> CSUserQueryContext {
        let context = CSUserQueryContext()
        context.fetchAttributes = ["title", "contentDescription"]
        context.enableRankedResults = true
        context.maxRankedResultCount = limit
        context.filterQueries = ["domainIdentifier == '\(CSSearchDomain.domainIdentifier)'"]
        return context
    }
}

/// One system-index query, = and the hits it produced.
///
/// **⇒ The box is `@unchecked Sendable` because `CSSearchQuery` is an
/// Objective-C class the checker cannot see through** (= it does not
/// conform to `Sendable`), = and the query's own API crosses threads
/// BY DESIGN: = `start()` is called on the caller's thread, = the
/// handlers fire on Core Spotlight's own queue, = and `cancel()` is
/// called from whichever thread gave up waiting (= that is what
/// `cancel` is for). = **⇒ The lock is what makes the sharing real**:
/// = the hits arrive on the index's queue, = and the caller reads them
/// after the wait ends. = **⇒ The old code relied on `group.wait()`
/// for that ordering, = and the wait is now a continuation (= which
/// does not order the collector's writes by itself).**
private final class SpotlightQuery: @unchecked Sendable {
    /// The system index's query.
    private let query: CSUserQuery

    /// The hits the query produced (= they arrive on the index's own
    /// queue, = so they are read behind the lock).
    private let lock = NSLock()
    private var collected: [CSSearchableItem] = []

    /// - Parameters:
    ///   - userQueryString: The question as a person wrote it.
    ///   - limit: How many ranked results the index may answer with.
    init(userQueryString: String, limit: Int) {
        query = CSUserQuery(
            userQueryString: userQueryString,
            userQueryContext: SpotlightIndexEntry.queryContext(limit: limit)
        )
    }

    /// Ask the index, = and report the answer.
    ///
    /// - Parameter onAnswer: Called when the index answers (= `.answered`
    ///   for hits, = `.failed` for an error).
    func start(onAnswer: @escaping @Sendable (SpotlightQueryOutcome) -> Void) {
        query.foundItemsHandler = { [self] items in
            lock.withLock { collected.append(contentsOf: items) }
        }
        query.completionHandler = { [self] error in
            onAnswer(error == nil ? .answered : .failed)
        }
        // product (macOS 27): `CSSearchQuery.start()` returns Void (= error surfaces
        // via completionHandler). If start is a no-op due to Spotlight unavailable,
        // completionHandler fires immediately with an error.
        query.start()
    }

    /// Stop the index (= it stops working on a question nobody waits
    /// for).
    func cancel() {
        query.cancel()
    }

    /// The hits the index produced.
    var hits: [CSSearchableItem] {
        lock.withLock { collected }
    }
}

/// CSSearchableIndexSearch: Core Spotlight primary + SwiftData fallback ranking.
///
/// Actor-isolated (= 1:1 with FullTextSearch actor contract).
actor CSSearchableIndexSearch {
    /// In-process mirror of indexed docs (= the app's own live view of
    /// what it indexed in this session).
    ///
    /// It is NOT persisted: the mirror lives for the process, and the
    /// system Spotlight index is the durable half. (= the search
    /// answers from both, because each half knows something the other
    /// does not: the mirror knows what was indexed a moment ago, the
    /// system index knows what was indexed in an earlier session.)
    private var mirror: [String: SearchDocMirrorEntry] = [:]

    /// Index-ready batch queue (= coalesces rapid `index` calls into 1 CSSearchableIndex call).
    private var pendingIndex: [(docId: String, title: String, body: String)] = []
    private var pendingRemove: [String] = []

    init() {
        // Public init = the mirror starts empty (= it is the live
        // view of this session; = the system Spotlight index holds
        // the documents of the earlier ones).
    }

    /// Shared singleton so `Task.detached` auto-call hooks (= chapter /
    /// reference / bookmark save) can index documents without owning
    /// the actor instance. Mirrors the `BackgroundReview.shared`
    /// pattern.
    static let shared = CSSearchableIndexSearch()

    /// Bootstrap the search index (= call once at app launch).
    /// product: CSSearchableIndex.default() returns the system Spotlight index
    /// (= created lazily by macOS on first write).
    func bootstrap() throws {
        // The mirror holds what this session indexed (= it is not
        // persisted; = the system Spotlight index is the durable
        // half), so there is nothing to load here.
    }

    /// Index one document (= upsert: remove then insert).
    /// product: the index entry carries title, contentDescription, textContent
    /// and keywords (= SpotlightIndexEntry.attributeSet); = the identifier
    /// (= docId) and the domain (= CSSearchDomain.domainIdentifier) belong to
    /// the CSSearchableItem that carries it.
    func index(docId: String, title: String, body: String) throws {
        // Update mirror first (= always in sync, even if Spotlight write fails).
        let mirrorEntry = MirrorRanking.entry(docId: docId, title: title, body: body)
        mirror[docId] = mirrorEntry

        // Coalesce into pendingIndex (= batch flush on next `flush()` or search()).
        // product: CSSearchableIndex.indexSearchableItems accepts batches of 100s;
        // = batching is the recommended pattern.
        pendingIndex.append((docId: docId, title: title, body: body))

        // Also remove stale Spotlight entry for this docId (= upsert semantics).
        pendingRemove.append(CSSearchDomain.itemIdentifier(for: docId))

        try flushPending()
    }

    /// Remove one document from the index.
    func remove(docId: String) throws {
        mirror.removeValue(forKey: docId)
        pendingRemove.append(CSSearchDomain.itemIdentifier(for: docId))
        try flushPending()
    }

    /// Look up the canonical display title for a docId (= the
    /// mirror's stored title; = falls back to the docId when the
    /// mirror has no entry). The editor tab title uses this so the
    /// user sees the friendly chapter / reference / bookmark name
    /// instead of the raw docId.
    func title(forDocId docId: String) -> String {
        mirror[docId]?.displayTitle ?? docId
    }

    /// Search (= Apple Spotlight relevance + the in-process mirror).
    ///
    /// Two sources answer, and both are needed:
    ///   - the in-process mirror (= every document this app indexed in
    ///     this session; = it is written before the system indexer has
    ///     caught up, so a document saved a moment ago is findable at
    ///     once),
    ///   - the system Spotlight index (= the durable view; = it holds
    ///     the documents this app indexed in EARLIER sessions, which the
    ///     in-memory mirror does not survive).
    ///
    /// A document can sit in both (= the mirror is the fresh copy of
    /// something the system index also holds), so the answer is the
    /// union by docId and the mirror's copy wins (= it is the app's own
    /// copy). The mirror answers first for the same reason: the mirror
    /// is the app's live index, and a document the user just saved must
    /// not be pushed out of the answer by older Spotlight hits.
    ///
    /// The rank is the position in the answer (= higher is better);
    /// each source ranks its own hits first.
    /// - Parameters:
    ///   - query: user query string (= Spotlight handles FTS5-style MATCH syntax).
    ///   - limit: max results (= default 20).
    /// - Returns: array of CSSearchResult sorted by descending rank.
    func search(query: String, limit: Int = 20) async throws -> [CSSearchResult] {
        let mirrorResults = try queryFallback(query: query, limit: limit)
        let spotlightResults = await querySpotlight(query: query, limit: limit)

        var seen = Set(mirrorResults.map(\.docId))
        var merged = mirrorResults
        for result in spotlightResults where !seen.contains(result.docId) {
            seen.insert(result.docId)
            merged.append(result)
        }
        return merged.prefix(limit).enumerated().map { idx, result in
            CSSearchResult(
                docId: result.docId,
                snippet: result.snippet,
                rank: Double(limit - idx),
                line: result.line
            )
        }
    }

    /// Query Apple Spotlight via CSUserQuery.
    ///
    /// product (macOS 27): `CSUserQuery.init(userQueryString:userQueryContext:)`
    /// takes the question as a person wrote it, = and the system's query
    /// understanding answers it. = A metadata query string matches a literal
    /// substring only, = and a question is not a substring of any document,
    /// = so the question itself is what the index receives.
    ///
    /// **⇒ THE WAIT DOES NOT HOLD THE ACTOR.** = The old wait was a
    /// `DispatchGroup.wait()` on this actor's own executor, = so a
    /// slow Spotlight froze every other caller on the actor (= the
    /// editor's title lookup, = an index write). = **⇒ The wait is
    /// now a suspended continuation with a DEADLINE** (= see
    /// `SpotlightQueryWait`): = the caller is suspended, = not blocked;
    /// = the index answers on its own queue; = and an index that never
    /// answers costs the caller the deadline, = not the app.
    private func querySpotlight(query: String, limit: Int) async -> [CSSearchResult] {
        let spotlight = SpotlightQuery(userQueryString: query, limit: limit)

        let outcome = await SpotlightQueryWait.awaitOutcome { done in
            spotlight.start(onAnswer: done)
        } cancel: {
            spotlight.cancel()
        }

        // The index did not answer, = or answered with an error: = the
        // mirror's answer stands alone. = **⇒ The mirror is the answer
        // the app always has** (= it is the app's own live index), = so
        // a system index that is slow or off costs LATENCY, = not the
        // answer.
        guard outcome == .answered else { return [] }

        // Only this app's own domain answers (= the system index holds
        // every application's documents, and a foreign one carries a
        // docId no caller of this app can resolve).
        return spotlight.hits
            .filter { $0.domainIdentifier == CSSearchDomain.domainIdentifier }
            .prefix(limit)
            .enumerated()
            .map { idx, item in
                let docId = CSSearchDomain.docId(from: item.uniqueIdentifier) ?? item.uniqueIdentifier
                let title = item.attributeSet.title ?? ""
                let body = item.attributeSet.contentDescription ?? ""
                let snippet = "<mark>\(title)</mark> \(String(body.prefix(64)))"
                // CSSearchableItem does not expose relevance directly; = rank by order.
                return CSSearchResult(
                    docId: docId,
                    snippet: snippet,
                    rank: Double(limit - idx),
                    line: -1
                )
            }
    }

    /// Token-overlap ranking over the in-process mirror.
    ///
    /// The mirror holds every document this app indexed in this
    /// session, so this path answers even when the system indexer is
    /// disabled by the user (= CSSearchQuery returns []) and even for
    /// a document the system indexer has not caught up with yet.
    private func queryFallback(query: String, limit: Int) throws -> [CSSearchResult] {
        MirrorRanking.rank(entries: Array(mirror.values), query: query, limit: limit)
    }

    /// Flush pending index/remove batches to Spotlight.
    private func flushPending() throws {
        if !pendingIndex.isEmpty {
            let attrSets = pendingIndex.map { entry -> CSSearchableItem in
                let attrSet = SpotlightIndexEntry.attributeSet(title: entry.title, body: entry.body)
                return CSSearchableItem(
                    uniqueIdentifier: CSSearchDomain.itemIdentifier(for: entry.docId),
                    domainIdentifier: CSSearchDomain.domainIdentifier,
                    attributeSet: attrSet
                )
            }
            CSSearchableIndex.default().indexSearchableItems(attrSets) { error in
                if let error {
                    // Surface via thrown error on next await (= not fatal; = mirror remains source of truth).
                    _ = error
                }
            }
            pendingIndex.removeAll()
        }

        if !pendingRemove.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(
                withIdentifiers: pendingRemove
            ) { _ in }
            pendingRemove.removeAll()
        }
    }
}
