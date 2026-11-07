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
//  **⇒ And the corpus narrows by KIND and by OWNER.** = The archive
//  narrows (= by agent and by kind, = `ArchiveSettingsPane`), = and
//  the corpus did not. = The two controls sit here because this is the
//  corpus's own read surface (= the grid shows the entities layer
//  only, = so a narrowing that cannot reach the raw layer would not
//  narrow the corpus). = The kind is the corpus's own closed set
//  (`EntityType`), = and the owner is "you vs. an agent" (= the only
//  owner the second-writer rule's witness can prove, = measured
//  2026-11-07: = no producer records WHICH agent).
//
//  **⇒ The owner's answer is READ, = never assumed.** = It comes from
//  the write record (= the second-writer rule's own witness), = and
//  it is read off the main actor with the bodies. = A document whose
//  owner cannot be read is the user's (= the agent may never replace
//  text it cannot prove it wrote), = so it is not lost from the
//  user's bucket.
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

    /// The kind the corpus is narrowed to (= nil = every kind).
    @State private var kindFilter: EntityType?

    /// The owner the corpus is narrowed to (= nil = both owners).
    @State private var ownerFilter: ReferenceCorpusOwner?

    /// The narrowing the two controls currently express.
    private var narrowing: ReferenceCorpusNarrowing {
        ReferenceCorpusNarrowing(kind: kindFilter, owner: ownerFilter)
    }

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
        .task(id: narrowing) {
            await search()
        }
    }

    // MARK: - The results

    private func results() -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingIconic) {
            header
            narrowingControls
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

    /// The two narrowing controls (= the corpus's kind and owner).
    ///
    /// **⇒ The options come from the corpus, = and from the closed
    /// sets the app can prove.** = The kind is the corpus's own
    /// `EntityType` set (= 9 cases, = the vocabulary the corpus is
    /// filed under). = The owner is the two the second-writer rule's
    /// witness can prove (= "you" and "an agent"), = because no
    /// producer records which agent wrote a document (= measured
    /// 2026-11-07) = and a menu naming a role the app cannot prove is
    /// worse than no menu.
    private var narrowingControls: some View {
        HStack(spacing: DesignTokens.spacingIconic) {
            Picker(String(localized: "library.search.fulltext.filter.kind"), selection: $kindFilter) {
                Text(String(localized: "library.search.fulltext.filter.all"))
                    .tag(EntityType?.none)
                ForEach(EntityType.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(EntityType?.some(kind))
                }
            }
            Picker(String(localized: "library.search.fulltext.filter.owner"), selection: $ownerFilter) {
                Text(String(localized: "library.search.fulltext.filter.all"))
                    .tag(ReferenceCorpusOwner?.none)
                ForEach(ReferenceCorpusOwner.allCases, id: \.self) { owner in
                    Text(owner.displayName).tag(ReferenceCorpusOwner?.some(owner))
                }
            }
        }
        .font(.caption)
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
        let narrowing = narrowing
        let found = await Task.detached(priority: .userInitiated) { () -> [ReferenceLibrarySearch.Hit] in
            // **⇒ The owner's answer is read HERE, = off the main
            // actor, = and with the bodies.** = The witness is the
            // second-writer rule's own (= the write record, = or the
            // corpus copy when there is no record), = so the owner
            // axis cannot be answered by the reference itself.
            let owners = narrowing.owner == nil
                ? [:]
                : ReferenceCorpusOwnership.owners(for: references, referenceLibraryRoot: root)
            return ReferenceLibrarySearch.search(
                query: trimmed,
                references: references,
                bodyOf: { reference in
                    FileSystemReferenceStore.loadReferenceBodyFromFileSystem(
                        id: reference.id,
                        layer: reference.layer,
                        referenceLibraryRoot: root
                    )
                },
                narrowing: narrowing,
                ownerOf: { reference in owners[reference.id] }
            )
        }.value
        // The query may have moved on while the search ran; a stale
        // result is worse than no result.
        guard trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        hits = found
        hasSearched = true
    }
}
