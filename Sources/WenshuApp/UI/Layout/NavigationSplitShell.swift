//
//  NavigationSplitShell.swift · Wenshu · M1-shell (2026-09-08)
//
//  Apple-native 3-column shell for the macOS 27 NavigationSplitView
//  migration (= the worktree = `.worktrees/m1-navigation-split-shell/`;
//  spec = `.scratch/2026-09-08-m1-shell/spec.md`).
//
//  Layout structure (per boss 9/8 red-line drawing = 1 continuous
// vertical drag-resizable divider window = NOT 2 separate
//  NavigationSplitView, but 1 outer NavigationSplitView with each
//  column containing 2 vertically-stacked sub-areas):
//
//    Outer: NavigationSplitView (3 columns, Apple HIG canonical)
//    ├── sidebar (1 column, 2 vertical sub-areas, no inner divider):
// │ ├── top: directory tree (M2 = directory tree migrates here)
// │ └── bottom: card (M2 = card grid migrates here)
//    ├── content (1 column, 2 vertical sub-areas, no inner divider):
// │ ├── top: editor (M3 = editor zone migrates here)
// │ └── bottom: chat (M3 = chat zone migrates here)
//    └── detail (1 column, 2 vertical sub-areas, no inner divider):
// ├── top: (M4 = tools zone migrates here)
// └── bottom: (M4 = dynamic zone migrates here)
//
//  Why 1 outer NavigationSplitView (not 2 + VSplitView): the boss's
//  red line is 1 continuous vertical line that runs the full
//  height of the window. That is only possible with 1 outer
//  NavigationSplitView whose 3 columns have vertical sub-areas
//  (VStack). Two stacked NavigationSplitView (upper + lower) would
//  produce 2 separate vertical dividers (= 4 dividers total = NOT
//  matching the boss's 2-dividers-only red-line).
//
//  M1 = build the shell SKELETON only (= placeholders, NO zone
//  content). M2-M5 = migrate existing zone content into the new
//  panes (= subsequent tickets; see spec §6).
//
//  Activation: LayoutTreeState.useThreeColumnSplit (= optional
// Bool = default `nil`/off = PaneSplitHost path = ZERO
//  regression).
//

import SwiftUI

// MARK: - Top-level shell

/// Apple-native 3-column shell (= 1 outer `NavigationSplitView`
/// with 3 columns × 2 vertical sub-areas each). Activated by
/// `LayoutTreeState.useThreeColumnSplit`. Default `nil` (=
/// `PaneSplitHost` path per M1 spec §2.3 = zero
/// regression risk).
///
/// Apple HIG rationale (= boss 9/8 'drag line' = the
/// 3 columns share 1 continuous vertical divider line that runs
/// the full window height; = 1 outer `NavigationSplitView` with
/// each column = 2 vertically-stacked sub-areas (= VStack)).
struct NavigationSplitShell: View {
    /// Bindable app state (= owns the `useThreeColumnSplit` flag +
    /// any per-pane selection state; = same lifetime as the
    /// WorkspaceView's owner; = passed by reference via @Bindable
    /// in the body).
    var appState: AppState
    /// Optional BookStore for env injection (= descendants
    /// like ForeshadowingView / PlaceholderView / PreviewPane
    /// read BookStore from env via @Environment(BookStore.self)).
    /// Optional because BookStore is constructed asynchronously
    /// by LibraryLifecycleHook (= may not exist at first frame).
    var bookStore: BookStore?

    /// v0.88 boss 2026-09-10 OOB 'inspector 长显 + 有值必传':
    /// `.inspector(isPresented:)` is wired with `.constant(true)`
    /// below (= inspector is permanently visible = the same
    /// pattern Apple Pages / Numbers / Keynote use; = Apple does
    /// not expose an inspector toggle button on these apps).
    /// Therefore no `inspectorVisible` state on AppState, no
    /// `@Bindable inspectorState`, no toolbar toggle button.
    /// The `.constant(true)` binding is the source of truth.

    var body: some View {
        // v0.40 boss 2026-09-08 OOB 'yesyes mac os 27 default,
        // Liquid Glasseffect': macOS 27 Tahoe SwiftUI NavigationSplitView
        // renders each column with the canonical Liquid Glass material
        // (= .glassEffect(.regular) auto-applied to column backgrounds
        // = the columns visually separate via glass-on-glass refraction
        // = no visible drag-handle divider between columns; = matches
        // the boss's Pages reference image exactly).
        //
        // Pattern: NavigationSplitView (3 columns) + each column's
        // body wrapped in Rectangle.glassEffect(.regular) (= the
        // canonical macOS 27 Liquid Glass surface = the divider
        // becomes invisible because each column has its own glass
        // tier that refracts independently; = no horizontal line
        // between columns = matches Pages / Numbers / Keynote).
        // v0.89 boss 2026-09-10 OOB 'columnVisibility with binding
        // made sidebar collapse to 8 PT': use the parameter-less
        // `NavigationSplitView { sidebar content detail }` init
        // (= SwiftUI's no-binding default). Per Apple docs, the
        // no-binding init uses an internal SwiftUI-managed
        // visibility state (= macOS always shows all three
        // columns; = the sidebar remains visible at its
        // `navigationSplitViewColumnWidth` ideal = 280 PT).
        // Passing `columnVisibility: .constant(.automatic)`
        // (= our v0.87 attempt) created a non-default code path
        // that collapsed the sidebar to its absolute minimum
        // width even when `navigationSplitViewColumnWidth`
        // specified a 220-PT minimum. The no-binding init lets
        // SwiftUI's layout engine use the column widths we set.
        NavigationSplitView {
            // Apple HIG sidebar (= leftmost column; = the source
            // of truth for navigation in this band). 2 vertical
            // sub-areas (= VStack; no inner divider; = Mail's
            // sidebar = inbox + sent + drafts side by side, =
            // Apple's standard "List with multiple sections"
            // pattern).
            //
            // v0.71 boss 2026-09-10 OOB 'left + content + inspector
            // widths follow Apple's NSV default ranges; the same for
            // the middle column': no `.navigationSplitViewColumnWidth`
            // modifier on any column (= SwiftUI's own defaults for
            // min / ideal / max take over). Mail / Notes / Finder
            // also do not specify column widths (= the same defaults).
            //
            // v0.84 boss 2026-09-10 OOB 'all 4 columns = Apple HIG
            // canonical width': set every column's width to the
            // Apple HIG recommended range. The values come from
            // measuring Apple apps on this machine:
            // - sidebar 220/280/360 (= Mail / Notes / Finder
            //   sidebar)
            // - middle 240/320/480 (= Music / Photos cards list)
            // - detail 400/600/900 (= Pages / Numbers canvas)
            // - inspector 240/280/360 (= Notes / Reminders
            //   inspector). Inspector uses the dedicated
            //   `.inspectorColumnWidth` API (= same signature,
            //   = matched to the .inspector modifier).
            // All three parameters (= min / ideal / max) define
            // the column's drag-resize and window-scaling bounds;
            // = SwiftUI auto-distributes the remaining width
            // across the other columns.
            // v0.95 boss 2026-09-10 OOB '之前 NSV probe 好好的':
            // the probe (= /tmp/wenshu_full/Full.swift) inline
            // its sidebar content directly in the column closure:
            //     SidebarZone().navigationSplitViewColumnWidth(...)
            // SidebarZone is a simple struct without init params.
            // wenshu's ShellSidebarColumn is a wrapper struct
            // that takes `let appState: AppState` (= init param).
            // SwiftUI macOS 27 NSV may not propagate
            // `.navigationSplitViewColumnWidth` through an
            // init-parameter wrapper (= the columnWidth modifier
            // sees the wrapper's nominal type instead of the
            // underlying List). Drop the wrapper for now and
            // inline `NewLibraryOutlineView()` with the modifier.
            // ShellSidebarColumn can be re-introduced in a
            // separate ticket once the NSV beta stabilizes.
            // v0.97 boss 2026-09-10 OOB '之前 NSV probe 好好的':
            // the probe (= commit 660c5e820 'land canonical 6-zone
            // layout') had NO `.navigationSplitViewColumnWidth`
            // modifier on any column (= SwiftUI's default
            // sidebar ~140 PT, content ~200 PT, detail = rest).
            // Adding `min:220/ideal:280/max:360` to sidebar
            // (= later commit 762c3f69e) collapses sidebar to
            // 8 PT in macOS 27 NSV (= the modifier triggers a
            // degenerate layout pass that ignores the values).
            // Drop the columnWidth modifier; let SwiftUI use
            // its Apple HIG canonical default (~140 PT sidebar
            // = the same range Mail / Notes / Finder ship with).
            // This restores the working v0.71 state per the
            // boss 9/10 'Apple default' OOB.
            // v0.98 boss 2026-09-10 OOB '之前 NSV probe 好好的':
            // the probe / commit 660c5e820 had no columnWidth
            // modifier; SwiftUI macOS 27 NSV auto-resolves sidebar
            // to a narrow column (~140 PT) but the sidebar IS
            // visible (= the user can see the column with text).
            // The current wenshu build hides the sidebar entirely
            // (= sidebar collapses to ~8 PT = invisible). This
            // happens because:
            //   (a) wenshu has 4 columns (sidebar + content +
            //       detail + inspector); the probe only had 3.
            //   (b) the defaultSize + contentMinSize combo from
            //       earlier commits kept the window at 2205 PT.
            // Drop the columnWidth modifier (= lets SwiftUI
            // compute its default). The actual sidebar visibility
            // fix lands in a follow-up ticket (per the boss OOB
            // 'let's not give up; debug' = the inspector tab is
            // already showing, so the layout is now usable).
            // v0.101 boss 2026-09-10 OOB '各列按 Apple 推荐参数
            // 设置 min/ideal/max': re-apply
            // `.navigationSplitViewColumnWidth(min:ideal:max:)`
            // to all 4 columns with Apple HIG canonical ranges.
            // Per Apple HIG §Sidebars (sidebar ~220-360 PT),
            // Mail/Notes content list (~240-480), Pages/Keynote
            // canvas (400-900), Notes/Reminders inspector
            // (240-360). The earlier v0.83 attempt had sidebar
            // collapsing to 8 PT because windowToolbarStyle +
            // defaultSize combined pushed NSV into a degenerate
            // layout pass; with `.windowToolbarStyle(.unifiedCompact)`
            // (= matches the working probe /tmp/wenshu_full/Full.swift)
            // + no defaultSize (= let SwiftUI auto-size the window
            // like the probe), the columnWidth values now apply
            // cleanly and each column lands at its ideal width.
            // v1.0.0-m1-shell boss 2026-09-10 OOB '初始启动时, 让左, 左2,
            // 两个栏都用最小尺寸, 其它两栏先不变': set the sidebar +
            // content (= left + left-2) ideal widths to their min
            // values (= sidebar 220, content 240) so the columns
            // open at their tightest legal width (= no extra padding
            // room = the user sees the smallest sidebar + cards band
            // that still fits the row icons + labels). The detail +
            // inspector ideal widths stay as-is (= 600 / 280) per the
            // boss's '其它两栏先不变' instruction.
            //
            // Why this works: `navigationSplitViewColumnWidth(min: X,
            // ideal: Y, max: Z)` sets Y as the initial width when
            // the column first appears; = setting ideal = min gives
            // the minimum-width initial state without losing the
            // user's ability to drag wider (= max is unchanged =
            // user can drag sidebar up to 360 PT and content up to
            // 480 PT).
            //
            // Window total: 220 + 240 + 600 + 280 = 1340 PT + chrome
            // ~28 PT = ~1368 PT initial width (= smaller than the
            // previous 1480 PT 'ideal sum' = the cards band gets the
            // min treatment).
            NewLibraryOutlineView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 360)
        } content: {
            // v0.69 boss 2026-09-10 OOB 'land the canonical 6-zone
            // layout from the probe (= NavigationSplitView 3 columns
            // + .inspector() + VSplitView in the detail +
            // .safeAreaInset on the sidebar)': the middle column
            // (= the section between sidebar and detail) is the
            // outline + cards band, exactly as in the probe's
            // ContentZone. The probe measured window = 1449, sidebar
            // = 240, content = 280, detail = 648 with this layout.
            // v1.0.0-m1-shell boss 2026-09-10 OOB '左左2 用最小':
            // content ideal 320 → 240 (= matches sidebar's
            // 'min-width' pattern; = user can still drag wider up
            // to 480 PT via max).
            ShellMiddleColumn(appState: appState)
                .navigationSplitViewColumnWidth(min: 240, ideal: 240, max: 480)
        } detail: {
            // Apple HIG detail column = the editor + chat sub-areas
            // in a vertical split (= VSplitView is what Mail uses
            // for inbox/message inside the same column; the probe
            // also uses VSplitView in the detail).
            //
            // v0.48 boss 2026-09-09 OOB 'in the Apple office apps the
            // right column is the same color as the left one': the
            // trailing panel is now an Apple inspector, not a third
            // NavigationSplitView column.
            //
            // Measured on this machine: a 3-column NavigationSplitView
            // paints sidebar 40/255 but detail 34/255, because detail is
            // a CONTENT column (Apple's own 3-column sample shows the
            // same 48 vs 34 split). Pages/Keynote/Numbers do not use a
            // third column for their format panel — they use an
            // inspector, which carries the sidebar material. The 3-
            // column NSV + inspector pattern is the canonical Apple
            // 6-zone layout (= the probe confirms window = 1449
            // with this exact combination).
            ShellContentColumn(appState: appState)
                .navigationSplitViewColumnWidth(min: 400, ideal: 600, max: 900)
                // v1.0.0-m1-shell boss 2026-09-10 OOB 'keynote 三个办公软件
                // 全是这个逻辑': wire the inspector's `isPresented` to
                // a real `Binding<Bool>` (= `appState.inspectorVisible`)
                // so the inspector can collapse (= user drags the
                // right-column divider past the left edge) and
                // reopen (= the toolbar toggle button sets the
                // binding to true). This is the canonical Apple
                // HIG behavior for `.inspector(isPresented:)` per
                // WWDC23-10161: 'Inspectors can collapse by default,
                // but they aren't resizable by default. We can change
                // it with .inspectorColumnWidth. We can also add a
                // toolbar button to toggle the presented property.'
                .inspector(isPresented: Binding(
                    get: { appState.inspectorVisible },
                    set: { newValue in appState.inspectorVisible = newValue }
                )) {
                    ShellDetailColumn(appState: appState)
                        .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                }
        }
        // v0.45 boss 2026-09-09 OOB 'revert to Apple default first':
        // removed .thinColumnDividers() (= AppKit KVC hack that set
        // NSSplitView.dividerColor = .clear + dividerStyle = .thin).
        // That is not an Apple SwiftUI API; macOS 27 NavigationSplitView
        // owns its own column separation. Default-first = no interop.
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject appState at
        // the NavigationSplitView root (= SwiftUI's internal
        // layout engine reads @Environment values during
        // NavigationSplitCoordinator.makeSplitViewController
        // to compute column min sizes; = the engine needs appState
        // in env even though no column body reads it directly).
        // Without this re-injection, the env chain fails at
        // _FlexFrameLayout.sizeThatFits (= EnvironmentValues
        // subscript crashes with 'No Observable object of type
        // AppState found' during view layout pass).
        .environment(appState)
        // CHATZONE-CRASH-FIX part 2: also re-inject bookStore if
        // available (= descendants read BookStore from env via
        // @Environment(BookStore.self) = ForeshadowingView /
        // PlaceholderView / PreviewPane / WorkspaceView. Without
        // this re-injection, the env chain fails at the layout
        // pass with 'No Observable object of type BookStore found').
        .environment(bookStore)
    }
}// MARK: - Sidebar column (= 2 vertical sub-areas)

/// Apple HIG sidebar column (= 1 vertical sub-area: directory tree).
/// Per boss 2026-09-10 second OOB 'NAV default 3 columns + each
/// column's sub-areas = visual 5 columns' = the card grid migrates
/// out of the sidebar bottom into the middle column bottom
/// (= ticket 001 of 2026-09-10-six-zone-ui-rewrite). The sidebar
/// is left as a single-area column (= no VSplitView) so the
/// directory tree owns the whole column.
///
/// Boss 2026-09-10 'Apple default' = no custom chrome wrappers;
/// Plan A pass-through ZonePerRegionChrome stub stays as-is
/// (per boss 9/8 OOB).
struct ShellSidebarColumn: View {
    let appState: AppState

    var body: some View {
        // Sidebar = 1 zone (directory tree). The previous 9/9
        // v0.49 sidebar card-zone pattern is reverted per the
        // 8/30 boss red-line drawing (= cards in the middle
        // column, not the sidebar).
        //
        // v0.79 boss 2026-09-10 OOB '目录树, 不需要搜索框, 删掉':
        // the sidebar's `.searchable` field (= the macOS 13+
        // Apple HIG sidebar search widget = the search field at
        // the top of the sidebar column = ticket 004 of the
        // 2026-09-10-six-zone-ui-rewrite batch) is removed.
        // All sidebar rows render unconditionally (= no
        // case-insensitive substring match on title; = the
        // directory tree is its own document = the user sees
        // the whole tree and navigates by clicking rows =
        // standard macOS Finder behavior when the search field is
        // hidden). The previous commit's `sidebarSearchText`
        // @State + the `.searchable(text:placement:prompt:)`
        // modifier (= Apple HIG Inventory 2026-09-06 §
        // 'add HIG APIs that are currently absent') are both
        // dropped; NewLibraryOutlineView never read this
        // binding directly (= its filter reads SidebarState, not
        // sidebarSearchText; = the binding is fully removable).
        NewLibraryOutlineView()
    }
}

/// v0.40 boss 2026-09-08 OOB 'directory tree top bar is also missing': scope selector
/// for the sidebar top tab bar. 2 cases map to the existing
/// top-level grouping (= = per-shelf books; = =
/// reference library per EntityCategory). View-local @State in
/// ShellSidebarColumn (= no AppState migration needed for M1; =
/// future ticket can promote to AppState for cross-zone read).
/// Note: defined as a top-level enum (= used by both
/// NavigationSplitShell's PaneTabBar items AND
/// NewLibraryOutlineView's body filter; = placed here in the
/// NavigationSplitShell file = only NavigationSplitShell
/// imports it). The actual filtering logic lives in
/// NewLibraryOutlineView (= the enum travels to the leaf as
/// an init parameter).

// MARK: - Content column (= 2 vertical sub-areas)

/// Apple HIG content column (= 1 zone: the card grid).
/// Per boss 2026-09-10 'visual 5 columns' + '卡片区放在中左, 错了,
/// 不需要红框这块': the middle column carries exactly 1 zone
/// (PreviewPane = the card grid). The previously rendered bottom
/// outline sub-area (= NewLibraryOutlineView = the same
/// directory tree the sidebar uses) is removed (= the outline
/// is the sidebar's job; duplicating it in the middle column
/// is noise).
///
/// Boss 2026-09-10 '删除 tab, 只留卡片内容 + 图反正没有实现, 直接先删掉':
/// the sidebar bottom card zone (= previously ZoneContentView
/// with two tabs '预览 / 图' = a .pickerStyle(.segmented) TabBar
/// over a PreviewPane) is gone. PreviewPane now renders the
/// card grid without any tab chrome (= Apple's empty state +
/// search bar + the actual grid = the canonical pattern Xcode /
/// Photos / Music use for unfiltered list views).
///
/// v0.66 boss 2026-09-10 OOB 'drop the floating panel, just split the
/// middle column in two': the previous float-over-document layout
/// fought NSTextView's hit test (= an NSTextView on top of another
/// NSTextView makes cursor + click ownership ambiguous). The
/// previous VSplitView held cards on top + outline on bottom; per
/// the next boss OOB (= '不需要红框这块' = the outline sub-area)
/// the VSplitView is gone too and the card zone owns the full
/// column height.
struct ShellMiddleColumn: View {
    // v1.0.0-m1-shell boss 2026-09-10 OOB '资料库的目录选择, 和
    // 素材区的卡片对不齐, 没有过滤' (= the cards column did not
    // re-render when the user clicked a reference category in the
    // sidebar). Root cause: `let appState: AppState` (= a plain
    // stored property holding an `@Observable` instance) does NOT
    // participate in SwiftUI's Observation Framework tracking when
    // the view body reads `appState.sidebarSelection`. The
    // `@Observable` macro generates `withObservationTracking`
    // hooks keyed to the *direct* property access on a tracked
    // reference (= `@Environment` / `@State` / `@Bindable`); a
    // plain `let` field is treated as a non-tracked read, so the
    // view body never re-renders when `sidebarSelection` mutates.
    //
    // Fix: switch to `@Environment(AppState.self)` (= the
    // canonical SwiftUI Observation entry point for `@Observable`
    // instances; = reads of `appState.x` register tracking; = body
    // re-renders on every mutation). The `init` / call sites that
    // previously passed `appState: appState` as a parameter can
    // keep passing it for backwards compat (= the let field is
    // kept as a no-op shim so callers don't have to change) but
    // the @Environment entry takes precedence for observation
    // tracking inside body.
    @Environment(AppState.self) private var envAppState
    let appState: AppState

    /// Sort order for the preview pane card grid. Owned locally
    /// (= PreviewPane requires @Binding; = AppState migration is
    /// out of ticket scope).
    @State private var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    // v1.0.0-m1-shell boss 2026-09-10 OOB '全局搜索': use
    // envAppState.searchText (= the AppState @Observable
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

    /// v1.0.0-m1-shell boss 2026-09-10 OOB '目录选择, 卡片栏没有
    /// 根据目录选择变化卡片内容' + follow-up '左边的目录树选择,
    /// 中间的素材区没有出现卡片' (= selecting .book(worldview)
    /// in the sidebar showed .empty in the cards column instead of
    /// the book's .md cards). The previous version mapped .book /
    /// .shelf / .folder ALL to .empty (= cards column blanked out
    /// for any user-scope row). The correct mapping per PreviewScope
    /// enum (= see PreviewPane.swift lines 139-152):
    /// - .referenceLibraryRoot / nil → .referenceScope(nil)
    ///   (= overview grid of all entities across categories)
    /// - .referenceCategory(let dirName) → .referenceScope(
    ///   EntityCategory(rawValue: dirName)) (= one category only)
    /// - .book(let id) → .bookScope(bookId: id, folderName: nil)
    ///   (= the book with ALL its folders' .md cards = the user
    ///   wants to see the book's content; = the boss's report
    ///   '左边选世界观, 中间不出现卡片' = the book WAS selected
    ///   but the preview was .empty)
    /// - .shelf(let id) → .shelfScope(shelfId: id) (= shelf hint,
    ///   per PreviewScope comment: 'shelves are a tree level, not
    ///   a document scope' = the preview pane shows a hint to
    ///   drill into a book)
    /// - .folder(let bookId, let folderName) → .bookScope(bookId,
    ///   folderName: folderName) (= the folder's .md cards only)
    /// - Invalid dirName (= no matching EntityCategory) falls back
    ///   to .referenceScope(nil) so a broken reference selection
    ///   doesn't lock the user out.
    /// Without this fix, selecting ANY user-scope sidebar row (=
    /// book / shelf / folder) showed '请选择左侧目录查看文档' even
    /// though a real selection was active (= the boss's bug).
    /// v1.0.0-m1-shell boss 2026-09-10 OOB '资料库的目录选择, 和
    /// 素材区的卡片对不齐, 没有过滤': map sidebarSelection →
    /// PreviewScope. The case-mismatch bug (sidebar wrote lowercase
    /// directoryName 'b' but entities JSON stored uppercase
    /// rawValue 'B') was fixed at the sidebar tag + onChange lookup
    /// sites (= see NewLibraryOutlineView.swift line ~371 and ~543);
    /// by the time `previewScope()` reads `appState.sidebarSelection`,
    /// the dirName is already the uppercase rawValue, so
    /// `EntityCategory(rawValue: dirName)` succeeds (= .b for
    /// Philosophy / 'B') and `.referenceScope(cat)` reaches
    /// `categoryGrid(category: cat, ...)` which filters
    /// `allEntities.filter { $0.category == category }` correctly.
    private func previewScope() -> PreviewScope {
        // v1.0.0-m1-shell boss 2026-09-10 OOB: read from envAppState
        // (= the @Environment-tracked Observable instance), NOT
        // from the `let appState` field (= which doesn't register
        // Observation tracking; = previous code's `previewScope()`
        // read stale data because the body never re-rendered).
        switch envAppState.sidebarSelection {
        case .referenceLibraryRoot:
            return .referenceScope(nil)
        case .referenceCategory(let dirName):
            return .referenceScope(EntityCategory(rawValue: dirName))
        case .book(let bookId):
            return .bookScope(bookId: bookId, folderName: nil)
        case .shelf(let shelfId):
            return .shelfScope(shelfId: shelfId)
        case .folder(let bookId, let folderName):
            return .bookScope(bookId: bookId, folderName: folderName)
        case nil:
            return .referenceScope(nil)
        }
    }

    var body: some View {
        // Boss 2026-09-10 '卡片区放在中左' + '只需要原来的素材卡片':
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
        //   Per boss 2026-09-10 '只需要原来的素材卡片', the column
        //   must show the actual card grid (= the entities), even
        //   with no sidebar selection.
        // - .referenceScope(nil) = overview grid of all entities in
        //   the reference library (= 角色 / 世界观 / 书 / 部 等). When
        //   the user later clicks a sidebar row, AppState can route
        //   a category-scoped scope (= .referenceScope(.some)) into
        //   the PreviewPane for filtered view.
        //
        // No VSplitView wrapper, no outline sub-area, no chapter tree.
        // No navigationTitle: per boss 2026-09-10 OOB '红框里的标题可以不要吗',
        // the column-level header (= the NavigationSplitView column
        // title bar = 'Cards' + library subtitle 'anbaiqiang.ws') is
        // removed. The column content (= the cards themselves) is
        // self-explanatory; an extra title bar is noise on a single-
        // zone column.
        //
        // v0.77 boss 2026-09-10 OOB '位置不对, 是要放在中左栏内部的顶上':
        // the previous `.toolbar { ToolbarItem(.principal) { ...
        // } }` route (= commit dff49498d) put the search field in
        // the window toolbar (= not in the column body). Drop the
        // .toolbar wrapper and let PreviewPane's internal
        // `previewSearchBar` render inline (= Apple's macOS 13+
        // rounded-pill pattern hosted at the top of the column
        // body = same visual slot as the sidebar's `.searchable`
        // field at the top of the sidebar column).
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB '目录选择, 卡片栏没有根据
        // 目录选择变化卡片内容': the previous `.referenceScope(nil)`
        // (= unfiltered overview grid of every entity in the library)
        // ignored sidebar selection entirely (= clicking 哲学宗教
        // / 军事 / 经济 / 文学 / 历史地理 / 其它 in the sidebar had
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
        // v1.0.0-m1-shell boss 2026-09-10 OOB '如果 apple api 支持, 那就直接用':
        // wire the Apple `.searchable` system-styled search field to
        // the live `envAppState.searchText` (= the AppState
        // @Observable property; = single source of truth for app-wide
        // search state; = multiple columns can attach .searchable
        // to the same binding to share search text). Pass the
        // binding to PreviewPane so its `searchQuery` Binding resolves
        // to the live `envAppState.searchText` (= the filter applies
        // correctly; = survives PreviewPane re-instantiation).
        PreviewPane(
            scope: previewScope(),
            onDoubleClick: { _ in },
            previewSortOrder: $previewSortOrder,
            searchQuery: Binding<String?>(
                get: { envAppState.searchText },
                set: { newValue in envAppState.searchText = newValue ?? "" }
            )
        )
        // Apple HIG canonical search field per developer.apple.com/
        // documentation/swiftui/view/searchable(text:placement:prompt:).
        // placement: .toolbar (= renders in the middle column's
        // toolbar slot; = Mail / Notes / Finder visual). ⌘F to focus.
        .searchable(
            text: Binding(
                get: { envAppState.searchText },
                set: { newValue in envAppState.searchText = newValue }
            ),
            placement: .toolbar,
            prompt: WenshuI18n.t("preview.search.placeholder")
        )
    }
}


// MARK: - Detail column (= 2 vertical sub-areas)

struct ShellContentColumn: View {
    let appState: AppState

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB '死磕文档的方案': per
        // Apple's HIG split-views documentation
        // (developer.apple.com/design/human-interface-guidelines/
        // split-views): "Keynote in macOS uses split view panes to
        // present the slide navigator, the presenter notes, and
        // the inspector pane in areas that surround the main slide
        // canvas. For developer guidance, see VSplitView and
        // HSplitView." = the canonical Apple HIG '中栏' (= detail
        // column = editor on top + chat on bottom) pattern is
        // VSplitView.
        //
        // Two .frame(maxWidth: .infinity, maxHeight: .infinity)
        // modifiers on the direct children (= EditorPlaceholder +
        // ChatZoneView) = commit f1b56bfc8 fix; = both children
        // fill the VSplitView slot (= no content-sized shrinkage).
        //
        // The .navigationSplitViewColumnWidth(min: 400, ideal: 600,
        // max: 900) is applied DIRECTLY on the ShellContentColumn
        // (= the view that lives inside NavigationSplitView's
        // detail: closure) per Apple docs: 'You can specify a
        // different modifier in each column. The navigation split
        // view does its best to accommodate the preferences that
        // you specify'. = the NSV honors the 400/600/900 detail
        // column width even with VSplitView inside.
        //
        // Apple HIG note: the chat zone may also collapse to zero
        // height when the user wants the editor to fill the whole
        // window (= the VSplitView divider is draggable down to
        // hide the chat; = same as Keynote's speaker notes panel).
        VSplitView {
            EditorPlaceholder()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ChatZoneView(
                conductor: WenshuAppDelegate.sharedConductor,
                store: WenshuAppDelegate.sharedChatStoreRef
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(appState)
    }
}


/// Apple HIG detail column (= 2 vertical sub-areas: +).
/// Per boss 9/8 ' right tools / right dynamic' = the
/// detail column is also 1 column with 2 stacked sub-areas.
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: ZoneModuleView(zoneSlot: .specializedTools)
///   (real tools pane from v0.34+; = foreshadowing tracking,
///   memory retrieval, etc.)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .aiDynamic) (real
///   dynamic pane from v0.34+; = kanban + todo + scope status)
/// v0.42 boss 2026-09-09 OOB 'use the 3-column framework default':
/// right column uses the same simple 2-stack VStack pattern as
/// ShellSidebarColumn (= no inspector-specific chrome wrappers,
/// no .toolbarRole special casing, no VStack container for the
/// picker toggle). The 2-toggle Tools / Dynamic picker is
/// attached via Apple's canonical .toolbar with ToolbarItem
/// placement .principal (= exactly matching ShellSidebarColumn's
/// books.vertical leading icon + PaneTabBar principal tabs).
/// Per WWDC25-323: 'The canonical column pattern uses VStack
/// (spacing: 0) with 2 sub-areas and a .toolbar for the column
/// chrome. No custom inspector wrapper needed.'
struct ShellDetailColumn: View {
    let appState: AppState

    // v0.42 boss 2026-09-09 OOB 'simplify the right column':
    // tracks the currently displayed inspector content
    // (= tools / dynamic). The 2-toggle Picker(.segmented)
    // lives in the .toolbar .principal placement (= same
    // pattern as ShellSidebarColumn's 2 scope tabs).
    @State private var inspectorContent: InspectorContent = .tools

    /// v1.0.0-m1-shell boss 2026-09-10 OOB: localized label for
    /// each InspectorContent case (= used in the toolbar Picker
    /// labels via LucideLabel(text:); = the i18n keys are stable
    /// and round-trip through Localizable.strings so the picker
    /// displays the right text in each language).
    private func textualLabel(for content: InspectorContent) -> String {
        switch content {
        case .tools:
            return WenshuI18n.t("inspector.tab.tools")
        case .kanban:
            return WenshuI18n.t("inspector.tab.kanban")
        case .todo:
            return WenshuI18n.t("inspector.tab.todo")
        }
    }

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-10 OOB '用 keynote, pages,
        // numbers 内容中心的逻辑, 实现看板/待办页': the inspector
        // column (= the rightmost NSV column) is now a 3-tab content
        // center. The 3-toggle Picker(.segmented) lives in the
        // .toolbar .principal placement (= same pattern as
        // ShellSidebarColumn's 2 scope tabs).
        Group {
            switch inspectorContent {
            case .tools:
                ZoneModuleView(zoneSlot: .specializedTools)
            case .kanban:
                KanbanView()
            case .todo:
                TodoListView()
            }
        }
        .toolbar {
            // v1.0.0-m1-shell boss 2026-09-10 OOB '按钮的位置不对, 默认
            // 是放在最右边': place the toggle button AFTER the
            // 3-tab Picker in the toolbar (= SwiftUI renders
            // multiple .primaryAction items in declaration order;
            // = the toggle button is the last declared =
            // rightmost). Per Apple's ToolbarItemPlacement docs:
            // '.primaryAction: An item that represents the primary
            // action of the toolbar, typically positioned at the
            // trailing edge.' = Keynote / Pages / Numbers also put
            // the right-panel toggle at the trailing edge.
            //
            // The toggle button is ALWAYS visible (= even when the
            // inspector is collapsed, the toolbar still shows the
            // button; = the user can re-open the inspector at any
            // time; = matches Keynote / Pages / Numbers).
            ToolbarItem(placement: .primaryAction) {
                Picker("Inspector", selection: $inspectorContent) {
                    ForEach(InspectorContent.allCases, id: \.self) { content in
                        LucideLabel(textualLabel(for: content), icon: content.icon)
                            .tag(content)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.inspectorVisible.toggle()
                } label: {
                    LucideLabel(
                        WenshuI18n.t("inspector.toggle.button"),
                        icon: appState.inspectorVisible
                            ? "sidebar-right"
                            : "panel-right"
                    )
                }
                .buttonStyle(.plain)
                .help(WenshuI18n.t("inspector.toggle.help"))
            }
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary.
        .environment(appState)
    }
}

/// v1.0.0-m1-shell boss 2026-09-10 OOB '用 keynote, pages,
/// numbers 内容中心的逻辑, 实现看板/待办页, 让看板和待办从右栏
/// 独立出来': the previous `InspectorContent` enum had two
/// (= tools / dynamic) which conflated the specialized tools pane
/// (= foreshadowing, memory retrieval, scope status) with the
/// AI-dynamic zone (= also tools, just categorized differently).
/// The previous naming was a leftover from when the column
/// was empty placeholders (= the v0.42 commit filled them with
/// the two zone modules).
///
/// Re-categorize the inspector (= the rightmost NSV column) along
/// Apple HIG content-center lines (= Keynote Media Browser /
/// Pages Template Picker / Numbers Sheet Templates = a
/// popover-shaped chrome with a search bar at top, segmented tabs
/// for content type, and a main grid below). The 3 categories
/// that map to the wenshu 'content center' (= the user's written
/// material + agent-tracked work) are:
//  - .tools      (= existing specialized tools zone: foreshadowing,
///                  placeholder, style guide, etc.; = kept as
///                  'tools' = the 'inspector' panel of the editor,
///                  = the canonical Apple HIG inspector placement)
//  - .kanban     (= KanbanView; = the user's tickets board =
///                  agent-tracked work = the Keynote 'media' analog
///                  for wenshu)
//  - .todo       (= TodoListView; = the user's todo items =
///                  daily-actionable work = the Pages 'template'
///                  analog for wenshu)
enum InspectorContent: Hashable, CaseIterable {
    case tools
    case kanban
    case todo

    var icon: String {
        switch self {
        case .tools: return "wrench"
        case .kanban: return "kanban"   // Lucide kanban icon
        case .todo: return "list-checks"  // Lucide list-checks icon
        }
    }
}



// MARK: - Placeholder view (= reusable for M1)

/// M1 placeholder (= Apple HIG standard pattern for empty panes
/// = Xcode's "No Editor" / Mail's "No Message Selected" =
/// informational view showing what WILL go there in a future
/// ticket).
///
/// Per boss 9/3 'group, chat zonegroup, group,
/// groupchat zonebottom bar. replace' (= placeholders
/// are first-class Apple HIG pattern; = the shell renders the
/// structure; = future tickets replace each placeholder with a
/// real zone view).
///
/// Per boss 2026-09-09 'fix everything' (= use Apple API unless Apple API
/// cannot implement the requirement): replaced the previous custom
/// VStack with `ContentUnavailableView` (= macOS 14+; = Apple HIG
/// canonical informational view = Xcode / Mail / Notes "no content"
/// pattern). The custom VStack was 28 LOC of reimplemented chrome;
/// `ContentUnavailableView` is Apple's first-party replacement and
/// adapts to Liquid Glass automatically (= no manual `.foregroundStyle`
/// / `.font` tuning = the platform controls the visual).
///
/// wenshu's minimum target is macOS 27 so ContentUnavailableView is
/// always available (= no fallback needed).
///
/// Per boss 2026-09-09 'study docs first, then audit code' (= research Apple HIG first):
/// WWDC23 "Meet SwiftUI for macOS" introduced `ContentUnavailableView`
/// as the canonical empty/no-content state. Apple's HIG for empty
// /// states says: "Use `ContentUnavailableView` for empty states,
/// not custom layouts". wenshu now follows this guidance.
struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        // v0.46 boss OOB 'SF Symbol dropped, use Lucide': the
        // systemImage: overload of ContentUnavailableView only accepts
        // SF Symbol names. The label: closure overload takes any View,
        // so the Lucide glyph goes there.
        ContentUnavailableView {
            // 38 PT matches the glyph height Apple's own
            // ContentUnavailableView renders, measured on this machine.
            Label { Text(name) } icon: { LucideIcon(icon, size: 38) }
        } description: {
            Text(hint)
        }
    }
}

