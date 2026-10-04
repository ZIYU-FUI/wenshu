//
//  SpotlightOps.swift · Wenshu · v2.8a ticket T7 (boss 2026-09-28 OOB)
//
//  Spotlight search operation layer (= the bridge between the
//  SpotlightSearchSheet SwiftUI view and the CSSearchableIndexSearch
//  actor that owns the search store).
//
//  rendering surfaces; business rules (= query validation,
//  result formatting, error mapping) live in a @MainActor enum
//  with static funcs. SpotlightOps is the right-side enum for
//  the Cmd-F ⌘F search surface.
//
//  Apple HIG search contract:
//    - Empty query → empty result array (= don't ask Spotlight
//      for an empty-string search; = token-overlap fallback
//      returns no rows).
//    - Query trimmed before dispatch (= the user typing '   '
//      should NOT trigger a Spotlight call).
//    - Result format = (docId, snippet, rank, line) =
//      `CSSearchResult` is the canonical return shape (= the
//      `CSSearchableIndexSearch.search(query:limit:)` actor
//      contract is 1:1 preserved).
//
//  Standards axis:
//    S1 (Apple-API-first): uses CoreSpotlight (= macOS 27 builtin;
//        = no third-party deps; = zero SPM dependency).
//    S3 (single source of truth for search): CSSearchableIndexSearch
//        = the one and only search seam; = SpotlightOps never
//        re-implements the query or ranking logic.
//    S5 (no private types the rest of the app needs): all return
//        types are public (= CSSearchResult is shared with the
//        actor contract).

import Foundation
import SwiftUI

/// Spotlight search operation layer (= @MainActor static funcs
/// per the v1.74 MVVM split pattern in §11.10).
@MainActor
enum SpotlightOps {

    /// One Spotlight result row (= the canonical shape for the
    /// Cmd-F ⌘F sheet view). Differs from `CSSearchResult` only
    /// in that the snippet has been HTML-stripped (= the raw
    /// CSSearchResult wraps <mark>...</mark>; = the SwiftUI
    /// Text view doesn't render that markup natively).
    struct Row: Identifiable, Equatable, Sendable {
        let docId: String
        let title: String       // derived from docId path's last component
        let snippet: String     // HTML-stripped excerpt
        let rank: Double
        var id: String { docId }

        init(docId: String, title: String, snippet: String, rank: Double) {
            self.docId = docId
            self.title = title
            self.snippet = snippet
            self.rank = rank
        }
    }

    /// Default hit limit (= matches `CSSearchableIndexSearch.search`
    /// contract; = Apple's Spotlight API returns at most `limit`
    /// rows).
    static let defaultLimit: Int = 20

    /// Run a Spotlight search (= the canonical Cmd-F path).
    ///
    /// - Parameters:
    ///   - query: Raw user query (= trimmed internally).
    ///   - limit: Max rows to return (= default = 20).
    ///   - store: The CSSearchableIndexSearch actor (= optional
    ///     to allow tests to inject a stub; = production path
    ///     uses the default-constructed actor).
    /// - Returns: Array of `Row` (= empty for empty / whitespace
    ///   queries; = does NOT throw — Spotlight failures are
    ///   surfaced via empty results so the sheet UI doesn't
    ///   have to handle async error propagation).
    static func search(
        query: String,
        limit: Int = defaultLimit,
        store: CSSearchableIndexSearch = CSSearchableIndexSearch()
    ) async -> [Row] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let results: [CSSearchResult]
        do {
            results = try await store.search(query: trimmed, limit: limit)
        } catch {
            // Per Apple HIG Spotlight contract, transient failures
            // (= index not bootstrapped; = permission denied; =
            // query parse error) surface as empty result arrays.
            // The Cmd-F sheet UI renders the empty-state and the
            // user can retry.
            return []
        }
        return results.map { mapToRow($0) }
    }

    /// Map a `CSSearchResult` to the `Row` view-model shape
    /// (= strip `<mark>...</mark>` HTML markup; = derive title
    /// from docId path's last path component).
    static func mapToRow(_ result: CSSearchResult) -> Row {
        let stripped = stripMarkup(result.snippet)
        let title = deriveTitle(from: result.docId)
        return Row(
            docId: result.docId,
            title: title,
            snippet: stripped,
            rank: result.rank
        )
    }

    /// Strip Apple Spotlight `<mark>` markup (= the only markup
    /// `CSSearchableIndex` wraps around highlighted terms).
    /// Conservative replacement: removes `<mark>` and `</mark>`
    /// tags; = leaves any other HTML markup untouched (= that
    /// would mean a malformed Spotlight response).
    static func stripMarkup(_ snippet: String) -> String {
        snippet
            .replacingOccurrences(of: "<mark>", with: "")
            .replacingOccurrences(of: "</mark>", with: "")
    }

    /// Derive a human-readable title from a docId path.
    /// Convention: docId = `<entity-type>:<uuid>:<bucket>` or a
    /// bare path; = take the last path component and trim the
    /// bucket suffix.
    static func deriveTitle(from docId: String) -> String {
        let segments = docId.split(separator: "/")
        guard let last = segments.last else { return docId }
        return String(last)
    }
}