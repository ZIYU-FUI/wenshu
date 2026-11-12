// Sources/WenshuApp/Views/Workspace/PreviewPane.swift Deferred per spec:
// ViewInspector test coverage is deferred (= the view has 3 distinct scope states
// + 3 sub-view modes; = mocking all of them exceeds a single commit's scope).
// This file is a documented deferral, not dead code. Scope model:
// -.referenceScope(category): reference library entities. nil = all, non-nil =
// that category only. -.bookScope(bookId, folderName): per-book documents.
// folderName nil = union of all 8 standard folders; folderName non-nil = that
// folder only. -.shelfScope: shelf row selected = empty state hint. -.empty:
// nothing selected = empty state hint. 3 sub- view modes (per scope): 1. Overview
// grid (= when nothing selected within a scope). 2. Category/folder-scoped grid
// (= filter active). 3. Document detail (= single card with full body).
// Double-click on a card (= the editor open action). For now, single- click
// selects. Grid uses `LazyVGrid` (= Apple standard for variable-height grid;
// matches Finder icon view style).
import AppKit
import CoreFoundation
import CryptoKit
import os
import SwiftUI

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "previewpane")

// MARK: - Sort order

/// The preview pane: the second column of the library view. It shows the
/// cards of the selected shelf, with the reference library beside them.
struct PreviewPane: View {
    @Environment(BookStore.self) var bookStore

    /// The card the user is renaming. Nil = no rename is in flight.
    @State var cardRenaming: SidebarRenamingTarget?
    @State var cardPendingDelete: SidebarPendingDelete?
    /// A local SidebarService (= the second column's reference cards need one of
    /// their own). The closures capture it for the card's `.contextMenu`.
    @State var cardService: SidebarService?

    /// The cover services the pane shares (= one set for the whole pane, so the
    /// per-card lock is shared: two clicks on the same card make ONE call, not
    /// two, and a batch run and a manual click make one call between them). It
    /// lives here rather than in the grid extension because an extension cannot
    /// hold a stored property.
    @State var coverServicesHolder: CoverPaneServices = .live()

    /// The service that makes a card's cover move (= one for the whole pane, so
    /// the per-card lock is shared: two clicks on the same card make ONE clip,
    /// not two). It lives here rather than in the grid extension because an
    /// extension cannot hold a stored property.
    @State var coverVideoServiceHolder: CoverVideoService = .live()

    /// A cached snapshot of `(shelfId → books)`, so the shelf subtree can be
    /// read without walking the library again on every cycle.
    @State var cachedShelfBooks: [UUID: [Book]] = [:]

    /// A counter bumped when the library changes on disk. SwiftUI does not
    /// re-render the grid when the file system changes, so the grid watches this
    /// counter instead.
    @State private var libraryChangeTick: Int = 0

    /// scope of documents to display. Driven by sidebar selection (=
    /// WorkspaceView computes from sidebarSelection).
    let scope: PreviewScope

    /// The card-double-click callback (= it replaces the empty NSLog
    /// placeholders). It takes the CardSource it is given, rather than
    /// `filtered.first`.
    let onDoubleClick: (CardSource) -> Void

    /// The trailing button rendered in the pane's tab bar (= the trailing slot
    /// next to the content).
    var trailingButton: AnyView?

    /// The sort order of the card grid. The default is `.pinyinFirstLetter` (= the
    /// spec), and the grid owns it.
    @Binding var previewSortOrder: EntitySortOrder

    /// The search query for the preview pane. PreviewPane owns it: an optional
    /// external binding, with the legacy internal `@State` as the nil fallback.
    @Binding var searchQuery: String?

    /// The SidebarItem.tag preview-pane filter: the active tag filter (= the
    /// user picked one, or the "all" filter, which shows all references).
    @Binding var activeTag: String?

    /// A custom search field, rendered where the pane's own search field goes:
    /// below the title and the divider, above the first card.
    var customLeadingSearch: AnyView?

    /// The legacy internal search state. It is used when `searchQuery` is nil, so
    /// the pane reads the same query either way.
    @State private var previewSearchQuery: String = ""

    /// Resolved search query used by `searchFilteredEntities`. Reads from the
    /// external Binding when present, else from the legacy internal `@State`.
    var resolvedSearchQuery: String {
        if let external = searchQuery {
            return external
        }
        return previewSearchQuery
    }

    /// Whether the pane renders its own handwritten search field. The binding
    /// still works for the unit tests and the previews.
    init(
        scope: PreviewScope,
        onDoubleClick: @escaping (CardSource) -> Void,
        previewSortOrder: Binding<EntitySortOrder>,
        searchQuery: Binding<String?> = .constant(nil),
        customLeadingSearch: AnyView? = nil,
        activeTag: Binding<String?> = .constant(nil),
        coverServices: CoverPaneServices = CoverPaneServices.live()
    ) {
        self.scope = scope
        self.onDoubleClick = onDoubleClick
        _previewSortOrder = previewSortOrder
        _searchQuery = searchQuery
        _activeTag = activeTag
        self.customLeadingSearch = customLeadingSearch
        _coverServicesHolder = State(initialValue: coverServices)
    }

    /// The width at which the pane switches to two columns. The spec says the
    /// cards display in multiple columns, two by default, and that the zone is
    /// dragged narrower to get there.
    /// The pane stays in 2-column mode.
    static let twoColumnBreakpoint: CGFloat = 350

    var body: some View {
        // The search and the toolbar sit in one top bar (see OOB.md
        // #2026-09-07).
        VStack(spacing: 0) {
            // The column's top row is the search band: the column carries
            // no title row above it.
            // Per Apple HIG / platform-default style: remove the custom top inset
            // (= `chromePaddingSectionTop` = 18 PT) and the custom bottom inset
            // (= 4 PT). The center column is the content column of a
            // NavigationSplitView; = Apple HIG macOS 27 default content column
            // rhythm places the column's first row at the natural List ScrollView
            // top margin (= NO custom padding required; = the Apple API default).
            // Per the verbatim port discipline, the previous search-field
            // `.padding(.top, 4)` (= 4 PT gap above the field) and the cards
            // column layout are preserved (= no unrelated changes). Custom
            // leading search field above the first card': render the custom
            // leading-aligned search field HERE (= at the TOP of the cards
            // column; above the first card grid) = the Apple HIG "inline search
            // field at the column top" pattern (= the canonical Mail / Notes
            // column search pattern). The previous attempt (commit 71daf8311)
            // put the search field in a wrapper HStack ABOVE PreviewPane (=
            // visually wrong = the search field rendered above the column's own
            // first row and the immediate ask was to move it). The fix = move
            // the search field into the PreviewPane body, so it sits exactly
            // where requested (= at the column's top, above the first card).
            // Only render the custom field when the caller passed one (=
            // `customLeadingSearch != nil`). Default = nil = no field (= legacy
            // callers / tests still work).
            if let customSearch = customLeadingSearch {
                // Per Apple HIG / platform-default style: render the search field
                // at the FULL column width (= the outer
                // `.frame(maxWidth:.infinity)` makes SwiftUI stretch this view to
                // consume all available horizontal space in the parent VStack; =
                // the search field now matches the LazyVGrid's full grid width; =
                // as the user drags the column wider, both the cards and the
                // search field stretch together). Why wrap with
                // `.frame(maxWidth:.infinity, alignment:.center)` (= not just
                // rely on the inner AnyView's `.frame`): SwiftUI AnyView wrappers
                // lose layout intent (= the framework can't see through them at
                // compile time; = the `customSearch` AnyView measures itself as
                // its intrinsic content size, not the parent's full width). The
                // OUTER `.frame(maxWidth:.infinity, alignment:.center)` (=
                // applied by the parent VStack that can see the column width) is
                // what forces the stretch.
                customSearch
                    // Per Apple HIG / platform-default style: use
                    // `.controlSize(.regular)` on the inner TextField (= the
                    // canonical macOS 13+ SwiftUI expression for the standard
                    // form- control height = 22 PT = matches Apple's Mail / Notes /
                    // Finder search fields = NO hard-coded `.frame(height: 30)`).
                    // Why not `.searchable`: `.searchable` is hard-wired to
                    // render in the TRAILING edge of any column toolbar (= a
                    // documented framework limitation in NavigationSplit columns
                    // = the earlier preference for a leading-positioned search
                    // field can't be satisfied). The custom TextField with
                    // `.controlSize(.regular)` gives us Apple's canonical control
                    // size + leading alignment in one package. Why not hard-code
                    // 30 PT: the explicit direction was 'don't write a hard
                    // number; = use Apple's semantic expression (=
                    // `.controlSize(.regular)`) = SwiftUI maps `.regular` to the
                    // canonical macOS 22 PT control height (= approximately 30 PT
                    // once SwiftUI's vertical padding and the surrounding HStack
                    // padding are added; = the intuition that 30 PT feels right).
                    .frame(maxWidth: .infinity, alignment: .center)
                // Per Apple HIG / platform-default style: drop the manual BOTTOM
                // padding around the search field (= the previous
                // `.padding(.bottom, 6)` was a hand- rolled vertical breathing
                // room between the search field and the first card; = removing it
                // makes the search field sit flush against the first card below;
                // = the cards' own LazyVGrid spacing controls the gap to the next
                // card). Per Apple HIG / platform-default style: per the UPDATE —
                // 'remove all custom padding and switch to Apple- standard
                // expressions — find an approximate value': REMOVE both
                // `.padding(.top, 4)` (= 4 PT divider→search gap) and
                // `.padding(.horizontal, 8)` (= 8 PT horizontal inset). The Apple
                // HIG macOS 27 default layout for an inline search field within a
                // content column places the field at natural SwiftUI default
                // spacing (= NO custom padding required; = the canonical Mail /
                // Notes column search pattern).
            }
            // Per Apple HIG platform availability: use the platform's own search
            // field, rather than a hand-rolled one (= the previous internal
            // search bar was removed). The search field now lives at the parent
            // level, attached to the shell's middle column.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                scopeGroup
                    // Cards fade in on sidebar tap (= no-flicker-stutter): the
                    // scope Group gets a stable per-scope identity (=
                    // `.id(scope)`) so SwiftUI treats each scope switch as a full
                    // subtree unmount / mount; = the matching `.transition` below
                    // plays the scope-switch entry animation. The animation is
                    // triggered by the parent `.onChange(of: scope)` wrapping the
                    // state mutation in `withAnimation(.smooth)` (= SwiftUI's
                    // structural transitions only animate when the change is
                    // wrapped in a withAnimation block; = without it the
                    // transition is instant and identical to the unfindable
                    // legacy behavior).
                    .id(scope)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                Spacer(minLength: 0)
            }
            // The body's horizontal padding (see OOB.md #2026-09-08).
            .padding(.horizontal, DesignTokens.spacingModerate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .wenshuLibraryDidChange)) { _ in
            libraryChangeTick &+= 1
        }
        // Cards fade in on sidebar tap (= no-flicker-stutter, the scope-switch
        // entry animation). The value-based `.animation` modifier is attached to
        // the body root: the state mutation lives outside this view, so a change
        // wrapped in `withAnimation` never reaches the transition, and the
        // modifier listens for the value change instead (= the reference for the
        // entry transition).
        .animation(.smooth(duration: 0.22), value: scope)
        // The right-click rename sheet (= the same `RenameItemSheet` the sidebar
        // uses). `otherReferenceTitles` is what the duplicate check reads.
        .sheet(item: $cardRenaming) { target in
            RenameItemSheet(
                originalName: target.originalName,
                otherNames: target.kind == .reference
                    ? (ensureCardService().otherReferenceTitles(excluding: target.itemId))
                    : (target.kind == .bookDoc
                        ? ensureCardService().otherBookDocTitles(excluding: target.itemId)
                        : (target.kind == .shelf
                            ? ensureCardService().otherShelfNames(excluding: target.itemId)
                            : ensureCardService().otherBookTitles(excluding: target.itemId))),
                onSave: { newName in
                    do {
                        switch target.kind {
                        case .reference:
                            try ensureCardService().renameReference(id: target.itemId, newTitle: newName)
                        case .bookDoc:
                            try ensureCardService().renameBookDoc(id: target.itemId, newTitle: newName)
                        case .shelf:
                            try ensureCardService().renameShelf(id: target.itemId, newName: newName)
                        case .book:
                            try ensureCardService().renameBook(id: target.itemId, newTitle: newName)
                        }
                        cardRenaming = nil
                        Task { await ensureCardService().reload() }
                    } catch {
                        wenshuLogger.info("[wenshu.preview] rename failed: \(String(describing: error))")
                        cardRenaming = nil
                    }
                },
                onCancel: { cardRenaming = nil }
            )
        }
        // The delete alert (= the same `.alert` the sidebar uses). Only the
        // `.reference` case fires for now (= the card menu is reference-only); =
        // the sheet/alert plumbing supports all kinds anyway (= future bookDoc
        // menu can reuse the same state).
        .alert(
            String(localized: "sidebar_delete_alert_title"),
            isPresented: Binding(
                get: { cardPendingDelete != nil },
                set: {
                    if !$0 {
                        cardPendingDelete = nil
                    }
                }
            ),
            presenting: cardPendingDelete
        ) { target in
            Button(String(localized: "sidebar_context_menu_delete"), role: .destructive) {
                do {
                    switch target.kind {
                    case .reference:
                        try ensureCardService().deleteReference(id: target.itemId)
                    case .bookDoc:
                        try ensureCardService().deleteBookDoc(id: target.itemId)
                    case .shelf:
                        try ensureCardService().deleteShelf(id: target.itemId)
                    case .book:
                        try ensureCardService().deleteBook(id: target.itemId)
                    }
                    cardPendingDelete = nil
                    Task { await ensureCardService().reload() }
                    // A card deleted by right-click disappears
                    // immediately.
                    NotificationCenter.default.post(
                        name: .wenshuLibraryDidChange,
                        object: nil
                    )
                } catch {
                    wenshuLogger.info("[wenshu.preview] delete failed: \(String(describing: error))")
                    cardPendingDelete = nil
                }
            }
            Button(String(localized: "auto.shared.cancel"), role: .cancel) {
                cardPendingDelete = nil
            }
        } message: { target in
            Text(String(localized: "sidebar_delete_alert_message")
                .replacingOccurrences(of: "%@", with: target.itemName))
        }
    }

    /// The preview-pane search bar (= 30 PT tall, matching the pattern the other
    /// columns use).
    @ViewBuilder
    private var scopeGroup: some View {
        switch scope {
        case let .referenceScope(category):
            referenceScopeView(category: category)
        case let .tagScope(tag):
            referenceScopeView(category: nil, tagOverride: tag)
        case let .bookScope(bookId, folderName: folderName):
            bookScopeView(bookId: bookId, folderName: folderName)
        case let .shelfScope(shelfId):
            shelfScopeView(shelfId: shelfId)
                .id(shelfId)
                .task(id: shelfId) {
                    await loadShelfBooksAsync(shelfId: shelfId)
                }
        case .empty:
            emptyScopeView()
        }
    }

    // (referenceScopeView extracted to PreviewPaneScopeViews.swift; = see that
    // file) (Card extracted to PreviewPaneCard.swift; = see that file)
}
