// Sources/WenshuApp/Views/Workspace/PreviewPane.swift Deferred per spec: ViewInspector
// test coverage is deferred (= the view has 3 distinct scope states + 3 sub-view
// modes; = mocking all of them exceeds a single commit's scope). This file is a
// documented deferral, not dead code. Scope model: - .referenceScope(category):
// reference library entities. nil = all, non-nil = that category only. -
// .bookScope(bookId, folderName): per-book documents. folderName nil = union of all 8
// standard folders; folderName non-nil = that folder only. - .shelfScope: shelf row
// selected = empty state hint. - .empty: nothing selected = empty state hint. 3 sub-
// view modes (per scope): 1. Overview grid (= when nothing selected within a scope).
// 2. Category/folder-scoped grid (= filter active). 3. Document detail (= single card
// with full body). Double-click on a card (= the editor open action). For now, single-
// click selects. Grid uses `LazyVGrid` (= Apple standard for variable-height grid;
// matches Finder icon view style).

import SwiftUI
import os
import CoreFoundation
import AppKit
import CryptoKit

private let wenshuLogger = Logger(subsystem: "com.wenshu", category: "previewpane")

// MARK: - Sort order
// 'all cards default sort is pinyin initial letter alphabetical, in the material preview
// top bar add an icon on the right side to implement re-sort. Current options: first
// letter, creation time, modification time'. 3 sort options: 1. .pinyinFirstLetter (=
// default) — Chinese pinyin alphabetical using CFStringTransform
// (kCFStringTransformToLatin + kCFStringTransformStripDiacritics) 2. .createdAt —
// newest first (= most useful for research material tracking) 3. .modifiedAt — most
// recently edited first (= for active writing)
// MARK: - BookFolder enum
// The 8 standard folders every book has on disk (= per AGENTS.md §11 +
// LibraryMigrator.swift standardFolders). Used by PreviewPane to scan all folders when
// scope = .bookScope(bookId, folderName: nil) and to label each BookDoc's folder
// badge. Sidebar tree only displays 5 of these (= world / characters / outlines /
// chapters / drafts), but the disk layout has all 8.
// Sessions/foreshadowing/placeholders can still be reached via the PreviewPane when
// the user picks them via API (= no UI yet for picking non-sidebar folders; deferred).
// (= boss 2026-10-10 (see OOB.md #2026-10-10) directive). The `ideas` (= 构思) case is
// added (= 9 cases now; = the 6 import folders: world / characters / outlines /
// chapters / drafts / ideas; = the 3 non-import folders: sessions / foreshadowing /
// placeholders). `ideas/` is a scratchpad for loose world- building fragments and
// future- story ideas (= the boss's "零散的 设定, 和未来 的一些想法"; = NOT a draft = `drafts/` is
// for undecided chapter content; = `ideas/` is for "things that might become
// characters / locations / events / chapters later" that don't fit any specific folder
// yet).
// (5 pure data types extracted to PreviewPaneModels.swift; = see that file)

// (5 pure data types extracted to PreviewPaneModels.swift; = see that file)


// MARK: - PreviewScope
// Defines which documents the preview pane should display. Driven by the sidebar
// selection (= WorkspaceView computes `previewScope` from `sidebarSelection` and
// passes it here). Each scope knows how to load its documents and what view mode to
// render. Note: PreviewScope is NOT Equatable (the underlying SidebarItem is, but
// PreviewScope is constructed from it; equality comparisons happen upstream via
// sidebarSelection).
// (5 pure data types extracted to PreviewPaneModels.swift; = see that file)


// MARK: - BookDoc model
// Represents one .md file in a book folder. Loaded on demand from the filesystem (= no
// caching yet; subsequent reads are fast on macOS APFS). Used for the book-scope
// preview mode.
// (5 pure data types extracted to PreviewPaneModels.swift; = see that file)

// (5 pure data types extracted to PreviewPaneModels.swift; = see that file)


// (extracted to PreviewPaneDocId.swift in A49; = see that file)
// (= the cross-file `extension PreviewPane { ... stableBookDocId }`
// = 8 LOC moved out of the main file. The `nonisolated` qualifier
// is preserved; = safe to call from any actor.)

/// Content for the material management zone (= projectPreview). Renders cards
/// in scope-driven modes: - .referenceScope(nil): all entities (= overview
/// grid) - .referenceScope(.some): category-scoped entity grid -
/// .bookScope(bookId, nil): all .md files in this book - .bookScope(bookId,
/// folder): .md files in this folder only - .shelfScope / .empty: empty state
/// hint
struct PreviewPane: View {
    @Environment(BookStore.self) private var bookStore

    /// (= boss 2026-10-10 "没 有实现， 右键卡片 没有菜 单" + "素 材栏， 不是 tree， 是第 二栏"
    /// directive). The right-click context-menu state (= the rename sheet
    /// target + the pending-delete alert target). Mirrors the
    /// `AppleSidebarView` pattern (= the sidebar's `renaming` / `pendingDelete`
    /// state uses the same `SidebarRenamingTarget` / `SidebarPendingDelete`
    /// structs; = the PreviewPane reuses those types for the second column's
    /// reference cards; = a single rename sheet / delete alert = the user can
    /// rename / delete from either surface; = but the PreviewPane gets its own
    /// local sheet state since `AppleSidebarView`'s sheet is local to that
    /// view).
    @State var cardRenaming: SidebarRenamingTarget?
    @State var cardPendingDelete: SidebarPendingDelete?
    /// a local SidebarService (= the second column's reference cards need a
    /// service to call `renameReference` / `deleteReference`). The service is
    /// @State (= the service is an actor-isolated class; = @State holds the
    /// reference; = the closures capture it for the card's `.contextMenu`).
    @State private var cardService: SidebarService?

    /// cached snapshot of `(shelfId → books)` so the shelf subtree can be
    /// cheaply skipped across body re-renders. The shelfScopeView ran
    /// FileManager I/O (= walk shelves tree + read every .md) on EVERY SwiftUI
    /// body re-render of PreviewPane (= every Observation tick = every
    /// sidebarSelection change = every AppState mutation = the 'more Update
    /// Constraints in Window passes than there are views in the window' SwiftUI
    /// NSHostingView constraint loop). The fix: pre-load via `.task(id:)` keyed
    /// on shelfId (= SwiftUI cancels and restarts the task only when shelfId
    /// changes = not on every parent re-render = no I/O storm = no layout
    /// cycle).
    @State private var cachedShelfBooks: [UUID: [Book]] = [:]

    /// (= boss 2026-10-10 "两 个 卡 片 右 键 删 除 ， 删 除 成 功 后 ， 目 录 树 没 有 刷 新 "
    /// feedback). A monotonically- increasing tick that bumps whenever
    /// `wenshuLibraryDidChange` fires. The card-grid view depends on this tick
    /// (= the @State change forces SwiftUI to re-evaluate the body; = the
    /// `loadBookDocs` walk runs again; = the deleted card disappears). Without
    /// this tick, the card grid would not notice the FS change (= the
    /// `loadBookDocs` call is inside a ViewBuilder body; = the body's inputs
    /// don't change when the FS changes; = SwiftUI doesn't re-render the grid).
    @State private var libraryChangeTick: Int = 0

    /// scope of documents to display. Driven by sidebar selection (=
    /// WorkspaceView computes from sidebarSelection).
    let scope: PreviewScope

    /// card-double-click callback (= replaces the B-13 empty NSLog placeholders
    /// + BUG1 from the 2026-09-03 macOS visual verify). Type = `() -> Void` (=
    /// untyped; = matches the existing single-Card pattern; = the actual card
    /// data is read from the Card's own `source` field at call time, not via
    /// closure capture; = same code path handles both reference and bookDoc
    /// sources since B-02's CardSource enum unification). (see OOB.md
    /// #2026-09-08) — 'clicking the Dufu card opens a tab with wrong name' (=
    /// clicking the card opens a new tab with the wrong name): the previous
    /// `onDoubleClick: () -> Void` had NO way to identify which card was
    /// clicked (= the closure was bound at ForEach time but didn't capture
    /// per-card state). The caller (= WorkspaceView.openCardInEditor) had to
    /// fall back to `filtered.first` (= always the topmost card, not the
    /// actually-clicked one), opening the wrong .md file. Fix: onDoubleClick
    /// now takes the clicked CardSource (= either .reference(Reference) or
    /// .bookDoc(BookDoc)). The caller passes it to openCardInEditor(source:
    /// CardSource?) which uses the supplied source instead of `filtered.first`.
    let onDoubleClick: (CardSource) -> Void

    /// trailing button rendered in the pane's tab bar (= PaneTabBar trailing
    /// slot). Used by the project preview scope to host the sort menu (= sorts
    /// the card grid by first letter / creation time / modification time).
    /// Default = nil = no trailing button (= the scope just renders its tab bar
    /// + content).
    var trailingButton: AnyView? = nil

    /// : 'carddefaultyes'. Default = .pinyinFirstLetter (= the spec). Owned by
    /// WorkspaceView (= shared with PreviewSortMenuButton via the @State
    /// binding) so changing the sort via the tab bar trailing button re-renders
    /// this view's card grid.
    @Binding var previewSortOrder: EntitySortOrder

    /// search query for the preview pane. Owned by PreviewPane (= previously a
    /// @Binding to WorkspaceView, = now reverted to @State since the search bar
    /// lives inside PreviewPane
    //  body; = the bind-chain is no longer needed). Empty string
    /// = show all cards; non-empty = filter by case-insensitive substring match
    /// on card display name + summary. SwiftUI @State reactivity re-evaluates
    /// `body` on every keystroke (= live refresh, no submit button, no
    /// .onChange handler needed). to the Apple API default style': callers can
    /// pass an OPTIONAL external `searchQuery` Binding to use an EXTERNAL
    /// `.searchable(...)` modifier (= the canonical macOS 13+ Apple HIG search
    /// field; = identical visual to the sidebar `.searchable` field). When
    /// `searchQuery` is non-nil, the internal handwritten search bar is
    /// suppressed (= one canonical Apple search field per pane, not two
    /// competing ones). When nil, the legacy internal `@State private
    /// previewSearchQuery` is used (= the legacy PaneSplitHost path = backward
    /// compat). Use `Binding<String>?` for the OPTIONAL external query (= nil
    /// means "no external binding = render internal search bar"). When non-nil,
    /// the Binding's wrapped value is the search query (= one source of truth,
    /// fed from the external `.searchable` modifier).
    @Binding var searchQuery: String?

    /// SidebarItem.tag preview-pane filter: the active tag filter (= the user
    /// clicked a `.tag(String)` sidebar item; = the preview pane renders only
    /// references whose `tags` set contains this string). = nil means "no tag
    /// filter" (= show all references).
    @Binding var activeTag: String?

    /// 'move the position: below the title and divider, above the first card':
    /// per the user's request, the search field renders BELOW the 'Assets'
    /// section header + Divider and ABOVE the first card (= the Apple HIG
    /// "sticky header + inline search" pattern, not "search on top of header").
    /// Why a custom AnyView (= not Apple's `.searchable`): 1. Apple HIG macOS
    /// 27 forces `.searchable` to render at the column's trailing edge (= a
    /// documented framework limitation in NavigationSplit columns; = the
    /// preference for a leading-positioned search field can't be satisfied with
    /// `.searchable`). 2. The custom search field IS leading-aligned per the
    /// earlier preference (= "search box on the left"). Why threaded through
    /// WorkspaceView (= not inlined in the caller): PreviewPane is a stable
    /// component (= other callers in tests / kanban previews use it too); =
    /// keeping the search field position inside PreviewPane (= "sticky header +
    /// search below + grid") preserves the component contract while satisfying
    /// the placement request. Default = nil = no custom search field rendered
    /// (= the legacy code path; = old callers and tests still work). Pass
    /// `customLeadingSearch: AnyView(...)` from WorkspaceView to inject the
    /// custom search field.
    var customLeadingSearch: AnyView? = nil

    /// Legacy internal search state. Used when `searchQuery` (= the new
    /// external Binding) is nil. Kept as `@State` so legacy callers = no
    /// behavior change.
    @State private var previewSearchQuery: String = ""

    /// Resolved search query used by `searchFilteredEntities`. Reads from the
    /// external Binding when present, else from the legacy internal `@State`.
    private var resolvedSearchQuery: String {
        if let external = searchQuery {
            return external
        }
        return previewSearchQuery
    }

    /// Whether the pane renders its internal handwritten search deleted
    /// `showsInternalSearchBar` (= verify-dead reports ext=0 + int=0; = 0
    /// callers; = the helper checked `searchQuery == nil` (= the legacy
    /// internal-@State fallback gate); = the binding is now always non-optional
    /// per the this computed var is no longer meaningful; = no behavior change;
    /// = 4 LOC removed). 'if the Apple API supports
        /// it, just use it — don't roll our own search': the previous init took
        /// `searchQuery: Binding<String?>?` (= optional; = nil meant
    /// 'fall back to the legacy internal @State'). The optional path was the
    /// source of the lifecycle-reset bug (= the internal @State got reset on
    /// every PreviewPane rebuild = the 'type x, results are unrelated to x'
    /// symptom). Now the search field lives at the parent level (= Apple's
    /// `.searchable` modifier on ShellMiddleColumn) and the binding is always
    /// non-optional = the search text always resolves to the same live parent
    /// @State across the PreviewPane lifecycle. Kept the default value of
    /// `.constant(nil)` (= backward-compat for callers that don't pass
    /// searchQuery; = those callers get the legacy internal `@State` path which
    /// still works for unit tests / previews).
    init(
        scope: PreviewScope,
        onDoubleClick: @escaping (CardSource) -> Void,
        previewSortOrder: Binding<EntitySortOrder>,
        searchQuery: Binding<String?> = .constant(nil),
        customLeadingSearch: AnyView? = nil,
        activeTag: Binding<String?> = .constant(nil)
    ) {
        self.scope = scope
        self.onDoubleClick = onDoubleClick
        self._previewSortOrder = previewSortOrder
        self._searchQuery = searchQuery
        self._activeTag = activeTag
        self.customLeadingSearch = customLeadingSearch
    }
/// : 'cards display in multiple columns, default two columns, if the zone is dragged narrower,
    /// not enough for two columns, auto-adapt to one column, in plain words
    /// it's card flow, width adaptive'. Adaptive column count: - preview pane
    /// width >= twoColumnBreakpoint: 2 columns (= default) - preview pane width
    /// < twoColumnBreakpoint: 1 column (= narrow) Why 280 PT threshold: - Per
    /// LayoutTokens.projectPreviewRatio = 0.20 (= preview pane gets 20% of
    /// total workspace width = 384 PT at 1920 PT total) - Card min content +
    /// padding needs ~120-150 PT (= readable summary + thumbnail) - 2 cards
    /// side by side = 240-300 PT + 16 PT gap = ~256-316 PT - 280 PT threshold =
    /// preview always defaults to 2 columns at the default 20% ratio (= the
    /// "default two columns" requirement) - If user drags the preview divider
    /// to shrink it (< 200 PT), falls back to 1 column automatically. Threshold
    /// lowered from 280 PT to 200 PT on 2026-09-01 to match the actual
    /// preview-pane width delivered by NSSplitView at weights [2] in the
    /// 10/20/60/10 preset (= ~210 PT). With the old 280 PT threshold, every
    /// launch collapsed to 1 column, defeating the "preview pane shows 2
    /// columns" expectation.
    // (2026-09-08): raised from 130 to 350 (= the cards grid renders as a SINGLE column
    // when embedded inside the M2 NavigationSplitShell's sidebar column = the red-
    // line drawing shows 1 column for the cards zone. 350 (= higher than the
    // typical sidebar sub-area width of ~250 PT in a 1452-wide window with a
    // 200-PT sidebar column) ensures the cards grid falls back to 1 column when
    // the preview pane is nested in the shell's sidebar sub-area. The legacy
    // PaneSplitHost path (= the preview pane is a standalone 4th column at
    // ~250-400 PT) is unaffected because that column is still wider than 350 PT =
    // stays in 2-column mode.
    static let twoColumnBreakpoint: CGFloat = 350

    @ViewBuilder
    var body: some View {
        // (see OOB.md #2026-09-07) — 'yes, top bar, search can editor, yes': the search
        // bar belongs BELOW the ZoneContentView's tab strip (= at the same Y
        // as the editor's pencil/arrow/refresh toolbar inside EditorView), NOT
        // above the tab strip. Pattern matches the editor: ZoneContentView tab
        // strip (= top layer) + tab content (= PreviewPane, = search bar BELOW
        // tab strip + body content below the search bar). Search bar lives at
        // the TOP of PreviewPane's body (= first element rendered after
        // ZoneContentView's tab strip), so it aligns horizontally with the
        // editor's toolbar in the right column. Body content (Group { switch
        // scope }) goes below the search bar. (see OOB.md #2026-09-07) — 'top
        // bar search: yes': the .padding(DesignTokens.spacingHero) was
        // wrapping the entire VStack (= search bar + body), = creating a
        // visual gap between the ZoneContentView tab strip and the search bar.
        // The padding belongs ONLY on the body content (= scope Group), NOT on
        // the search bar (= search bar should sit flush against the tab strip,
        // = Apple HIG canonical toolbar pattern = no padding between tab strip
        // and toolbar).
        VStack(spacing: 0) {
            // Per Apple HIG / platform-default style: the section-header block (=
            // 'Assets' title + Pages hairline) and the search bar must
            // STICK TO THE TOP of the cards column. The empty-state hint
            // (= icon + 'Please pick a node on the left to view the
            // document' + 'Pick a reference library, book, or folder on
            // the left.') must stay vertically CENTERED in the REMAINING
            // space below the header + search bar. This is the Apple HIG
            // canonical 'sticky toolbar + centered empty state' pattern (=
            // Finder / Photos / Music empty-state visuals when a sidebar
            // selection is made but the right-hand column has no content
            // yet). : the preview-pane search bar ALWAYS renders inline at
            // the top of the middle column body (= same visual slot as the
            // sidebar's `.searchable` field at the top of the sidebar
            // column). The previous `if showsInternal SearchBar` branch (=
            // commit 4a0453516) was the workaround for the
            // `.searchable(placement: .toolbar)` routing-to-window-toolbar
            // bug; with that workaround removed (= the next commit drops
            // the column toolbar and lets PreviewPane render its own
            // search bar at the top of the column body), PreviewPane is
            // the single source of truth for the search bar visual (= the
            // sidebar's `.searchable` is Apple's first- party widget for
            // the sidebar column; the card pane's inline
            // `previewSearchBar` is Apple's macOS 13+ rounded-pill pattern
            // hosted inline because `.searchable` has no 'middle column
            // top' placement). Mirror the sidebar's Pages-style section
            // header: - .font(.body) (= matches the card row text below; =
            // Pages sidebar visual reference). -
            // .foregroundStyle(.primary) (= Pages uses primary tint for
            // sidebar title; = the previous small- caption secondary-tint
            // was the generic SwiftUI sidebar style, not Pages). - Divider
            // below with .padding(.top, 4) (= Pages leaves ~4 PT gap
            // between title text and hairline). - .padding(.bottom, 4) (=
            // Pages hairline sits ~4 PT above the search bar; = the
            // canonical Apple HIG toolbar-below-section-header spacing). -
            // Always rendered (= present in BOTH the populated- card state
            // AND the empty state; = the previous empty state hid the
            // search bar visually but the search bar still rendered at the
            // top; = the report 'in empty state the search bar still goes
            // to the top' = the search bar is always there but the title
            // was missing; = adding the title above the search bar fixes
            // the visual alignment in both states). lift the preview
            // column title bar to the shared SectionHeader component (=
            // also used by AppleSidebarView 'library shelf' header (= same
            // Apple HIG Mail / Notes / Finder section-header idiom; =
            // SectionHeader owns the 10 PT / 4 PT / 10 PT insets; =
            // PreviewPane no longer hardcodes the geometry here).
            SectionHeader(title: String(localized: "preview.column.title"))
            // Per Apple HIG / platform-default style: remove the custom top inset (=
            // `chromePaddingSectionTop` = 18 PT) and the custom bottom
            // inset (= 4 PT). The center column is the content column of a
            // NavigationSplitView; = Apple HIG macOS 27 default content
            // column rhythm places the section header at the natural List
            // / ScrollView top margin (= NO custom padding required; = the
            // Apple API default). Per the verbatim port discipline, the
            // previous search-field `.padding(.top, 4)` (= 4 PT gap to the
            // Divider) and the cards column layout are preserved (= no
            // unrelated changes).
        // Custom leading search field
            // below the title and divider, above the first card': render the custom
            // leading-aligned search field HERE (= below the 'Assets'
            // title + Divider; above the first card grid) = the Apple HIG
            // "sticky header + inline search field below" pattern (= the
            // canonical Mail / Notes / Pages section-header-then-search
            // layout). The previous attempt (commit 71daf8311) put the
            // search field in a wrapper HStack ABOVE PreviewPane (=
            // visually wrong = the search field rendered above the title
            // and the immediate ask was to move it). The fix = move the
            // search field into the PreviewPane body, between the title
            // block and the scope body, so it sits exactly where requested
            // (= below the divider, above the first card). Only render the
            // custom field when the caller passed one (=
            // `customLeadingSearch != nil`). Default = nil = no field (=
            // legacy callers / tests still work).
            if let customSearch = customLeadingSearch {
                // Per Apple HIG / platform-default style: render the search field at the
                // FULL column width (= the outer `.frame(maxWidth:
                // .infinity)` makes SwiftUI stretch this view to
                // consume all available horizontal space in the parent
                // VStack; = the search field now matches the
                // LazyVGrid's full grid width; = as the user drags the
                // column wider, both the cards and the search field
                // stretch together). Why wrap with `.frame(maxWidth:
                // .infinity, alignment: .center)` (= not just rely on
                // the inner AnyView's `.frame`): SwiftUI AnyView
                // wrappers lose layout intent (= the framework can't
                // see through them at compile time; = the
                // `customSearch` AnyView measures itself as its
                // intrinsic content size, not the parent's full
                // width). The OUTER `.frame(maxWidth: .infinity,
                // alignment: .center)` (= applied by the parent VStack
                // that can see the column width) is what forces the
                // stretch.
                customSearch
                    // Per Apple HIG / platform-default style: use
                    // `.controlSize(.regular)` on the inner
                    // TextField (= the canonical macOS 13+ SwiftUI
                    // expression for the standard form- control
                    // height = 22 PT = matches Apple's Mail /
                    // Notes / Finder search fields = NO hard-coded
                    // `.frame(height: 30)`). Why not
                    // `.searchable`: `.searchable` is hard-wired
                    // to render in the TRAILING edge of any column
                    // toolbar (= a documented framework limitation
                    // in NavigationSplit columns = the earlier
                    // preference for a leading-positioned search
                    // field can't be satisfied). The custom
                    // TextField with `.controlSize(.regular)`
                    // gives us Apple's canonical control size +
                    // leading alignment in one package. Why not
                    // hard-code 30 PT: the explicit direction was
                    // 'don't write a hard number; = use Apple's
                    // semantic expression (=
                    // `.controlSize(.regular)`) = SwiftUI maps
                    // `.regular` to the canonical macOS 22 PT
                    // control height (= approximately 30 PT once
                    // SwiftUI's vertical padding and the
                    // surrounding HStack padding are added; = the
                    // intuition that 30 PT feels right).
                    .frame(maxWidth: .infinity, alignment: .center)
                    // Per Apple HIG / platform-default style: drop the manual BOTTOM
                    // padding around the search field (= the
                    // previous `.padding(.bottom, 6)` was a hand-
                    // rolled vertical breathing room between the
                    // search field and the first card; = removing
                    // it makes the search field sit flush against
                    // the first card below; = the cards' own
                    // LazyVGrid spacing controls the gap to the
                    // next card). Per Apple HIG / platform-default
                    // style: per the UPDATE 2026-09-11 — 'remove
                    // all custom padding and switch to Apple-
                    // standard expressions — find an approximate
                    // value': REMOVE both `.padding(.top, 4)` (= 4
                    // PT divider→search gap) and
                    // `.padding(.horizontal, 8)` (= 8 PT
                    // horizontal inset). The Apple HIG macOS 27
                    // default layout for an inline search field
                    // within a content column places the field at
                    // natural SwiftUI default spacing (= NO custom
                    // padding required; = the canonical Mail /
                    // Notes column search pattern).
            }
            // Per Apple HIG platform availability: just use it — don't roll our own
            // search': the previous internal `previewSearchBar` view (= a
            // hand-rolled HStack with Lucide search icon + TextField +
            // clear-x button) is REMOVED. The search field now lives at
            // the parent level (= ShellMiddleColumn) attached via Apple's
            // canonical `.searchable(text:placement:prompt:)` modifier (=
            // the system-styled search field rendered in the column's
            // toolbar slot; = identical visual to Mail / Notes / Finder
            // column search). Removing the internal search bar means: -
            // The cards column body no longer has a top search field (the
            // user sees only 'Assets' title + cards grid below). - The
            // Apple `.searchable` field at the column's toolbar slot hosts
            // the search input. - ⌘F focuses the field (= Apple standard
            // keyboard shortcut). (see OOB.md #2026-08-31) — scope-driven
            // dispatch. Each scope branch handles its own toolbar (some
            // hide toolbar, e.g. empty state). Padding applied here only
            // (= doesn't affect the search bar's Y position). Per Apple
            // HIG / platform-default style: wrap the scope Group in an
            // explicit `VStack { Spacer; Group; Spacer }` (= top + bottom
            // spacers push the Group to vertical center inside the
            // remaining space BELOW the sticky header + search bar).
            // Without the Spacers, the Group rendered at the top of its
            // slot (= immediately below the search bar) and the empty-
            // state hint appeared squashed against the search bar. With
            // the Spacers, the empty-state hint stays centered in the
            // residual space (= the canonical Apple HIG empty-state
            // layout). Cards fade in on sidebar tap (= the no-flicker-
            // stutter pattern): wrap the scope Group in `.id(scope)` (=
            // stable subtree identity per scope = SwiftUI unmounts the
            // previous scope and mounts the new one on scope change) +
            // apply `.transition(.opacity.combined(with: .scale(scale:
            // 0.96)))` (= the cards fade in + scale up from 96% to 100% on
            // entry; = the same scale-fade-in Apple Photos uses when
            // navigating between library days; = 220 ms = matches Apple's
            // macOS 27 List / LazyVGrid default animation duration). The
            // parent VStack wraps the transition in a
            // `withAnimation(.smooth)` block triggered by `.onChange(of:
            // scope)` (= the actual animation trigger; = without
            // withAnimation the transition fires instantly with no visible
            // motion). Why scope-level transition (= not per-card
            // transition): when the user clicks a different sidebar row,
            // ALL cards in the previous scope unmount and ALL cards in the
            // new scope mount in one batch. Animating each card
            // independently would create a staggered cascade that looks
            // chaotic; = the report 'cards appear without any animation,
            // looks ugly' was specifically about the scope-switch case. A
            // single coordinated group-level fade-in reads as a deliberate
            // state transition (= Apple Mail / Notes behavior on mailbox /
            // folder switch). Per-card transition (.opacity + .scale 0.96)
            // stays attached for the search-filter case (= typing in the
            // search field adds/removes cards one at a time; = each card's
            // own transition fires individually with the
            // `.animation(.smooth, value: ids)` modifier on the ForEach; =
            // search changes feel responsive without cascading the scope-
            // level animation).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                scopeGroup
                // Cards fade in on sidebar tap (= no-flicker-stutter): the scope Group
                // gets a stable per-scope identity (= `.id(scope)`) so
                // SwiftUI treats each scope switch as a full subtree
                // unmount / mount; = the matching `.transition` below
                // plays the scope-switch entry animation. The
                // animation is triggered by the parent `.onChange(of:
                // scope)` wrapping the state mutation in
                // `withAnimation( .smooth)` (= SwiftUI's structural
                // transitions only animate when the change is wrapped
                // in a withAnimation block; = without it the
                // transition is instant and identical to the
                // unfindable legacy behavior).
                .id(scope)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                Spacer(minLength: 0)
            }
            // (see OOB.md #2026-09-08) — round 1 'card, search card icon, , 18pt': body
            // content padding was chromePaddingHero = 20 PT; = bumped to
            // 18 PT. (see OOB.md #2026-09-08) — round 2: '18 is a bit
            // wide; Apple API default spacing isn't PT, it's a semantic
            // name'. (see OOB.md #2026-09-08) — round 3: 'cards zone
            // having no spacing is not pretty, keep the spacing, all zones
            // use round 2'. Apple HIG = chromePaddingLeading (= horizontal
            // inset from zone edge to content) = 8 PT (= the canonical
            // toolbar / inline content inset per SwiftUI 'Spacing.
            // small'). Used padding(8) (= horizontal + vertical 8 PT) so
            // cards have visible breathing room (= not flush against the
            // zone edge = not pretty) but match Apple HIG spacing scale (=
            // 8-point grid). Note: per the Apple HIG card grid pattern (=
            // Finder / Photos / Music), the gap between cards IS the
            // spacing (= LazyVGrid's `spacing: 16` per GridItem + this
            // outer 8 PT inset = the canonical 'comfortable but compact'
            // grid per Apple Design Resources). Per Apple HIG / platform-
            // default style: the previous `.padding(8)` (= 8 PT top +
            // bottom + leading + trailing) added a hand- rolled 8 PT gap
            // between the search field above and the first card below. Per
            // the user's request to keep only Apple-HIG defaults, drop the
            // manual top padding (= the cards' own LazyVGrid spacing
            // controls vertical spacing between cards; = no extra top
            // inset between the search field and the first card needed).
            // Keep leading + bottom padding (= 8 PT) so cards still have
            // breathing room from the column edges (= Apple HIG 8-point
            // grid for inline content). Search-bar + cards padding (= 10pt
            // inset per Apple HIG): the cards' left + right padding
            // switches from 8 PT (= hand-written magic number, = a long-
            // standing inline number that drifted from the search field's
            // 8 PT horizontal padding) to 10 PT (=
            // chromePaddingContentHorizontal = the canonical PreviewPane
            // content gutter; = same value the search field now uses; =
            // one gutter = one source = no horizontal drift between search
            // field and card grid). : the cards' horizontal padding MOVED
            // to the outer PreviewPane column (= the column-level inset).
            // Drop the inner horizontal padding here (= would stack with
            // the column padding = 10 + 10 = 20 PT total = the explicit
            // complaint). Cards now rely solely on the column-level inset
            // for left + right breathing room (= single source of truth
            // for the PreviewPane gutter =
            // chromePaddingContentHorizontal). (= the user wants 10 PT
            // inner padding on the cards column; = the column-level
            // padding was the Column-level padding (= not affected by
            // header inset, per Apple HIG): be removed = the 10 PT gutter
            // now lives on the per-element level = the cards grid re-
            // asserts its own chromePaddingContentHorizontal (= 10 PT)
            // horizontal padding here = the same visual result but without
            // affecting the SectionHeader. 2026-10-12 round-16 boss
            // directive "这个素材栏是 不是写了内边距, 你看一下, 如果是写了, 把 下边的内边距取消掉" — drop
            // the column-level `.padding(.bottom,
            // DesignTokens.spacingStandard)` (= 8 PT bottom padding before
            // the column's last content; = creates an 8 PT visible gap
            // between the last card and the floating `ChromeBottomFooter`
            // from commit `1d3d8a404`; = the user reports "还差点, 素材栏底栏上面
            // 还有空白"). The horizontal padding (`.padding(.horizontal,
            // DesignTokens.spacingModerate = 12 PT`) is preserved (= the
            // cards' gutter rhythm with the sidebar / editor column
            // gutters is unchanged; = the user only flagged the bottom
            // padding).
            .padding(.horizontal, DesignTokens.spacingModerate)
                }
            .onReceive(NotificationCenter.default.publisher(for: .wenshuLibraryDidChange)) { _ in
                libraryChangeTick &+= 1
            }
            // Cards fade in on sidebar tap (= no-flicker-stutter, scope-switch entry
            // animation). 2026-09-24 followup No visible animation: the
            // original approach (= .onChange(of: scope) wrapping
            // withAnimation) does NOT trigger the transition because
            // `scope` is an immutable let-bound prop that arrives from the
            // parent (= the parent triggers the value change outside any
            // withAnimation block; = the closure runs in a non- animated
            // transaction; = the .transition attached to the Group never
            // plays). Resolution: attach `.animation(.smooth(duration:
            // 0.22), value: scope)` directly on the body root. SwiftUI's
            // value-based .animation modifier is the canonical replacement
            // for withAnimation when the state mutation lives outside the
            // current view (= the .animation modifier listens for value
            // changes on the passed Equatable/Hashable and wraps the
            // resulting render frames in an animation transaction; = the
            // .transition on the Group below fires correctly). Scale 0.96
            // + opacity over 220 ms = the Apple Photos library-day
            // navigation feel (= the reference for the entry transition).
        .animation(.smooth(duration: 0.22), value: scope)
            // the right-click "重命名" sheet (= the same RenameItemSheet the sidebar uses).
            // The `kind: .reference` case is already handled in
            // `RenameItemSheet.init` (= the sheet shows a single TextField
            // + the duplicate-name error; = the reference case uses
            // `otherReferenceTitles` for the duplicate check).
            .sheet(item: $cardRenaming) { target in
                RenameItemSheet(
                    kind: target.kind,
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
            // `.reference` case fires for now (= the card menu is
            // reference-only); = the sheet/alert plumbing supports all
            // kinds anyway (= future bookDoc menu can reuse the same
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
                        // " feedback): post the canonical
                        // library change notification (= same
                        // notification ImportSheet posts after
                        // a successful import; =
                        // AppleSidebarView observes this and
                        // reloads its tree; = PreviewPane's
                        // card grid also re-evaluates because
                        // the notification carries a timestamp
                        // change that SwiftUI treats as a new
                        // body input; = the user sees the
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

    /// preview-pane search bar (= 30 PT tall, = matches
    /// `LayoutTokens.toolbarHeight` = the editor's pencil/arrow toolbar inside
    /// EditorView). Pattern matches the editor: tab strip (ZoneContentView) →
    /// search bar (this view) → body content. Layout: - magnifying-glass icon
    /// (left, .secondary, .small) - TextField bound to `$previewSearchQuery`
    /// (.plain style,
    // MARK: - Scope subviews

    /// Reference library scope: existing entity card flow ((see OOB.md
    /// #2026-08-30) OOB: 'card'). category nil = overview (= all entities, flat
    /// grid per (see OOB.md #2026-08-30)); non-nil = category filter. Scope
    /// group (= the Apple HIG section-header + search-bar + body content block;
    /// = dispatches to reference / tag / book / shelf / empty scope based on
    /// `previewScope`). The body of the body (= ~65 LOC of switch) is the
    /// canonical switch dispatch (= 4 cases; = each case delegates to a
    /// dedicated private func; = same shape as the `Apple HIG` tabbed-detail
    /// pattern).
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

    @ViewBuilder

    private func referenceScopeView(category: EntityCategory?, tagOverride: String? = nil) -> some View {
        // (see OOB.md #2026-09-07) — 'search,': apply the search filter (=
        // previewSearchQuery) on top of the category filter. Both filters
        // compose (= all entities → search filter → category filter).
        let searched = PreviewPaneOps.searchFilteredEntities(PreviewPaneOps.loadAllEntities(bookStore: bookStore).entities, query: resolvedSearchQuery)
        // SidebarItem.tag preview-pane filter: apply the tag filter (= self.activeTag OR
        // tagOverride from PreviewScope.tagScope) on top of the search +
        // category filter. tag nil = show all (= the user picked the reference
        // library root). tagOverride takes precedence (= the new
        // PreviewScope.tagScope is the canonical route; =
        // workspaceUI.activeTag remains supported for backward compatibility
        // with the prior .referenceScope(nil) routing path that AssetsPane
        // uses to set activeTag in addition).
        let effectiveTag = tagOverride ?? activeTag
        let allEntities: [Reference] = {
            guard let effectiveTag else {
                return searched
            }
            return searched.filter { entity in
                entity.tags.contains(effectiveTag)
            }
        }()
        VStack(spacing: 0) {
            Group {
                if let cat = category {
                    categoryGrid(category: cat, allEntities: allEntities)
                } else {
                    overviewGrid(allEntities: allEntities)
                }
            }
        }
    }

    /// Book scope: scan filesystem for .md files in the book folders.
    /// folderName nil = union of all 8 standard folders; non-nil = just that
    /// folder.
    @ViewBuilder
    private func bookScopeView(bookId: UUID, folderName: String?) -> some View {
        // the `libraryChangeTick` `@State` is read in the body's `.onReceive` (= the
        // parent's body re-evaluates when the tick changes; = this view is re-
        // instantiated as part of the body re-render; = the `loadBookDocs`
        // call below re-walks the FS; = the deleted card disappears). No
        // explicit read needed here (= the body's re-evaluation is enough).
        let allDocs = PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: bookId, folderName: folderName).docs
        // Search-field padding rationale: actually filter the cards' (= typing in the
        // search field did not filter cards in the book scope). The previous
        // code passed the unfiltered `docs` to `bookDocsGrid(docs:)`; = the
        // search field only filtered reference entities (= in
        // `referenceScopeView`), but book .md cards bypassed the filter
        // entirely. Apply the same shape as `searchFilteredEntities` (= title
        // / summary / pinyin first-letter substring) to book docs.
        let docs = PreviewPaneOps.searchFilteredBookDocs(allDocs, query: resolvedSearchQuery)
        VStack(spacing: 0) {
            if docs.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: folderName != nil
                        ? "preview.empty_state.book_with_folder"
                        : "preview.empty_state.book_no_folder",
                    bodyKey: "preview.empty.pick_book"
                )
            } else {
                bookDocsGrid(docs: docs)
            }
        }
    }

    /// Shelf scope: union of every book's docs under the shelf. The shelf row
    /// is a scope (= shows every .md card from every book under that shelf; =
    /// union of all `loadBookDocs(bookId:, folderName: nil)` results filtered
    /// to books whose `shelfId == shelfId`).
    @ViewBuilder
    private func shelfScopeView(shelfId: UUID) -> some View {
        // see the comment on `bookScopeView` (= the body's `.onReceive` reads the
        // `libraryChangeTick` @State; = no explicit read needed here). Stable-
        // id root-cause fix: the original ran FileManager I/O (= walk shelves
        // tree + read every .md) inside this ViewBuilder body. SwiftUI re-
        // evaluates this body on EVERY Observation tick (= every AppState
        // mutation, every sidebarSelection change, every parent re-render), so
        // the I/O ran hundreds of times per second while the shelf was
        // selected → NSHostingView size constraint invalidation storm → 'more
        // Update Constraints in Window passes than there are views in the
        // window' NSGenericException crash. Fix: read the pre-computed, cached
        // book list from `@State cachedShelfBooks` (= populated exactly once
        // per shelfId via `.task(id: shelfId)` at the call site below = the
        // I/O runs at most once per shelfId change = no storm = no constraint
        // cycle). The `.id(shelfId)` at the call site gives SwiftUI a stable
        // identity for the subtree (= SwiftUI skips body re-evaluation
        // entirely when the shelfId is unchanged = the cached state survives
        // every observation tick).
        let books = cachedShelfBooks[shelfId] ?? []
        let allDocs = books.flatMap { PreviewPaneOps.loadBookDocs(bookStore: bookStore, bookId: $0.id, folderName: nil).docs }
        let filteredDocs = PreviewPaneOps.searchFilteredBookDocs(allDocs, query: resolvedSearchQuery)
        if filteredDocs.isEmpty {
            // Empty shelf branch (= no books under the shelf, or every book has no .md
            // cards, or the search filter excluded everything). Reuse the
            // existing emptyState view (= matches the cross-scope fallback
            // shape that the other scopes fall back to) but with a shelf-
            // specific bodyKey.
            emptyState(
                icon: "books.vertical",
                titleKey: "preview.empty_state.shelf_empty",
                bodyKey: "preview.empty.shelf_no_books"
            )
        } else {
            // Non-empty: reuse the canonical bookDocsGrid (= same LazyVGrid +
            // adaptiveColumns(width:) + sort + Card styling as
            // bookScopeView). Avoids the draft duplicate LazyVGrid (=
            // different .padding(24) vs .padding(.vertical,
            // DesignTokens.spacingStandard); = the user's "width is wrong"
            // complaint was the duplicate-render path bypassing the
            // existing chromePaddingVertical / card chrome contract).
            bookDocsGrid(docs: filteredDocs)
        }
    }

    /// Empty scope: empty state with hint to select a sidebar item.
    @ViewBuilder
    private func emptyScopeView() -> some View {
        emptyState(
            icon: "book.pages",
            titleKey: "preview.empty_state.pick_book",
            bodyKey: "preview.empty.scope_hint"
        )
    }

    // MARK: - 3 view modes

    /// deleted `singleEntityDetail(_ entity: Reference) -> some View` (=
    /// verify-dead reports ext=0 + int=0; = 0 callers; = the function was a
    /// 3-mode dispatcher child for entity detail; = the parent body in
    /// PreviewPane uses `singleEntityDetail` is wired via Switch case in the
    /// parent body which now uses a different rendering path — see git history
    /// for the full deleted body; = no behavior change; = 80 LOC removed). Mode
    /// 2: category-scoped grid (= only entities in this category).
    @ViewBuilder
    private func categoryGrid(category: EntityCategory, allEntities: [Reference]) -> some View {
        let inCategory = allEntities.filter { $0.category == category }
        // removed the category header HStack (= icon + category.displayName + count). Per
        // the rule: 'in the reference library, the title in the red box in the
        // material preview area is unused, not needed, delete it'. The sidebar
        // already shows the category name (= when user clicks reference-
        // library/History-Geography, the sidebar shows the selection); the
        // preview pane's category header is redundant. Now the preview pane
        // jumps directly to the card grid (= card thumbnails + card content).
        // preview area content isn't fully displayed when width was narrowed
        // preview area doesn't auto-adapt the width' = preview pane content
        // area is narrower than the pane (= 184 PT vs ~430 PT) because the
        // outer VStack has no .frame(maxWidth: .infinity) = the inner
        // GeometryReader takes the parent's intrinsic width (= 0) = the
        // LazyVGrid falls back to a single column at narrow width = sort
        // button / trailing icons at right edge get clipped by the content
        // width, NOT the pane width. Fix = .frame(maxWidth: .infinity) on the
        // outer VStack so GeometryReader reports the full pane width.
        VStack(alignment: .leading, spacing: 0) {
            if inCategory.isEmpty {
                emptyState(
                    icon: "book.pages",
                    titleKey: "preview.empty_state.category_empty",
                    bodyKey: "preview.empty.import_hint"
                )
            } else {
                categoryGridContent(inCategory: inCategory)
            }
        }
    }

    /// Non-empty branch of categoryGrid (= the GeometryReader + ScrollView +
    /// LazyVGrid + animations + contentInset pipeline). Apple HIG canonical
    /// pattern: when an if/else has a heavy non-empty branch (= 5 nested view
    /// frames here: GeometryReader → ScrollView → LazyVGrid → ForEach →
    /// referenceCategoryCard), extract it into a named @ViewBuilder helper (=
    /// categoryGrid goes from 7 nested views to 4; = the function call flattens
    /// the entire GeometryReader/ScrollView/LazyVGrid pipeline into one frame
    /// in the parent body; = the parent categoryGrid body becomes: VStack →
    /// if/else → emptyState/categoryGridContent = 4 frames; = the deepest path
    /// through the file is now 5 = the per-helper's internal nesting).
    @ViewBuilder
    private func categoryGridContent(inCategory: [Reference]) -> some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                    ForEach(inCategory) { entity in
                        // (see OOB.md #2026-09-08) — 'card, show': the trailing closure
                        // here IS Card's onDoubleClick (= now
                        // takes the CardSource as a
                        // parameter). Forward that source to
                        // PreviewPane's onDoubleClick (= which
                        // opens THIS specific card in the
                        // editor, not the topmost card = the
                        // previous filtered.first bug).
                        referenceCategoryCard(entity)
                            // Cards fade in on sidebar tap: individual Card gets an
                            // opacity + scale entry
                            // transition. When the user
                            // types in the search field,
                            // matching cards fade + scale
                            // in and non-matching cards
                            // fade out (= the
                            // .animation(.smooth, value:)
                            // on the LazyVGrid triggers
                            // each card's transition as
                            // SwiftUI adds or removes it
                            // from the diff).
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                // per-card animation trigger (= fires on every Card add/remove within
                // this categoryGrid). Reading `inCategory.map(\.id)`
                // produces an Equatable sequence SwiftUI can diff (=
                // when the IDs change = some cards added/removed = the
                // cards' .opacity / scale transitions play). 180 ms =
                // matches the LazyVGrid default fade duration.
                .animation(.smooth(duration: 0.18), value: inCategory.map(\.id))
                // STYLES-006 (2026-09-07): use the canonical content inset modifier (= 0
                // PT = matches sidebar / editor behavior = content
                // sits right below the chrome tier separator with no
                // extra gap). Previously
                // (.contentInsetStyle(.standard, edges: .vertical) =
                // 18 PT) created a 35 PT inconsistency vs zone 1
                // sidebar / zone 3 editor ((see OOB.md #2026-09-07) —
                // round 5 'region, ' = all 6 zones should share the
                // same chrome-tier-to-content-tier inset). The
                // previous 18 PT was Apple's .defaultContentMargins (=
                // NSTextView internal), which doesn't apply to
                // LazyVGrid (= the grid's rows are not text).
                .contentInsetStyle(.none, edges: .vertical)
                // 2026-10-12 round-18 boss directive "还是有 一点间距" — the prior
                // `.frame(maxHeight: .infinity) + .safeAreaInset(edge:
                // .bottom, spacing: 0)` (= round-17 fix) anchored the
                // chrome footer at the column's bottom BUT the safe
                // area inset did NOT extend down to the bottom of the
                // inner ScrollView's content (= SwiftUI's
                // `safeAreaInset` only adds the chrome's outer height
                // to the receiver's bottom safe area, but the inner
                // ScrollView's own bottom safe area stays at 0 = the
                // last card's natural position is at the ScrollView's
                // natural bottom = the gap between the last card and
                // the chrome's Divider = `chrome.padding-top 8 PT + 1
                // PT Divider` ≈ 9 PT visible column-bg gap). Mirror
                // the chat's `contentMargins(.bottom,
                // chatInputBarHeight, for: .scrollContent)` pattern (=
                // explicit content bottom margin equal to the chrome
                // footer's total height; = the last card is pushed up
                // by the full chrome height = 0 PT visible gap between
                // the last card and the chrome footer's Divider). 33
                // PT = `1 (Divider) + 8 (padding-top) + 16 (text
                // intrinsic) + 8 (padding-bottom)` = the chrome
                // footer's total height (= matches the chat's
                // `chatInputBarHeight` which is also the chrome
                // footer's total height).
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
    }

    /// Single Reference card for a category grid (= extracted from
    /// categoryGrid's nested ForEach + Card trailing closure). Apple HIG
    /// canonical pattern for deep view hierarchies (= extract nested trailing
    /// closures into named @ViewBuilder helpers; = one less view layer; =
    /// categoryGrid goes from 8 nested views to 7). The body contains the
    /// Card's onDoubleClick (= the Card source argument; = forwards to
    /// PreviewPane's `onDoubleClick`, which opens THIS specific card in the
    /// editor; = the previous filtered.first bug). the single-card render
    /// helper for the per-category grid (= the per-card `onRename` / `onDelete`
    /// closures are wired here). Extracted from the inline ForEach body so the
    /// closures can capture `entity` (= the right-clicked card's reference; =
    /// the closures set `cardRenaming` / `cardPendingDelete` to that specific
    /// entity; = the user sees a rename / delete flow for the exact card they
    /// right-clicked).
    // (referenceCategoryCard extracted to PreviewPaneGrids.swift in A79; = see that file)


    /// Mode 3: all-entities overview grid (= group by category inline).
    @ViewBuilder
    private func overviewGrid(allEntities: [Reference]) -> some View {
        if allEntities.isEmpty {
            emptyState(
                icon: "book.pages",
                titleKey: "preview.empty_state.reference_empty",
                bodyKey: "preview.empty.import_hint"
            )
        } else {
            // (per the rule 'the material preview area only displays cards of the
            // currently selected directory, so only card flow is needed,
            // just lay them out continuously' + 'material preview area
            // doesn't need this title, cards just tile flat'. Single flat
            // LazyVGrid (= no per-category section headers, no global
            // count header). Cards flow continuously (= wubi-ji sticky-
            // note style). Sort by current `previewSortOrder` (= (see
            // OOB.md #2026-08-30) — default pinyin first letter; user can
            // pick creation time or modification time via top-right sort
            // menu icon).
            let sorted = PreviewPaneOps.sortEntities(allEntities, by: previewSortOrder)
            GeometryReader { geometry in
                ScrollView {
                    LazyVGrid(columns: adaptiveColumns(width: geometry.size.width), spacing: 16) {
                        ForEach(sorted) { entity in
                            Card(
                                source: .reference(entity),
                                onDoubleClick: { source in
                                    onDoubleClick(source)
                                },
                                onRename: { beginReferenceRename(entity) },
                                onDelete: { beginReferenceDelete(entity) }
                            )
                            // per-card transition (= see categoryGrid comment for
                            // rationale).
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    // per-card animation trigger (= search filter add/remove within
                    // overviewGrid).
                    .animation(.smooth(duration: 0.18), value: sorted.map(\.id))
                }
                .padding(.vertical, DesignTokens.spacingStandard)
                // 2026-10-12 round-18 — see the `categoryGridContent` LazyVGrid for the
                // doc on the `.contentMargins(.bottom, 33, for:
                // .scrollContent)` chrome-footer gap-absorber (= 33 PT
                // = the chrome footer's total height; = the last card
                // is pushed up by the full chrome height; = 0 PT
                // visible gap between the last card and the chrome
                // footer's Divider; = 1:1 with the chat footer
                // pattern; = matches the chat's `chatInputBarHeight`
                // content margin).
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
    }

    /// Empty-state placeholder ((see OOB.md #2026-08-27) — '...no markdown body
    /// = leave a clear empty state, not a blank white pane').
    @ViewBuilder
    // (emptyState extracted to PreviewPaneGrids.swift in A79; = see that file)


    /// the 3 helpers that the right-click `Card` callbacks call into. They
    /// mirror the `AppleSidebarView` `renaming` / `pendingDelete` state pattern
    /// (= the rename sheet + delete alert pick up the local @State and show the
    /// corresponding UI). The service is built lazily from the same closures
    /// the sidebar uses (= the same source of truth for the business methods
    /// `renameReference` / `deleteReference`). Lazy service init (= the service
    /// is an actor; = we build it on first access and cache it in
    /// `cardService`). Returns the service (= creates a new one if the cache is
    /// empty).
    private func ensureCardService() -> SidebarService {
        if let cached = cardService {
            return cached
        }
        let service = SidebarService(
            loadShelves: { try self.bookStore.sidebarLoadShelves() },
            loadAllBooks: { try self.bookStore.sidebarLoadAllBooks() },
            loadReferences: { try self.bookStore.loadAllReferences() },
            bookStore: self.bookStore
        )
        cardService = service
        return service
    }
    // (beginReferenceRename extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginReferenceDelete extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginBookDocRename extracted to PreviewPaneCardActions.swift in A80; = see that file)

    // (beginBookDocDelete extracted to PreviewPaneCardActions.swift in A80; = see that file)


    /// helper for shelfScopeView. Returns the books that live under the given
    /// shelf (= the books whose `.shelfId` matches). Reads from the same
    /// BookStore.sidebarLoadAllBooks source the sidebar already uses (= single
    /// source of truth; = no parallel book list). Returns [] (= empty shelf =
    /// empty-state card grid) when the lookup fails (= disk error) so the
    /// caller doesn't have to do its own error-handling.
    private func loadBooksInShelf(shelfId: UUID) -> [Book] {
        return PreviewPaneOps.loadBooksInShelf(bookStore: bookStore, shelfId: shelfId).books
    }

    /// pre-computes the shelf's books exactly once per shelfId change (= called
    /// from `.task(id: shelfId)` at the call site). SwiftUI cancels any
    /// in-flight task and restarts it whenever shelfId changes, so the cache is
    /// always fresh (= re-load on shelf switch) but never re-evaluates on
    /// parent re-renders. The result lands in `@State cachedShelfBooks` (= the
    /// shelf subtree reads from cache, not from disk = no I/O storm = no
    /// SwiftUI NSHostingView constraint cycle).
    @MainActor
    private func loadShelfBooksAsync(shelfId: UUID) async {
        let result = await PreviewPaneOps.loadShelfBooksAsync(bookStore: bookStore, shelfId: shelfId)
        cachedShelfBooks[shelfId] = result.books
    }

    /// load .md files from a book folder on the filesystem. Walks all shelves
    /// (= shelves/<shelf>/books/<book>/) to find the matching bookId, then
    /// scans one or more of the 8 standard folders for .md files. Errors (=
    /// missing folders, permission denied, etc.) are silently skipped so a
    /// single bad folder doesn't break the whole view (= partial load is more
    /// useful than nothing).
    /// Sort book docs by the current sort order (= same menu as entity scope,
    /// but applied to BookDoc). (see OOB.md #2026-08-31) — sort still defaults
    /// to .pinyinFirstLetter so docs in Chinese filenames also flow
    /// alphabetically.
    /// Sort entities by the selected sort order ((see OOB.md #2026-08-30)).
    /// Returns a NEW array (doesn't mutate input). Stable sort by using id as
    /// the tiebreaker (= prevents visual shuffle on re-render when entities
    /// have equal sort keys).
    /// Flat LazyVGrid for book docs (= same visual style as entity card grid,
    /// but BookDocCard instead of EntityCard).
    @ViewBuilder
    private func bookDocsGrid(docs: [BookDoc]) -> some View {
        let sorted = PreviewPaneOps.sortBookDocs(docs, by: previewSortOrder)
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: adaptiveColumns(width: geometry.size.width),
                    spacing: 16
                ) {
                    ForEach(sorted) { doc in
                        Card(
                            source: .bookDoc(doc),
                            onDoubleClick: { source in
                                onDoubleClick(source)
                            },
                            onRename: { beginBookDocRename(doc) },
                            onDelete: { beginBookDocDelete(doc) }
                        )
                        // per-card transition (= see categoryGrid comment for rationale).
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                // per-card animation trigger (= search filter add/remove within
                // bookDocsGrid).
                .animation(.smooth(duration: 0.18), value: sorted.map(\.id))
                .padding(.vertical, DesignTokens.spacingStandard)
                // 2026-10-12 round-18 — see the `categoryGridContent` LazyVGrid for the
                // doc on the `.contentMargins(.bottom, 33, for:
                // .scrollContent)` chrome-footer gap-absorber.
                .contentMargins(.bottom, 33, for: .scrollContent)
            }
        }
}

/// Card view for a single entity in the grid. Tap = select (= not wired yet).
/// Double-click = open in editor (= the card-double-click hook).
// (per the rule): 'card, '. Thumbnail
// (CardSource extracted to PreviewPaneCard.swift in A33; = see that file)


// (Card extracted to PreviewPaneCard.swift in A33; = see that file)

}
