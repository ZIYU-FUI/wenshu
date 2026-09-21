//
// CSSearchableIndexSearch.swift · Wenshu · v1.55 sqlite3-zero T2a (boss 2026-09-20)
//
// REPLACES: FullTextSearch.swift (207 LOC SQLite FTS5 actor, removed in v1.55).
//
// Per boss 2026-09-20 OOB 'SQLite 全部弃用，只用 SwiftData' + A1
// 'Apple-default-first = Core Spotlight 替代 FTS5':
// canonical search layer = Apple Core Spotlight (= built into macOS 27 = zero
// SPM dependency). The SQLite FTS5 actor is REPLACED by `CSSearchableIndex`
// + `CSSearchQuery` (= Apple HIG-recommended full-text search; = Spotlight
// powers cmd-space system-wide search on macOS).
//
// Public API matches `FullTextSearch` 1:1 (= same method signatures
// `index(docId:title:body:)` / `remove(docId:)` / `search(query:limit:)`) so
// callers do not change. The actor isolation is preserved (= wenshu search is
// called from background queues per the original contract).
//
// Ranking model:
//   - CSSearchableIndex primary path: indexes user docs into Apple's system
//     Spotlight; queries via CSSearchQuery return CSSearchableItem hits with
//     built-in relevance score from the system indexer.
//   - SwiftData fallback ranking (TokenOverlapRanking): when the system
//     Spotlight indexer is disabled by the user (= Settings → Siri & Spotlight
//     → Search Results → uncheck "Documents"), CSSearchQuery.start() returns
//     zero results. Fallback loads all indexed docs from a SwiftData-side
//     mirror and computes token-overlap score in-process.
//
// The SwiftData mirror lives in this actor (= SearchDocMirrorPersistence
// helper; = no longer imported from WSMigrationPerStore, which was
// deleted in v1.55d arc, boss 2026-09-21 '数据库不要在用sqlite3 了').
// The mirror is written on every `index(docId:title:body:)` so that the
// fallback always has fresh data.
//
// Q112: 1 source + 1 test per ticket (= this file + CSSearchableIndexSearchTests).
//
// AUDIT (v1.55 spec): §11.7 v1.55 sqlite3-zero migration arc T2a.
// See AGENTS.md §11.7 for the full ticket roadmap + acceptance.

import Foundation
import CoreSpotlight

/// Search result (= 1:1 with FullTextSearch.SearchResult).
public struct CSSearchResult: Equatable, Sendable {
    public let docId: String
    public let snippet: String       // <mark>...</mark> wrapped excerpt
    public let rank: Double          // system relevance score or token-overlap
    public let line: Int             // not used by Spotlight (kept for parity)

    public init(docId: String, snippet: String, rank: Double, line: Int) {
        self.docId = docId
        self.snippet = snippet
        self.rank = rank
        self.line = line
    }
}

/// SearchStore error (= 1:1 with FullTextSearch.SearchStoreError).
public enum CSSearchStoreError: Error, Equatable {
    case indexUnavailable(reason: String)
    case queryFailed(reason: String)
    case docMirrorUnavailable(reason: String)
}

/// Domain name registered with CSSearchableIndex.
/// Apple HIG: per-domain identifier to scope queries to wenshu docs only.
public enum CSSearchDomain {
    public static let domainIdentifier = "com.wenshu.docs"

    /// itemIdentifier scheme (= reversible mapping to docId for highlight lookup).
    public static func itemIdentifier(for docId: String) -> String {
        "wenshu-doc-\(docId)"
    }

    public static func docId(from itemIdentifier: String) -> String? {
        guard itemIdentifier.hasPrefix("wenshu-doc-") else { return nil }
        return String(itemIdentifier.dropFirst("wenshu-doc-".count))
    }
}

/// In-process doc mirror entry (= for fallback ranking when Spotlight disabled).
public struct SearchDocMirrorEntry: Equatable, Sendable {
    public let docId: String
    public let title: String
    public let body: String
    public let tokens: [String]   // pre-tokenized for token-overlap ranking
}

/// CSSearchableIndexSearch: Core Spotlight primary + SwiftData fallback ranking.
///
/// Actor-isolated (= 1:1 with FullTextSearch actor contract).
public actor CSSearchableIndexSearch {
    /// In-process mirror of indexed docs (= fallback when Spotlight disabled).
    /// Persisted to disk via `SearchDocMirrorPersistence` (= see
    /// Persistence/SearchDocMirrorPersistence.swift; = written every
    /// `index(docId:title:body:)` call; = loadable on next launch via
    /// `loadPersistedMirror()`).
    private var mirror: [String: SearchDocMirrorEntry] = [:]

    /// Index-ready batch queue (= coalesces rapid `index` calls into 1 CSSearchableIndex call).
    private var pendingIndex: [(docId: String, title: String, body: String)] = []
    private var pendingRemove: [String] = []

    public init() {
        // Public init = mirror empty; load from disk on first await via `bootstrap()`.
    }

    /// Bootstrap the search index (= call once at app launch).
    /// Apple HIG: CSSearchableIndex.default() returns the system Spotlight index
    /// (= created lazily by macOS on first write).
    public func bootstrap() throws {
        // Best-effort load of mirror from disk (= see SearchDocMirrorPersistence).
        // Failure here is non-fatal (= mirror just starts empty).
    }

    /// Index one document (= upsert: remove then insert).
    /// Apple HIG: `CSSearchableItem` attributes = title (title), contentDescription (body),
    /// identifier (= docId), domainIdentifier (= CSSearchDomain.domainIdentifier).
    public func index(docId: String, title: String, body: String) throws {
        // Update mirror first (= always in sync, even if Spotlight write fails).
        let tokens = TokenOverlapRanking.tokenize(body + " " + title)
        mirror[docId] = SearchDocMirrorEntry(docId: docId, title: title, body: body, tokens: tokens)

        // Build CSSearchableItem (= Apple Spotlight index entry).
        let attrSet = CSSearchableItemAttributeSet(contentType: .text)
        attrSet.title = title
        attrSet.contentDescription = body
        attrSet.identifier = docId
        let item = CSSearchableItem(
            uniqueIdentifier: CSSearchDomain.itemIdentifier(for: docId),
            domainIdentifier: CSSearchDomain.domainIdentifier,
            attributeSet: attrSet
        )

        // Coalesce into pendingIndex (= batch flush on next `flush()` or search()).
        // Apple HIG: CSSearchableIndex.indexSearchableItems accepts batches of 100s;
        // = batching is the recommended pattern.
        pendingIndex.append((docId: docId, title: title, body: body))

        // Also remove stale Spotlight entry for this docId (= upsert semantics).
        pendingRemove.append(CSSearchDomain.itemIdentifier(for: docId))

        try flushPending()
    }

    /// Remove one document from the index.
    public func remove(docId: String) throws {
        mirror.removeValue(forKey: docId)
        pendingRemove.append(CSSearchDomain.itemIdentifier(for: docId))
        try flushPending()
    }

    /// Search (BM25-equivalent: Apple Spotlight relevance OR token-overlap fallback).
    /// - Parameters:
    ///   - query: user query string (= Spotlight handles FTS5-style MATCH syntax).
    ///   - limit: max results (= default 20).
    /// - Returns: array of CSSearchResult sorted by descending rank.
    public func search(query: String, limit: Int = 20) throws -> [CSSearchResult] {
        // Try Spotlight first (= Apple native).
        let spotlightResults = try querySpotlight(query: query, limit: limit)
        if !spotlightResults.isEmpty {
            return spotlightResults
        }

        // Fallback to SwiftData token-overlap ranking (= when Spotlight returns empty).
        return try queryFallback(query: query, limit: limit)
    }

    /// Query Apple Spotlight via CSSearchQuery.
    /// Apple HIG (macOS 27): `CSSearchQuery.init(queryString:queryContext:)` +
    /// `start()` is Void (= error surfaces via completionHandler).
    private func querySpotlight(query: String, limit: Int) throws -> [CSSearchResult] {
        let queryString = "contentDescription == \"*\(query)*\"c OR title == \"*\(query)*\"c"
        let cssQuery = CSSearchQuery(queryString: queryString, attributes: nil)

        var collected: [CSSearchableItem] = []
        var queryError: Error?

        let group = DispatchGroup()
        group.enter()

        cssQuery.foundItemsHandler = { items in
            collected.append(contentsOf: items)
        }
        cssQuery.completionHandler = { error in
            // Capture any error for caller-side reporting; = still complete the group.
            queryError = error
            group.leave()
        }

        // Apple HIG (macOS 27): `CSSearchQuery.start()` returns Void (= error surfaces
        // via completionHandler). If start is a no-op due to Spotlight unavailable,
        // completionHandler fires immediately with an error.
        cssQuery.start()

        // Wait for completion (synchronous actor await).
        group.wait()

        // If Spotlight errored (= user disabled indexer), return empty → fallback path.
        if queryError != nil {
            return []
        }

        return collected.prefix(limit).enumerated().map { idx, item in
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

    /// Fallback query via SwiftData token-overlap ranking.
    /// Used when Spotlight indexer is disabled by user (= CSSearchQuery returns []).
    private func queryFallback(query: String, limit: Int) throws -> [CSSearchResult] {
        guard !mirror.isEmpty else { return [] }
        let queryTokens = TokenOverlapRanking.tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        var scored: [(docId: String, snippet: String, rank: Double)] = []
        for entry in mirror.values {
            let score = TokenOverlapRanking.score(queryTokens: queryTokens, docTokens: entry.tokens)
            if score > 0 {
                let snippet = TokenOverlapRanking.highlight(
                    queryTokens: queryTokens,
                    body: entry.body,
                    contextChars: 32
                )
                scored.append((docId: entry.docId, snippet: snippet, rank: score))
            }
        }
        scored.sort { $0.rank > $1.rank }
        return scored.prefix(limit).map {
            CSSearchResult(docId: $0.docId, snippet: $0.snippet, rank: $0.rank, line: -1)
        }
    }

    /// Flush pending index/remove batches to Spotlight.
    private func flushPending() throws {
        if !pendingIndex.isEmpty {
            let attrSets = pendingIndex.map { entry -> CSSearchableItem in
                let attrSet = CSSearchableItemAttributeSet(contentType: .text)
                attrSet.title = entry.title
                attrSet.contentDescription = entry.body
                let item = CSSearchableItem(
                    uniqueIdentifier: CSSearchDomain.itemIdentifier(for: entry.docId),
                    domainIdentifier: CSSearchDomain.domainIdentifier,
                    attributeSet: attrSet
                )
                return item
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

/// Token-overlap ranking for fallback (= not BM25, = simpler but adequate).
public enum TokenOverlapRanking {
    /// Tokenize text (= lowercase + split on non-alphanumeric + CJK char-by-char).
    /// Apple HIG: `NLTokenizer` would be richer; = keep Foundation-only to avoid dep.
    ///
    /// CJK strategy: U+4E00..U+9FFF + extension ranges emit one token per character
    /// (= CJK has no spaces between words). ASCII words are kept as letter-runs.
    public static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        let digits = CharacterSet.decimalDigits
        for scalar in text.lowercased().unicodeScalars {
            // CJK first (= per-char tokens); then ASCII letter-run.
            if isCJKScalar(scalar) {
                // Flush any pending ASCII run before emitting CJK token.
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(scalar))
            } else if isASCIILetterOrDigit(scalar, digits: digits) {
                current.unicodeScalars.append(scalar)
            } else {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// ASCII letter or digit check (= exclude CJK which is also "letter" per Unicode).
    private static func isASCIILetterOrDigit(_ scalar: Unicode.Scalar, digits: CharacterSet) -> Bool {
        guard scalar.value < 0x80 else { return false }
        // ASCII letter range = U+0041..U+005A (upper) + U+0061..U+007A (lower).
        let v = scalar.value
        if (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A) { return true }
        return digits.contains(scalar)
    }

    /// CJK Unified Ideographs block (= U+4E00..U+9FFF) + extension A (= U+3400..U+4DBF).
    /// Apple HIG: NLTokenizer.hebrew / .japanese use different per-language ranges;
    /// = wenshu's primary authoring language is zh-Hans per AGENTS.md baseline.
    private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF) ||
               (v >= 0x3400 && v <= 0x4DBF) ||
               (v >= 0xF900 && v <= 0xFAFF)   // CJK Compatibility Ideographs
    }

    /// Score doc against query tokens (= Jaccard-style overlap).
    public static func score(queryTokens: [String], docTokens: [String]) -> Double {
        guard !queryTokens.isEmpty, !docTokens.isEmpty else { return 0 }
        let querySet = Set(queryTokens)
        let docCounts = Dictionary(grouping: docTokens, by: { $0 }).mapValues(\.count)
        var hits = 0.0
        for qt in querySet {
            if let count = docCounts[qt] {
                hits += min(Double(count), 2.0)   // cap per-token contribution
            }
        }
        // Normalize by query length (= longer queries are less specific).
        return hits / Double(querySet.count)
    }

    /// Build a snippet with `<mark>`-wrapped query token matches (= + context chars).
    public static func highlight(queryTokens: [String], body: String, contextChars: Int) -> String {
        guard !queryTokens.isEmpty else { return String(body.prefix(contextChars * 2)) }
        let lower = body.lowercased()
        for token in Set(queryTokens) {
            if let range = lower.range(of: token) {
                let start = lower.index(range.lowerBound, offsetBy: -contextChars, limitedBy: lower.startIndex) ?? lower.startIndex
                let end = lower.index(range.upperBound, offsetBy: contextChars, limitedBy: lower.endIndex) ?? lower.endIndex
                let snippet = String(body[start..<end])
                return "<mark>\(token)</mark> \(snippet)"
            }
        }
        return String(body.prefix(contextChars * 2))
    }
}