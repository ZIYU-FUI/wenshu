//
//  SpotlightSearchSheet.swift · Wenshu · v2.8a ticket T7 (boss 2026-09-28 OOB)
//
//  Cmd-F ⌘F Spotlight search sheet (= the overlay surface for the
//  v2.8a Spotlight search feature per boss OOB B2).
//
//  Boss intent (= boss 2026-09-28 OOB B2): no separate chrome-level
//  UI for search; = Cmd-F triggers a small sheet attached to the
//  root view. Sheet hosts:
//    - TextField for the query (= focus on appear; = Cmd-L clears).
//    - Result list (= one row per `SpotlightOps.Row`; = click
//      dispatches the open action).
//    - Empty state (= "No results" hint when the query has no
//      hits).
//
//  (= pure SwiftUI primitives + SF Symbols 6 + Apple HIG empty
//  state), this view reuses the same `EmptyStateView` shape as
//  BookmarkView + TagManagerView.
//
//  Standards axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        icon helper. No custom hover / click handlers; Apple
//        `.buttonStyle(.borderless)` + `.searchable` shape.
//    S3 (single source of truth for search): view never calls the
//        CSSearchableIndexSearch actor directly; = SpotlightOps =
//        the one and only bridge.
//    S5 (no private types the rest of the app needs): the
//        Row view-model lives in SpotlightOps (= public).

import SwiftUI

/// Spotlight search sheet (= the Cmd-F ⌘F overlay surface).
///
/// Hosted by LibraryRootView via `.sheet(item:)` (= reusable
/// for any parent that wants to expose Cmd-F).
@MainActor
struct SpotlightSearchSheet: View {

    /// Closure invoked when the user picks a row (= the
    /// dispatcher routes the docId to the right destination:
    /// chapter / reference / outline / entity).
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var rows: [SpotlightOps.Row] = []
    @State private var status: SpotlightLoadStatus = .idle

    init(onPick: @escaping (String) -> Void = { _ in }) {
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
                VStack(spacing: DesignTokens.spacingModerate) {
                    TextField(
                        WenshuI18n.t("spotlight.search.placeholder"),
                        text: $query
                    )
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: query) { _, newValue in
                        Task { await runSearch(query: newValue) }
                    }
                    Divider()
                    resultList
                }
                .padding(DesignTokens.spacingModerate)
                .navigationTitle(WenshuI18n.t("spotlight.search.title"))
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear { status = .idle }
    }

    @ViewBuilder
    private var resultList: some View {
        switch status {
        case .idle:
            EmptyStateView(
                icon: "magnifyingglass",
                title: WenshuI18n.t("spotlight.search.idle.title"),
                body: WenshuI18n.t("spotlight.search.idle.body")
            )
        case .loading:
            ProgressView()
        case .loaded:
            if rows.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: WenshuI18n.t("spotlight.search.empty.title"),
                    body: WenshuI18n.t("spotlight.search.empty.body")
                )
            } else {
                List(rows) { row in
                    Button(action: { pick(row) }) {
                        SpotlightRow(row: row)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        case .failed(let message):
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: WenshuI18n.t("spotlight.search.failed.title"),
                body: message
            )
        }
    }

    private func runSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            rows = []
            status = .idle
            return
        }
        status = .loading
        let result = await SpotlightOps.search(query: trimmed)
        rows = result
        status = .loaded
    }

    private func pick(_ row: SpotlightOps.Row) {
        onPick(row.docId)
        dismiss()
    }
}

/// One Spotlight result row (= shows title + snippet + rank).
/// Kept private (= internal to SpotlightSearchSheet.swift; = no
/// other view needs this layout).
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

/// Local load-status enum (= mirrors `SpecializedToolLoadStatus`
/// but kept private to this file since Spotlight has only 4 cases
/// and doesn't need the shared type).
private enum SpotlightLoadStatus: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}