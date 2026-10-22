// Sources/WenshuApp/Views/Workspace/PreviewPane.swift Deferred per spec: ViewInspector
// … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
// matches Finder icon view style).
import SwiftUI
import os
import CoreFoundation
import AppKit
import CryptoKit

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "previewpane")

// MARK: - Sort order
// … (= 48 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / hint
struct PreviewPane: View {
    @Environment(BookStore.self) var bookStore

    // / (= boss 2026-10-10 "没 有实现， 右键卡片 没有菜 单" + "素 材栏， 不是 tree， 是第 二栏"
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / view).
    @State var cardRenaming: SidebarRenamingTarget?
    @State var cardPendingDelete: SidebarPendingDelete?
    // / a local SidebarService (= the second column's reference cards need a
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / reference; = the closures capture it for the card's `.contextMenu`).
    @State var cardService: SidebarService?

    // / The cover services the pane shares (= one set for the whole
    // / pane, so the per-card lock is shared: = two clicks on the same
    // / card make ONE call, = not two, = and a batch run and a manual
    // / click make one call between them). = It lives here rather than in
    // / the grid extension because an extension cannot hold a stored
    // / property.
    @State var coverServicesHolder: CoverPaneServices = CoverPaneServices.live()

    // / The service that makes a card's cover move (= one for the whole
    // / pane, so the per-card lock is shared: = two clicks on the same
    // / card make ONE clip, = not two). = It lives here rather than in
    // / the grid extension because an extension cannot hold a stored
    // / property.
    @State var coverVideoServiceHolder: CoverVideoService = CoverVideoService.live()

    // / cached snapshot of `(shelfId → books)` so the shelf subtree can be
    // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / cycle).
    @State var cachedShelfBooks: [UUID: [Book]] = [:]

    // / (= boss 2026-10-10 "两 个 卡 片 右 键 删 除 ， 删 除 成 功 后 ， 目 录 树 没 有 刷 新 "
    // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / don't change when the FS changes; = SwiftUI doesn't re-render the grid).
    @State private var libraryChangeTick: Int = 0

    /// scope of documents to display. Driven by sidebar selection (=
    /// WorkspaceView computes from sidebarSelection).
    let scope: PreviewScope

    // / card-double-click callback (= replaces the B-13 empty NSLog placeholders
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / CardSource?) which uses the supplied source instead of `filtered.first`.
    let onDoubleClick: (CardSource) -> Void

    // / trailing button rendered in the pane's tab bar (= the trailing
    // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / + content).
    var trailingButton: AnyView? = nil

    // / : 'carddefaultyes'. Default = .pinyinFirstLetter (= the spec). Owned by
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / this view's card grid.
    @Binding var previewSortOrder: EntitySortOrder

    // / search query for the preview pane. Owned by PreviewPane (= previously a
    // … (= 17 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / fed from the external `.searchable` modifier).
    @Binding var searchQuery: String?

    // / SidebarItem.tag preview-pane filter: the active tag filter (= the user
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / filter" (= show all references).
    @Binding var activeTag: String?

    // / 'move the position: below the title and divider, above the first card':
    // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / custom search field.
    var customLeadingSearch: AnyView? = nil

    // / Legacy internal search state. Used when `searchQuery` (= the new
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / behavior change.
    @State private var previewSearchQuery: String = ""

    /// Resolved search query used by `searchFilteredEntities`. Reads from the
    /// external Binding when present, else from the legacy internal `@State`.
    var resolvedSearchQuery: String {
        if let external = searchQuery {
            return external
        }
        return previewSearchQuery
    }

    // / Whether the pane renders its internal handwritten search deleted
    // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / still works for unit tests / previews).
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
        self._previewSortOrder = previewSortOrder
        self._searchQuery = searchQuery
        self._activeTag = activeTag
        self.customLeadingSearch = customLeadingSearch
        self._coverServicesHolder = State(initialValue: coverServices)
    }
// / : 'cards display in multiple columns, default two columns, if the zone is dragged narrower,
// … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
// stays in 2-column mode.
    static let twoColumnBreakpoint: CGFloat = 350

    @ViewBuilder
    var body: some View {
        // (see OOB.md #2026-09-07) — 'yes, top bar, search can editor, yes': the search
        // … (= 15 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // and toolbar).
        VStack(spacing: 0) {
            // Per Apple HIG / platform-default style: the section-header block (=
            // … (= 44 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // PreviewPane no longer hardcodes the geometry here).
            SectionHeader(
                title: String(localized: "preview.column.title"),
                // Per boss 2026-10-16 OOB "我不想要那个间距": the assets
                // column renders `EditorHeaderView` (= the chrome band
                // wrapping the search field) directly below the title's
                // divider. The chrome band already carries its own 28 PT
                // row height + 8 PT horizontal padding; the section
                // header's trailing 10 PT inset would create a redundant
                // vertical gap between the divider and the search chrome
                // (= the gap the user described as "搜索框和标题的分割线
                // 之间有间距"). Suppress the trailing inset here; the
                // default `true` still applies to sidebar + inspector,
                // which render a list with internal padding right below
                // the section header.
                trailingInset: false
            )
            // Per Apple HIG / platform-default style: remove the custom top inset (=
            // … (= 24 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // legacy callers / tests still work).
            if let customSearch = customLeadingSearch {
                // Per Apple HIG / platform-default style: render the search field at the
                // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // stretch.
                customSearch
                    // Per Apple HIG / platform-default style: use
                    // … (= 23 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // intuition that 30 PT feels right).
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Per Apple HIG / platform-default style: drop the manual BOTTOM
                    // … (= 19 rationale lines collapsed; = A112 docblock collapse per §1.8)
                    // Notes column search pattern).
            }
            // Per Apple HIG platform availability: just use it — don't roll our own
            // … (= 53 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // level animation).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                scopeGroup
                // Cards fade in on sidebar tap (= no-flicker-stutter): the scope Group
                // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // unfindable legacy behavior).
                .id(scope)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                Spacer(minLength: 0)
            }
            // (see OOB.md #2026-09-08) — round 1 'card, search card icon, , 18pt': body
            // … (= 58 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // padding).
            .padding(.horizontal, DesignTokens.spacingModerate)
                }
            .onReceive(NotificationCenter.default.publisher(for: .wenshuLibraryDidChange)) { _ in
                libraryChangeTick &+= 1
            }
            // Cards fade in on sidebar tap (= no-flicker-stutter, scope-switch entry
            // … (= 16 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // navigation feel (= the reference for the entry transition).
        .animation(.smooth(duration: 0.22), value: scope)
            // the right-click "重命名" sheet (= the same RenameItemSheet the sidebar uses).
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // `otherReferenceTitles` for the duplicate check).
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
            // the delete alert (= the same `.alert` the sidebar uses). Only the
            // … (= 3 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // state).
            .alert(
                String(localized: "sidebar_delete_alert_title"),
                isPresented: Binding(
                    get: { cardPendingDelete != nil },
                    set: { if !$0 { cardPendingDelete = nil } }
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
                        // (= boss 2026-10-10 "两 个 卡 片 右 键 删 除 ， 删 除 成 功 后 ， 目 录 树 没 有 刷 新
                        // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // deleted card disappear immediately).
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

    // / preview-pane search bar (= 30 PT tall, = matches
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / pattern).
    @ViewBuilder
    private var scopeGroup: some View {
        Group {
            switch scope {
            case .referenceScope(let category):
                referenceScopeView(category: category)
            case .tagScope(let tag):
                referenceScopeView(category: nil, tagOverride: tag)
            case .bookScope(let bookId, folderName: let folderName):
                bookScopeView(bookId: bookId, folderName: folderName)
            case .shelfScope(let shelfId):
                shelfScopeView(shelfId: shelfId)
                    .id(shelfId)
                    .task(id: shelfId) {
                        await loadShelfBooksAsync(shelfId: shelfId)
                    }
            case .empty:
                emptyScopeView()
            }
        }
    }

    // (referenceScopeView extracted to PreviewPaneScopeViews.swift in A82; = see that file)
    // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // (Card extracted to PreviewPaneCard.swift in A33; = see that file)
}

