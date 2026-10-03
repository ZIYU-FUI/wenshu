// ShellMiddleColumn.swift · Wenshu
//
// Extracted from `NavigationSplitShell.swift`. Apple HIG content
// column (= 1 zone: the card grid) for the macOS 27
// NavigationSplitView shell. The 26-line Apple HIG doc + the
// 410-line SwiftUI body (= card grid wrapper + sort toolbar)
// move verbatim. 0 behavior change.
//
// Out of scope (= future ticket):
// - ShellDetailColumn

import SwiftUI

/// Apple HIG content column (= 1 zone: the card grid).
/// Cards zone is middle-right (= the Apple 5-zone pattern, not 6);
/// = per the 'visual 5 columns' design directive. The middle
/// column carries exactly 1 zone (PreviewPane = the card grid).
/// The previously rendered bottom outline sub-area (= the pre-v1.69e
/// NewLibraryOutlineView = the same directory tree the sidebar uses)
/// is removed (= the outline is the sidebar's job; duplicating it in
/// the middle column is noise).
///
/// Remove the tab, keep just the cards content: the sidebar
/// bottom card zone (= previously ZoneContentView with two
/// tabs 'Preview / Image' = a .pickerStyle(.segmented) TabBar
/// over a PreviewPane) is gone. PreviewPane now renders the
/// card grid without any tab chrome (= Apple's empty state +
/// search bar + the actual grid = the canonical pattern Xcode /
/// Photos / Music use for unfiltered list views).
///
/// Drop the floating panel, just split the middle column in two:
/// the previous float-over-document layout fought NSTextView's
/// hit test (= an NSTextView on top of another NSTextView makes
/// cursor + click ownership ambiguous). The previous VSplitView
/// held cards on top + outline on bottom; per the 'we don't need
/// that red-box area' design directive, the VSplitView is gone
/// too and the card zone owns the full column height.
struct ShellMiddleColumn: View {
    // The cards column did not re-render when the user clicked a
    // reference category in the sidebar. Root cause: `let appState:
    // AppState` (= a plain stored property holding an `@Observable`
    // instance) does NOT participate in SwiftUI's Observation
    // Framework tracking when the view body reads `appState.
    // sidebarSelection`. The `@Observable` macro generates
    // `withObservationTracking` hooks keyed to the *direct* property
    // access on a tracked reference (= `@Environment` / `@State` /
    // `@Bindable`); a plain `let` field is treated as a non-tracked
    // read, so the view body never re-renders when
    // `sidebarSelection` mutates.
    //
    // Fix: switch to `@Bindable var envAppState: AppState` (= the
    // canonical SwiftUI Observation entry point for `@Observable`
    // instances; = reads of `envAppState.x` register tracking; =
    // body re-renders on every mutation; = supports
    // `$envAppState.x` binding syntax for Picker/Toggle). The
    // `init` / call sites that previously passed `appState: appState`
    // as a parameter can keep passing it for backwards compat (= the
    // let field is kept as a no-op shim so callers don't have to
    // change) but the @Bindable entry takes precedence for
    // observation tracking inside body.
    @Bindable var envAppState: AppState
    let appState: AppState
    // previewSortOrder / sidebarSelection / activeTag live in
    // WorkspaceUIState. The card grid's `previewSortOrder`
    // binding (= passed to PreviewPane) reads via `workspaceUI`
    // (= the @Bindable Observable instance = observation
    // tracking on every body render).
    @Bindable var workspaceUI: WorkspaceUIState
    // `openCardInEditor` needs `BookStore.referenceStore` to load
    // reference bodies for double-clicked cards (= the same env
    // chain `WorkspaceView.openCardInEditor` uses via
    // `@Environment(BookStore.self)`). Optional because the env
    // chain may not be ready on early launch (= silent no-op
    // fallback in `openCardInEditor`).
    @Environment(BookStore.self) private var envBookStore

    private var bookStore: BookStore? { envBookStore }

    // `previewSortOrder` lives in `envAppState.previewSortOrder`
    // (= single source of truth; = shared across all columns; =
    // survives column collapse-expand; = future changes to one
    // place propagate to all readers).
    //
    // Access pattern: `$envAppState.previewSortOrder` is the
    // SwiftUI binding (= AppState is @Observable; = property
    // changes trigger view re-render via Observation framework).

    // Use `envAppState.searchText` (= the AppState @Observable
    // property) instead of a local @State. This lets the
    // .searchable modifier on the cards column share the same
    // search state with any future .searchable modifiers on
    // the sidebar / inspector (= the canonical SwiftUI
    // Observation pattern for app-wide search state; = single
    // source of truth; = no string-threading across columns).
    // envAppState is the @Environment(AppState.self) entry that
    // already registers Observation tracking on the cards
    // column body (= body re-renders on every mutation).
    private var searchText: String {
        get { envAppState.searchText }
        nonmutating set { envAppState.searchText = newValue }
    }

    /// Tree selection → cards column. Selecting `.book(worldview)`
    /// in the sidebar showed `.empty` in the cards column instead
    /// of the book's `.md` cards. The previous version mapped
    /// `.book` / `.shelf` / `.folder` ALL to `.empty` (= cards
    /// column blanked out for any user-scope row). The correct
    /// mapping per `PreviewScope` enum:
    /// - `.referenceLibraryRoot` / nil → `.referenceScope(nil)`
    ///   (= overview grid of all entities across categories)
    /// - `.referenceCategory(let dirName)` → `.referenceScope(
    ///   EntityCategory(rawValue: dirName))` (= one category only)
    /// - `.book(let id)` → `.bookScope(bookId: id, folderName: nil)`
    ///   (= the book with ALL its folders' .md cards = the user
    ///   wants to see the book's content)
    /// - `.shelf(let id)` → `.shelfScope(shelfId: id)` (= shelf hint,
    ///   per PreviewScope comment: 'shelves are a tree level, not
    ///   a document scope' = the preview pane shows a hint to
    ///   drill into a book)
    /// - `.folder(let bookId, let folderName)` → `.bookScope(bookId,
    ///   folderName: folderName)` (= the folder's .md cards only)
    /// - Invalid dirName (= no matching EntityCategory) falls back
    ///   to `.referenceScope(nil)` so a broken reference selection
    ///   doesn't lock the user out.
    /// Without this fix, selecting ANY user-scope sidebar row (=
    /// book / shelf / folder) showed 'Please pick a node on the
    /// left to view the document' even though a real selection was
    /// active.
    ///
    /// Map `sidebarSelection` → `PreviewScope`. The case-mismatch
    /// bug (sidebar wrote lowercase directoryName 'b' but entities
    /// JSON stored uppercase rawValue 'B') was fixed at the sidebar
    /// tag + onChange lookup sites; by the time `previewScope()`
    /// reads `appState.sidebarSelection`, the dirName is already
    /// the uppercase rawValue, so `EntityCategory(rawValue: dirName)`
    /// succeeds (= `.b` for Philosophy / 'B') and `.referenceScope
    /// (cat)` reaches `categoryGrid(category: cat, ...)` which
    /// filters `allEntities.filter { $0.category == category }`
    /// correctly.
    private func previewScope() -> PreviewScope {
        // Read from `envAppState` (= the @Environment-tracked
        // Observable instance), NOT from the `let appState` field
        // (= which doesn't register Observation tracking; = previous
        // code's `previewScope()` read stale data because the body
        // never re-rendered).
        switch workspaceUI.sidebarSelection {
        case .referenceLibraryRoot:
            return .referenceScope(nil)
        case .referenceCategory(let dirName):
            // SidebarItem.referenceCategory(directoryName) carries
            // the EntityCategory.directoryName (= lowercase letter
            // for the official 22 CLC cases, "其它" for the .z
            // fallback, "未分类" for pre-v0.29 nil-category
            // references). EntityCategory rawValues are uppercase
            // letters (= "A" .. "Z"), so a case-insensitive lookup
            // restores the canonical form.
            //
            // Previous behavior: the rawValue lookup was
            // case-sensitive, so a lowercase dirName produced nil →
            // fall-back to `.referenceScope(nil)` = the user picked
            // a category but the middle column showed the full
            // overview.
            if let raw = EntityCategory(rawValue: dirName) {
                return .referenceScope(raw)
            }
            let upper = dirName.uppercased()
            if let raw = EntityCategory(rawValue: upper) {
                return .referenceScope(raw)
            }
            return .referenceScope(nil)
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .shelf(let shelfId):
            return .shelfScope(shelfId: shelfId)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case .tag(let tagString):
            // v2.9d T37 (boss 2026-09-28 OOB A7 follow-up):
            // a tag selection now sets workspaceUI.activeTag
            // (= PreviewPane reads workspaceUI.activeTag
            // to filter its card grid by tag). Previously
            // the tag route fell through to .referenceScope
            // (= no real filter applied; = tag chip was a
            // dead UI affordance).
            workspaceUI.activeTag = tagString
            return .referenceScope(nil)
        case nil:
            return .referenceScope(nil)
        }
    }

    // The card double-click handler reads the actually-clicked
    // CardSource from the parameter (= not the topmost card;
    // = prevents the 'clicking Dufu card opens a tab with wrong
    // name' regression). Mirrors `WorkspaceView.openCardInEditor`
    // logic.
    //
    // Differences from `WorkspaceView.openCardInEditor`:
    // 1. Reads `previewScope()` (= NavigationSplitShell's helper;
    //    = the equivalent of WorkspaceView's `previewScope`
    //    computed property).
    // 2. mode = .edit (= 'opening a document means edit state' =
    //    the user wants the WenshuMarkdownEditor's editable NSTextView,
    //    NOT the read-only preview; = uses the SM third-party md
    //    editor's edit surface directly).
    // 3. Reads `bookStore?` (= NavigationSplitShell threads it as
    //    an optional via @Environment(BookStore.self); = if nil,
    //    falls back to the empty body path).
    //
    // The duplicate-tab fingerprint check (= first 200 chars of
    // content) is preserved (= the boss 9/3 OOB Safari-style
    // 'switch to existing tab if same .md already open' behavior
    // still applies; = no duplicate tabs).
    //
    /// Thin wrapper over `CardOpenOps` (=
    /// the dedup + EditorTab + activeTabId mutation shared with
    /// WorkspaceView + ZoneModuleView). Same `mode = .edit` per
    /// ShellMiddleColumn's specific UX (= WenshuMarkdownEditor's
    /// editable NSTextView from the start).
    private func openCardInEditor(source: CardSource?) {
        let scope = previewScope()
        let triad = CardOpenOps.computeCardTriad(
            source: source,
            previewScope: scope,
            bookStore: bookStore
        )
        _ = CardOpenOps.openTab(
            triad: triad,
            previewScope: scope,
            appState: envAppState,
            mode: .edit
        )
    }

    var body: some View {
        // + 'we only need the original assets cards':
        // the middle column is exactly 1 zone = the reference library
        // overview grid (= PreviewPane with scope = .referenceScope(nil)
        // = ALL entities across categories). This is the canonical
        // 'material cards' view = Xcode's project navigator cards /
        // Photos' library = unfiltered entity grid per category with
        // sort = first letter (= the boss 8/30 OOB default).
        //
        // Why .referenceScope(nil) and not .empty:
        // - .empty renders Apple's ContentUnavailableView (= an
        //   informational placeholder = NOT the cards themselves).
        //   The column must show the actual card grid (= the entities),
        //   even with no sidebar selection.
        // - .referenceScope(nil) = overview grid of all entities in
        //   the reference library (= Characters / Worldview / Books / Volumes / etc.). When
        //   the user later clicks a sidebar row, AppState can route
        //   a category-scoped scope (= .referenceScope(.some)) into
        //   the PreviewPane for filtered view.
        //
        // No VSplitView wrapper, no outline sub-area, no chapter tree.
        // No navigationTitle: the column-level header (= the NavigationSplitView column
        // title bar = 'Cards' + library subtitle 'anbaiqiang.ws') is
        // removed. The column content (= the cards themselves) is
        // self-explanatory; an extra title bar is noise on a single-
        // zone column.
        //
        // The previous `.toolbar { ToolbarItem(.principal) { ...
        // } }` route (= commit dff49498d) put the search field in
        // the window toolbar (= not in the column body). Drop the
        // .toolbar wrapper and let PreviewPane's internal
        // `previewSearchBar` render inline (= Apple's macOS 13+
        // rounded-pill pattern hosted at the top of the column
        // body = same visual slot as the sidebar's `.searchable`
        // field at the top of the sidebar column).
        //
        // The previous `.referenceScope(nil)`
        // (= unfiltered overview grid of every entity in the library)
        // ignored sidebar selection entirely (= clicking Philosophy & Religion
        // / Military / Economics / Literature / History & Geography / Other in the sidebar had
        // no effect on the cards column = the bug boss is reporting).
        // Switch the scope based on `appState.sidebarSelection` so the
        // cards column follows the sidebar:
        //   - sidebarSelection == .referenceLibraryRoot or nil
        //     → .referenceScope(nil) (= overview; = the 6 categories
        //     collapse state on the sidebar root; = same as before)
        //   - sidebarSelection == .referenceCategory(let dirName)
        //     → .referenceScope(.some(dirName)) (= only entities in
        //     the picked category show up)
        //   - sidebarSelection == .book(let bookId) / .shelf(...) /
        //     .folder(...) → .empty (= no preview yet; = clicking a
        //     user shelf or book is preview-zone's blank state)
        // All branches are exhaustive over SidebarItem cases (= no
        // unknown-sidebar-selection fallback path = the bug can't
        // reappear silently).
        // Wire the Apple `.searchable` system-styled search field to
        // the live `envAppState.searchText` (= the AppState
        // @Observable property; = single source of truth for app-wide
        // search state; = multiple columns can attach .searchable
        // to the same binding to share search text). Pass the
        // binding to PreviewPane so its `searchQuery` Binding resolves
        // to the live `envAppState.searchText` (= the filter applies
        // correctly; = survives PreviewPane re-instantiation).
        VStack(spacing: 0) {
            // Place the search field at the LEADING (= left) edge of the cards
            // column's top bar (= flush to the column's left margin).
            // The SwiftUI `.searchable` modifier is hard-wired to
            // render in the TRAILING edge of any column toolbar (=
            // Apple macOS 27 Mail / Notes / Finder all have their
            // search box on the trailing side, so that's the
            // framework default). To override the LEADING-positioned
            // search field preference, drop the `.searchable`
            // modifier and render a custom TextField instead (= the
            // same TextField-with-search-icon that `.searchable`
            // produces internally; = bound to the same
            // `envAppState.searchText` state so the search filter
            // in PreviewPane keeps working). Place the custom
            // search field in a `.frame(maxWidth:.infinity,
            // alignment: .leading)` so it sits flush to the LEFT
            // edge of the cards column. ⌘F still works (= Apple
            // system shortcut) because the search field IS in the
            // view hierarchy.
            //
            // The search field now fills the full column width via (= .frame(maxWidth: .infinity,
            // alignment: .leading) so it stretches as the user
            // drags the column wider, matching the card grid's
            // intrinsic width). Removed the previous hard-coded
            // .frame(minWidth: 120, maxWidth: 240) (= a fixed 120-240
            // PT search bar that didn't track the column's width).
            //
            // The outer VStack (= the entire PreviewPane column = the search
            // field + cards + empty-state) gains a 10 PT horizontal
            // padding (= chromePaddingContentHorizontal = the same
            // gutter token for search field / cards). Search field +
            // cards DROPPED their inner .padding(.horizontal, ...)
            // (= would have stacked with the column padding = 10 +
            // 10 = 20 PT total). Search field
            // also switches to .controlSize(.large) (28 PT control
            // height) + .padding(.vertical, chromePaddingMicro = 4
            // PT) (= 28 + 4 × 2 = 36 PT total height = the
            // user-specified 36 PT without hard-coding a frame
            // height = Apple semantic expression per the boss's
            // '不要硬编码, 用 Apple 表达式' rule).
            //
            // Note: dropped `.searchable` because the framework's
            // own search box was rendering trailing regardless of
            // the `placement:` parameter (= `.automatic` /
            // `.toolbar` both = trailing in macOS 27 NavigationSplit
            // columns; = a documented framework limitation).
            // The custom TextField below gives us full control
            // over placement (= left-aligned, per the boss).
            //
            // Note: PreviewPane does NOT take a `searchText:` arg
            // (= the search state lives in envAppState.searchText,
            // a global; = PreviewPane's `searchQuery: Binding<String?>`
            // already reads/writes through envAppState). The
            // wrapper stays as a thin pass-through; = the search
            // field rendered here and the search filter inside
            // PreviewPane share the SAME binding = typing in one
            // updates the other live (= the same envAppState.searchText).
            PreviewPane(
                scope: previewScope(),
                // Card double-click opens the document in the editor pane
                // pane (= mode = .edit = the WenshuMarkdownEditor
                // editable surface from the start; = not a separate
                // window). Forward the clicked CardSource so the
                // correct entity opens (= not the topmost card =
                // BOSS 9/8 'clicking Dufu card opens tab with wrong
                // name' regression).
                onDoubleClick: { source in
                    openCardInEditor(source: source)
                },
                previewSortOrder: $workspaceUI.previewSortOrder,
                searchQuery: Binding<String?>(
                    get: { envAppState.searchText },
                    set: { newValue in envAppState.searchText = newValue ?? "" }
                ),
                customLeadingSearch: AnyView(
                    HStack(spacing: DesignTokens.spacingIconic) {
                        SFIcon("magnifyingglass", style: .inlineSmall, color: IconColor.secondary)
                        TextField(
                            WenshuI18n.t("preview.search.placeholder"),
                            text: Binding(
                                get: { envAppState.searchText },
                                set: { newValue in envAppState.searchText = newValue }
                            )
                        )
                        // Apply `.controlSize(.regular)` (= the canonical
                        // macOS 13+ SwiftUI semantic expression for
                        // standard form-control height = maps to
                        // NSTextField regular controlSize = 22 PT
                        // = matches Apple's Mail / Notes / Finder
                        // NO hard-coded `.frame(height: 30)`.
                        // The search field total height must match the sidebar selection row height (= chromeHeight = 30 PT, = the same Apple HIG standard sidebar-row height used for the sidebar's selected rows). Used `.controlSize(.large)` + chromePaddingMicro (= 28 + 4 × 2 = 36 PT = 6 PT taller than the sidebar row = visually inconsistent across the two columns). Switch back to `.controlSize(`
                        // .regular) (22 PT) + chromePaddingMicro
                        // (4 PT × 2) = 30 PT = exact match to
                        // chromeHeight (= Apple semantic expression
                        // = no hard-coded frame height = the search
                        // field and the sidebar row now form a
                        // matched-height rhythm across the
                        // NavigationSplitView).
                        .controlSize(.regular)
                        .textFieldStyle(.plain)
                    }
                    // Total height = 22 PT
                    // (controlSize .regular) + 6 PT × 2 = 34 PT,
                    // 这个需要再改, 还是得 8PT, 6 不够': the
                    // search field INNER vertical padding is
                    // chromePaddingMedium (= 8 PT) on each side =
                    // 16 PT total vertical breathing room between
                    // the icon / TextField and the RoundedRectangle
                    // background top / bottom edges. Boss
                    // experimented with 6 PT (= '用六的') and
                    // decided 8 PT (= '还是得 8PT') = the rect
                    // needs more vertical room = the
                    // chromePaddingSmall (= 6 PT) was visually
                    // cramped.
                    //
                    // The search field border
                    // 左右距离素材栏栏边的间距没有生效': the
                    // outer .padding(.horizontal, 10) modifier
                    // was placed AFTER .background(...) in the
                    // The chain (= HStack content → padding
                    // .vertical → frame → background → padding
                    // .horizontal). The SwiftUI layout system
                    // honors that order, but the background fills
                    // the parent's maxWidth regardless (= the
                    // padding wraps the framed view but the
                    // background is drawn at maxWidth). Re-orders: HStack content → padding
                    // .horizontal → padding .vertical → frame
                    // → background. The padding now sits INSIDE
                    // the frame (= the padded view reports a size
                    // = maxWidth; = the background then draws on
                    // the padded view = the background now stands
                    // 10 PT away from each column edge).
                    // 10 PT away from each column edge (= chat transcript
                    // content horizontal padding = chromePaddingContentHorizontal
                    // = shared single source of truth across the chat
                    // transcript = Apple HIG canonical macOS chat column
                    // gutter).
                    .padding(.horizontal, DesignTokens.spacingModerate)
                    .padding(.vertical, DesignTokens.spacingStandard)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    // The search field,
                    // spacing between it and the first card — is there a hand-written padding, and if
                    // so, drop it': drop the manual `.padding(.vertical,
                    // 4)` (= 4 PT top + 4 PT bottom = hand-rolled
                    // breathing room inside the search HStack) =
                    // the outer PreviewPane layer handles vertical
                    // spacing (= `.padding(.top, 4)` for the gap
                    // above the search field; = no bottom padding
                    // so the search field sits flush against the
                    // first card; = the LazyVGrid handles card-to-
                    // card spacing). Keep only the `.padding(.horizontal,
                    // 8)` (= Apple HIG 8-point grid for inline
                    // content horizontal inset).
                    // Fill the width automatically,
                    // grow with the drag just like the cards do': the search field
                    // now fills the full column width (= the
                    // `.frame(maxWidth: .infinity)` modifier
                    // forces SwiftUI to stretch this HStack to
                    // consume all available horizontal space in
                    // its parent; = the search field now matches
                    // the LazyVGrid's full grid width; = as the
                    // user drags the column wider, both the cards
                    // and the search field stretch together).
                    //
                    // Why not use `alignment: .leading` (= the
                    // earlier preference for left-alignment):
                    // the LazyVGrid cards are center-aligned within
                    // the column (= the card grid is centered to
                    // keep the 2-column rhythm visually balanced);
                    // = the search field should also be center-
                    // aligned to track the cards' visual position.
                    // The inner HStack's leading-left Image +
                    // TextField still keep the icon flush to the
                    // search field's left edge (= the field is
                    // wider but the icon stays at the field's own
                    // left; = no visual change inside the field).
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusProgressCard, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    // Search field
                    // 的描边掉, 不要描边': drop the stroke
                    // overlay (= the macOS 27 hairline stroke on
                    // top of the rounded rectangle = 'no border' call. The fill stays (= the
                    // visual background the user requested =
                    // visible inset rectangle without the hairline
                    // edge = flat fill style = the Apple Music /
                    // Apple Notes 'pill' fill without border = the
                    // '更协调' aesthetic per the search-field rhythm.
                )
            )
            // Header (= assets + divider
            // 也被内边距影响了, 需要像目录树和右栏一样, 让标题不
            // 受栏的内边距影响, 让分割线拉满整栏': drop the
            // PreviewPane-column-level .padding(.horizontal,
            // chromePaddingContentHorizontal). The column-level
            // padding affected the SectionHeader (= divider + title
            // shrank by 10 PT from each side = not flush to the
            // column edges). Per the user's request, SectionHeader
            // must stay flush to the column edges (= like the
            // sidebar's SectionHeader at AppleSidebarView L103 + the
            // inspector's SectionHeader at ShellDetailColumn = both
            // are NOT wrapped in any horizontal padding). The
            // padding instead moves DOWN to the per-element level
            // (= search field HStack + card grid each carry their
            // own 10 PT horizontal padding = single horizontal
            // gutter rhythm across the column without affecting
            // the column-top chrome).
        }
    }
}
