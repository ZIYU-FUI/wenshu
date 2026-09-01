// WorldOutlineView.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// Second-column card grid for a single Book's world-building entries.
// Book-private (= FCP Event metadata pattern). Per boss 2026-08-26
// OOB '卡片样式就是展示文档的重点摘要' = card shows the entry's
// summary (= 1-line description of the world's lore fact).
//
// Storage path (= per spec v5):
//   books/<book-uuid>/world/<entry-uuid>.md   <- markdown body
//   books/<book-uuid>/world.json              <- structured index
//
// The view is intentionally decoupled from WenshuLibrary = it takes
// a `WorldStoring` instance + a `bookId` as parameters (= functional
// injection). BookStore singleton wiring (ticket 019) replaces this
// with @Environment injection in a followup commit.
//
// v0.26 FCP library replica spec at
// `.scratch/2026-08-26-fcp-library-replica/spec.md` ticket 008.

import SwiftUI

struct WorldOutlineView: View {
    /// The world store (= the per-book filesystem reader/writer).
    let store: WorldStoring

    /// Book id (= whose world/ folder this view shows).
    let bookId: UUID

    /// Optional selection callback (= the editor opens the chosen
    /// entry's .md body when the user clicks a card). v0.26 ships the
    /// view alone; wiring the editor is ticket 014 (LibraryProperties)
    /// + ticket 019 (BookStore) followup.
    var onSelect: ((WorldEntry) -> Void)?

    /// Optional delete callback.
    var onDelete: ((WorldEntry) -> Void)?

    @State private var entries: [WorldEntry] = []
    @State private var loadError: String?
    @State private var showCreateSheet: Bool = false

    var body: some View {
        Group {
            if let error = loadError {
                contentUnavailable(
                    title: "无法加载世界观",
                    systemImage: "exclamationmark.triangle",
                    description: error
                )
            } else if entries.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(minWidth: 280, minHeight: 200)
        .onAppear(perform: reload)
        .sheet(isPresented: $showCreateSheet) {
            WorldEntryEditorSheet(
                bookId: bookId,
                onSave: { newEntry in
                    do {
                        try store.saveEntry(newEntry, bodyMarkdown: defaultMarkdown(for: newEntry))
                        reload()
                    } catch {
                        loadError = error.localizedDescription
                    }
                }
            )
        }
    }

    // MARK: - Content views

    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)],
                spacing: 12
            ) {
                ForEach(entries) { entry in
                    WorldEntryCard(entry: entry)
                        .onTapGesture { onSelect?(entry) }
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                if let onDelete = onDelete {
                                    onDelete(entry)
                                } else {
                                    try? store.deleteEntry(id: entry.id)
                                    reload()
                                }
                            }
                        }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("这本书还没有世界观")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("新建世界观条目") { showCreateSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func reload() {
        do {
            entries = try store.loadWorld()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func defaultMarkdown(for entry: WorldEntry) -> String {
        // Per Apple HIG document convention: a new .md body starts with
        // a level-1 heading matching the entry's name. The parser
        // (Document.loadDocument) extracts the title from this H1.
        "# \(entry.name)\n\n\(entry.summary)\n"
    }

    // SwiftUI contentUnavailable shim (= avoid pinning to a specific
    // iOS-only API; macOS uses a small custom View).
    @ViewBuilder
    private func contentUnavailable(
        title: String,
        systemImage: String,
        description: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(description)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card view

private struct WorldEntryCard: View {
    let entry: WorldEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.type.icon)
                    .foregroundStyle(.tint)
                Text(entry.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.name)
                .font(.headline)
                .lineLimit(2)
            if !entry.summary.isEmpty {
                Text(entry.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // v0.30 boss 2026-09-01 OOB: card background uses
        // .glassEffect(.regular) (= Apple canonical Liquid Glass
        // card on macOS 27 Tahoe per developer.apple.com/documentation/
        // technologyoverviews/liquid-glass). .glassEffect is the
        // macOS 27 SwiftUI API (= unlike the older Material enum
        // which only adds a tint layer, .glassEffect adds the full
        // Apple Liquid Glass shape: blur + specular highlight +
        // shadow + adaptive opacity). The shape matches the card's
        // RoundedRectangle outline (= 8 PT corner radius).
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}