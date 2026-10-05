//
//  SpotlightInlineResults.swift · Wenshu
//
//  Apple HIG canonical Spotlight search result list (= the
//  inline overlay shown when the user is actively searching).
//
//  Migrated from SpotlightSearchSheet (= 160 lines of custom
//  sheet chrome) to Apple's `.searchable` pattern (macOS 14+;
//  = the search field renders in the trailing toolbar; = the
//  result list is a sibling overlay triggered by
//  `@Environment(\.isSearching)` on the .searchable view).
//
//  This view is the single rendering surface for the result
//  list (= replaces the inline result rendering that used to
//  live inside SpotlightSearchSheet's NavigationStack +
//  VStack + List + EmptyStateView chain).
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        icon helper + `EmptyStateView` (= Apple HIG empty state
//        primitive). The List uses `.plain` style (= Apple Mail
//        inline result list).
//    S3 (single source of truth for search): never calls the
//        CSSearchableIndexSearch actor directly; = SpotlightOps
//        = the one and only bridge (= same shape as the
//        pre-migration SpotlightSearchSheet).
//    S5 (no private types the rest of the app needs): the Row
//        view-model lives in SpotlightOps (= public).
//

import SwiftUI

/// Apple HIG canonical inline result list for the `.searchable`
/// search field (= replaced the previous custom-sheet + List
/// shape that lived inside SpotlightSearchSheet). The parent
/// view (= LibraryRootView) gates this with `isSearching` so
/// the list only appears when the user is actively searching.
@MainActor
struct SpotlightInlineResults: View {
    let rows: [SpotlightOps.Row]
    let onPick: (String) -> Void

    var body: some View {
        if rows.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: String(localized: "spotlight.search.empty.title"),
                body: String(localized: "spotlight.search.empty.body")
            )
        } else {
            List(rows) { row in
                Button(action: { onPick(row.docId) }) {
                    SpotlightRow(row: row)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

/// One Spotlight result row (= shows title + snippet + rank).
/// Private to this file (= no other view needs this layout;
/// = same scope as the pre-migration SpotlightRow).
private struct SpotlightRow: View {
    let row: SpotlightOps.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(row.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(String(format: "rank %.2f", row.rank))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }
}
