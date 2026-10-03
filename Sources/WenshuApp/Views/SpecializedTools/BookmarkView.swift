// BookmarkView.swift · WenshuApp · v2.8a
//
// SpecializedTools pane tab 13: Bookmark Manager. Renders:
//   - Top header (= icon + tab title + active book scope +
//     bookmark count).
//   - "Add bookmark" row (= label `TextField` + add button).
//   - Bookmarks list (= one row per bookmark; shows the label +
//     target reference + delete button).
//     doc/book anchor + remove button).
//    - Empty state (= unified EmptyStateView when no state.bookmarks).
//
//  State source: `WSBookmarkRepository` (= SwiftData-backed per
//  AGENTS.md §11.4; = v0.72 SwiftData migration; =
//  WSBookmark @Model + WSBookmarkRepository = canonical store).
//
//  Per v2.4 product philosophy (= AGENTS.md §11.14): users pick
//  from closed enums, never type free text. The label input is
//  the one exception (= a bookmark label is by definition a
//  free-text user choice; = not a system-defined behavior).
//
//  Standards-axis:
//    S1 (Apple-API-first): pure SwiftUI primitives + SF Symbols 6
//        icon helper. No custom hover / click handlers; Apple
//        `.buttonStyle(.borderless)` + Apple HIG-native empty state.
//    S3 (single source of truth for persistence): the SwiftData
//        repository owns the @Model context; the view reads /
//        mutates the repository and never touches the file
//        system or the model context directly.
//    S5 (no private types the rest of the app needs): the
//        Bookmark domain type + WSBookmark @Model +
//        WSBookmarkRepository = all public; this view holds
//        only display state.

import SwiftUI

/// SpecializedTools pane tab 13: Bookmark Manager (= v2.8a).
///
/// Reads the active bookId from `BookStore.selectedBookId`. If
/// no book is selected, renders the empty-state (= "no book
/// selected" hint, matching the ForeshadowingView no-content
/// pattern).
@MainActor
struct BookmarkView: View {

    @Environment(BookStore.self) private var bookStore

    /// Active book id (= drives the SwiftData query scope).
    private var activeBookId: UUID? { bookStore.selectedBookId }

    /// Business state mirror (= state.bookmarks + status + errorText).
    /// Form drafts stay on the View per §11.3.
    @State private var state = BookmarkViewState()

    // Add-bookmark picker state.
    @State private var draftLabel: String = ""

    /// SwiftData repository (= canonical persistence).
    /// `@MainActor` singleton lives on `WSPersistenceContainer.shared`.
    private var repository: WSBookmarkRepository {
        WSBookmarkRepository(container: WSPersistenceContainer.shared)
    }

    init() {}

    var body: some View {
        specializedToolBody(
            activeBookId: activeBookId,
            emptyContent: { emptyState },
            mainContent: { contentBody }
        )
        .task(id: activeBookId) {
            await reload()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "bookmark",
            title: WenshuI18n.t("bookmark.empty.title"),
            body: WenshuI18n.t("bookmark.empty.body")
        )
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
            header
            Divider()
            addRow
            Divider()
            listSection
            if let errorText = state.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var header: some View {
        HStack {
            SFIcon("bookmark", style: .inlineSmall, color: IconColor.tint)
            Text(WenshuI18n.t("tab.title.bookmark"))
                .font(.headline)
            Spacer()
            Text("\(state.bookmarks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var addRow: some View {
        HStack {
            TextField(
                WenshuI18n.t("bookmark.add.placeholder"),
                text: $draftLabel
            )
            .textFieldStyle(.roundedBorder)
            Button(WenshuI18n.t("bookmark.add.button")) {
                Task { await addBookmark() }
            }
            .disabled(draftLabel.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var listSection: some View {
        if state.bookmarks.isEmpty {
            Text(WenshuI18n.t("bookmark.list.empty"))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(state.bookmarks) { bookmark in
                BookmarkRow(
                    bookmark: bookmark,
                    onRemove: {
                        Task { await removeBookmark(id: bookmark.id) }
                    }
                )
            }
        }
    }

    // v2.9d: MVVM split lifted the inline reload / addBookmark /
    // removeBookmark funcs to `BookmarkOps`. The view now renders
    // the result of a single @MainActor enum call (= the canonical
    // MVVM split template).
    private func reload() async {
        let outcome = BookmarkOps.load(
            repository: repository,
            activeBookId: activeBookId
        )
        switch outcome {
        case .empty:
            state.bookmarks = []
            state.status = .loaded
        case .loaded(let rows):
            state.bookmarks = rows
            state.status = .loaded
            state.errorText = nil
        case .failed(let message):
            state.errorText = message
            state.status = .failed(message)
        }
    }

    private func addBookmark() async {
        guard let bookID = activeBookId else { return }
        let trimmed = draftLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let bookmark = BookmarkOps.add(
            repository: repository,
            label: trimmed,
            activeBookId: bookID
        )
        do {
            try repository.add(bookmark)
            draftLabel = ""
            await reload()
        } catch {
            state.errorText = String(describing: error)
        }
    }

    private func removeBookmark(id: String) async {
        let outcome = BookmarkOps.remove(
            repository: repository,
            id: id
        )
        switch outcome {
        case .empty:
            await reload()
        case .loaded:
            await reload()
        case .failed(let message):
            state.errorText = message
        }
    }
}

/// One bookmark row (= shows label + book anchor + remove
/// button). Kept private (= internal to BookmarkView.swift;
/// = no other view needs this layout).
private struct BookmarkRow: View {
    let bookmark: Bookmark
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.label)
                    .font(.body)
                Text(bookmark.docId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(action: onRemove) {
                SFIcon("trash", style: .inlineSmall, color: IconColor.tint)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, DesignTokens.spacingCaption)
    }
}