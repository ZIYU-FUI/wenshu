//
//  LibraryFullTextSearchView.swift
//
//  The library's full-text hits, for the search field in the assets
//  column.
//
//  Why: the assets column's search field filters the CARDS (= the
//  entities the user sees, by title, summary and pinyin). That is
//  the right filter for the grid, but it cannot reach the two things
//  a user actually remembers about a document they imported: the
//  layer it landed in (= the raw layer holds the original, = and the
//  grid never shows those), and a word in its BODY. So a document
//  the user imported last month and whose title they do not
//  remember was unreachable.
//
//  What: the hits, and only the hits. The grid below keeps filtering
//  the way it did (= no behaviour change for the cards); this sits
//  above it and says what the search found in the library's own
//  documents. A hit in the raw layer says so, because a document in
//  a layer the user cannot browse is a different thing from one they
//  can.
//
//  Timing: the bodies are files, so the search runs off the main
//  actor in a `.task(id:)` keyed on the query (= a keystroke starts
//  a new search; = the old one's result is discarded).
//

import SwiftUI

/// The library's full-text hits for the current search field.
struct LibraryFullTextSearchView: View {
    /// The search field's text (= the same text the grid filters on).
    let query: String

    /// Open a document the search found.
    let onOpen: (Reference) -> Void

    @Environment(BookStore.self) private var envBookStore

    /// The hits (= empty until the search has run).
    @State private var hits: [ReferenceLibrarySearch.Hit] = []

    /// Whether the search has run at least once (= so the view can say
    /// "nothing found" without saying it before the search started).
    @State private var hasSearched = false

    var body: some View {
        Group {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                EmptyView()
            } else {
                results()
            }
        }
        .task(id: query) {
            await search()
        }
    }

    // MARK: - The results

    private func results() -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            header
            if hits.isEmpty {
                if hasSearched {
                    Text(String(localized: "library.search.fulltext.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(hits) { hit in
                    row(hit: hit)
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingSection)
        .padding(.vertical, DesignTokens.spacingIconic)
    }

    /// The line that says what was found.
    private var header: some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.secondary)
            Text(String(localized: "library.search.fulltext.title"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(
                String(
                    localized: "library.search.fulltext.count",
                    defaultValue: "\(hits.count) 篇"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// One hit (= the document's title, the layer it is in, and the
    /// line of it that matched).
    private func row(hit: ReferenceLibrarySearch.Hit) -> some View {
        Button {
            onOpen(hit.reference)
        } label: {
            HStack(alignment: .top, spacing: DesignTokens.spacingIconic) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.reference.title)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(hit.snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                layerBadge(hit: hit)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Which layer the hit is in (= the raw layer is not browsable, =
    /// so a hit there must say so).
    private func layerBadge(hit: ReferenceLibrarySearch.Hit) -> some View {
        let label = hit.isInAVisibleLayer
            ? String(localized: "library.search.fulltext.layer_visible")
            : String(localized: "library.search.fulltext.layer_raw")
        return Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - The search

    /// Run the search, off the main actor, whenever the query changes.
    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hits = []
            hasSearched = false
            return
        }
        // The store is main-actor isolated (= its SwiftData contract
        // requires it), so the METADATA is read here (= cheap) and the
        // BODIES are read off the main actor through the store's
        // nonisolated file path (= reading N files on the main actor
        // while the user types is a frozen app).
        guard let references = try? envBookStore.loadAllReferences() else {
            hits = []
            hasSearched = true
            return
        }
        let root = envBookStore.stores.referenceLibraryRoot
        let found = await Task.detached(priority: .userInitiated) { () -> [ReferenceLibrarySearch.Hit] in
            ReferenceLibrarySearch.search(
                query: trimmed,
                references: references,
                bodyOf: { reference in
                    FileSystemReferenceStore.loadReferenceBodyFromFileSystem(
                        id: reference.id,
                        layer: reference.layer,
                        referenceLibraryRoot: root
                    )
                }
            )
        }.value
        // The query may have moved on while the search ran; a stale
        // result is worse than no result.
        guard trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        hits = found
        hasSearched = true
    }
}
