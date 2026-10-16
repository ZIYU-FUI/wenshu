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
    @Environment(BookStore.self) var bookStore

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
    @State var cardService: SidebarService?

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
    @State var cachedShelfBooks: [UUID: [Book]] = [:]

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
    var resolvedSearchQuery: String {
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

    // (referenceScopeView extracted to PreviewPaneScopeViews.swift in A82; = see that file)

    // (bookScopeView extracted to PreviewPaneScopeViews.swift in A82; = see that file)

    // (shelfScopeView extracted to PreviewPaneScopeViews.swift in A82; = see that file)


    /// Empty scope: empty state with hint to select a sidebar item.
    // (categoryGrid extracted to PreviewPaneGrids.swift in A84; = see that file)

    // (categoryGridContent extracted to PreviewPaneGrids.swift in A84; = see that file)

    // (overviewGrid extracted to PreviewPaneGrids.swift in A84; = see that file)


    /// Empty-state placeholder ((see OOB.md #2026-08-27) — '...no markdown body
    /// = leave a clear empty state, not a blank white pane').
    // (ensureCardService extracted to PreviewPaneDataAccess.swift in A83; = see that file)

    // (loadBooksInShelf extracted to PreviewPaneDataAccess.swift in A83; = see that file)




/// Card view for a single entity in the grid. Tap = select (= not wired yet).
/// Double-click = open in editor (= the card-double-click hook).
// (per the rule): 'card, '. Thumbnail
// (CardSource extracted to PreviewPaneCard.swift in A33; = see that file)


// (Card extracted to PreviewPaneCard.swift in A33; = see that file)

}

