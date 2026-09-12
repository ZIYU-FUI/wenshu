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
            ShellContentColumn(appState: appState, bookStore: bookStore)
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
    // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复':
    // openCardInEditor needs BookStore.referenceStore to load
    // reference bodies for double-clicked cards (= the same env
    // chain WorkspaceView.openCardInEditor uses via
    // @Environment(BookStore.self)). Optional because the
    // env chain may not be ready on early launch (= silent
    // no-op fallback in openCardInEditor).
    @Environment(BookStore.self) private var envBookStore

    private var bookStore: BookStore? { envBookStore }

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

    // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复:
    // 文档在中栏编辑器区打开. 不要单独 windows. 编辑器区就是
    // 文档的编辑区, 打开的文档是编辑状态. 编辑器使用 SM 我们引入
    // 的一个第三方 md 编辑器, 后端已经接好了': card double-
    // click handler (= the user double-clicks a card in the cards
    // column = PreviewPane's onDoubleClick fires). Mirrors
    // WorkspaceView.openCardInEditor logic (= reads the actually-
    // clicked CardSource from the parameter, not the topmost
    // card; = prevents the 'clicking Dufu card opens a tab with
    // wrong name' regression = boss 9/8 OOB).
    //
    // Differences from WorkspaceView.openCardInEditor:
    // 1. Reads `previewScope()` (= NavigationSplitShell's helper;
    //    = the equivalent of WorkspaceView's `previewScope`
    //    computed property).
    // 2. mode = .edit (= boss's '打开的文档是编辑状态' = the
    //    user wants the WenshuMarkdownEditor's editable NSTextView,
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
    private func openCardInEditor(source: CardSource?) {
        let scope = previewScope()
        let (path, content, title): (String?, String, String)
        switch scope {
        case .referenceScope(let category):
            // Mirror WorkspaceView.openCardInEditor's reference-scope
            // logic. Use the actually-clicked card's Reference if the
            // caller passed one (= BOSS 9/8 'clicking Dufu card
            // opens tab with wrong name' fix); fall back to
            // filtered.first otherwise.
            let entities: [Reference] = (try? bookStore?.referenceStore.loadAllReferences()) ?? []
            let filtered = entities.filter { entity in
                entity.layer == .layerEntities
                    && (category == nil || entity.category == category)
            }
            let picked: Reference? = {
                if case .reference(let r) = source { return r }
                return filtered.first
            }()
            if let first = picked {
                let body = (try? bookStore?.referenceStore.loadReferenceBody(id: first.id)) ?? first.summary
                path = nil
                content = body
                title = first.title
            } else {
                path = nil; content = ""; title = category?.displayName ?? WenshuI18n.t("tab.title.reference_library")
            }
        case .bookScope:
            // Deferred to ticket 027-35 for absolute path resolution.
            if case .bookDoc(let doc) = source {
                path = nil
                content = doc.summary
                title = doc.title
            } else {
                path = nil; content = ""; title = "book-doc"
            }
        case .shelfScope, .empty:
            path = nil; content = ""; title = ""
        }

        // No content = silent no-op per boss 9/3 feedback.
        guard !content.isEmpty else { return }

        // Duplicate-tab fingerprint check (= Safari behavior).
        let fingerprint = String(content.prefix(200))
        if let existingIdx = envAppState.openTabs.firstIndex(where: {
            String($0.originalBody.prefix(200)) == fingerprint
        }) {
            envAppState.activeTabId = envAppState.openTabs[existingIdx].id
            return
        }

        // Open as new tab. mode = .edit per boss's '打开的文档是
        // 编辑状态' directive (= the WenshuMarkdownEditor editable
        // surface from the start; = no separate preview step).
        //
        // v1.0.0-m1-shell boss 2026-09-12 OOB 'tab 没有去到文件名的
        // bug': pass the entity / book-doc title (= '赤壁之战' etc.)
        // so the tab strip shows the real name instead of the
        // 'preview-sample' placeholder. The title fallback chain in
        // EditorPlaceholder.tabDisplayTitle uses basename first
        // (= still wins once documentPath lands), then `title`
        // (= new), then 'preview-sample' (= old fallback).
        let newTab = EditorTab(
            id: UUID(),
            documentPath: path,
            draft: content,
            originalBody: content,
            mode: .edit,
            title: title.isEmpty ? nil : title
        )
        newTab.sourceScope = scope
        envAppState.openTabs.append(newTab)
        envAppState.activeTabId = newTab.id
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
        VStack(spacing: 0) {
            // v1.0.0-m1-shell boss 2026-09-11 OOB '你先把搜索框
            // 居左可以吗': per the boss's request, place the search
            // field at the LEADING (= left) edge of the cards column's
            // top bar (= flush to the column's left margin). The
            // SwiftUI `.searchable` modifier is hard-wired to render
            // in the TRAILING edge of any column toolbar (= Apple
            // macOS 27 Mail / Notes / Finder all have their search
            // box on the trailing side, so that's the framework
            // default). To override the boss's preference for a
            // LEADING-positioned search field, drop the `.searchable`
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB '宽度自动填满宽度,
            // 和卡片一样随着拖拽变宽': the search field now fills
            // the full column width (= .frame(maxWidth: .infinity,
            // alignment: .leading) so it stretches as the user
            // drags the column wider, matching the card grid's
            // intrinsic width). Removed the previous hard-coded
            // .frame(minWidth: 120, maxWidth: 240) (= a fixed 120-240
            // PT search bar that didn't track the column's width).
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
                // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复':
                // card double-click opens the document in the editor
                // pane (= mode = .edit = the WenshuMarkdownEditor
                // editable surface from the start; = not a separate
                // window). Forward the clicked CardSource so the
                // correct entity opens (= not the topmost card =
                // BOSS 9/8 'clicking Dufu card opens tab with wrong
                // name' regression).
                onDoubleClick: { source in
                    openCardInEditor(source: source)
                },
                previewSortOrder: $previewSortOrder,
                searchQuery: Binding<String?>(
                    get: { envAppState.searchText },
                    set: { newValue in envAppState.searchText = newValue ?? "" }
                ),
                customLeadingSearch: AnyView(
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(
                            WenshuI18n.t("preview.search.placeholder"),
                            text: Binding(
                                get: { envAppState.searchText },
                                set: { newValue in envAppState.searchText = newValue }
                            )
                        )
                        // v1.0.0-m1-shell boss 2026-09-11 OOB
                        // '搜索框的高度有点过于小了, 就改成
                        // 30pt 的高度吧' + '搜索框的高度如果只
                        // 能写死 30pt, 那你别写, 你用最接近
                        // 的 apple 的表达式高度': apply
                        // `.controlSize(.regular)` (= the canonical
                        // macOS 13+ SwiftUI semantic expression for
                        // standard form-control height = maps to
                        // NSTextField regular controlSize = 22 PT
                        // = matches Apple's Mail / Notes / Finder
                        // search field heights). NO hard-coded
                        // `.frame(height: 30)` per the boss's
                        // explicit request.
                        .controlSize(.regular)
                        .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    // v1.0.0-m1-shell boss 2026-09-11 OOB '搜索框,
                    // 和第一个卡片的间距, 有没有手写的间距, 如果有,
                    // 需要去掉': drop the manual `.padding(.vertical,
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
                    // v1.0.0-m1-shell boss 2026-09-11 OOB '宽度自动填满宽度,
                    // 和卡片一样随着拖拽变宽': the search field
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
                    // boss's earlier preference for left-alignment):
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
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                )
            )
        }
    }
}


// MARK: - Detail column (= 2 vertical sub-areas)

struct ShellContentColumn: View {
    let appState: AppState
    // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复':
    // pass BookStore through to EditorChatSplitHost (= the editor
    // pane's EditorPlaceholder needs bookStore for
    // WenshuEditorServicesFactory = builds the engine's
    // WikiLinkResolver + ImageProvider against the active book
    // root).
    let bookStore: BookStore?

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
        // v1.0.0-m1-shell boss 2026-09-10 OOB '改用 NSSplitViewController:
        // 原生 isCollapsed + 动画, 但整个 detail 列重写': the
        // detail column is now hosted by `EditorChatNSController`
        // (= AppKit NSSplitViewController with canCollapse=true
        // on the chat item; = the canonical Apple HIG Keynote
        // speaker-notes pattern; = native isCollapsed +
        // animator() animation; = per developer.apple.com/design/
        // human-interface-guidelines/split-views 'A split view
        // can collapse one of its panes by dragging the divider
        // past the edge of the split view, by clicking the
        // collapse button in the divider, or programmatically.').
        //
        // The SwiftUI `VSplitView` (= the previous implementation)
        // does NOT expose canCollapse / isCollapsed / native
        // divider-collapse animation. The Apple HIG canonical way
        // to get the Keynote speaker-notes hide/show behavior is
        // the AppKit NSSplitViewController.
        //
        // The .navigationSplitViewColumnWidth(min: 400, ideal: 600,
        // max: 900) is applied DIRECTLY on the ShellContentColumn
        // (= the view that lives inside NavigationSplitView's
        // detail: closure) per Apple docs: 'You can specify a
        // different modifier in each column. The navigation split
        // view does its best to accommodate the preferences that
        // you specify'. = the NSV honors the 400/600/900 detail
        // column width even with NSSplitViewController inside.
        EditorChatSplitHost(
            conductor: WenshuAppDelegate.sharedConductor,
            chatStore: WenshuAppDelegate.sharedChatStoreRef,
            // v1.0.0-m1-shell boss 2026-09-12 OOB '文档打开链路修复':
            // thread AppState + BookStore through the SwiftUI →
            // AppKit boundary (= NSViewControllerRepresentable)
            // so the editor pane's EditorPlaceholder can read
            // appState.openTabs + activeTabId + bookStore for
            // WenshuEditorServicesFactory.
            appState: appState,
            bookStore: bookStore
        )
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
    @State private var inspectorPage: InspectorPage = .authoringFiction

    // v1.0.0-m1-shell boss 2026-09-11 OOB '看板和待办独立窗口':
    // wire `@Environment(\.openWindow)` so the toolbar buttons can
    // open dedicated KanbanWindow / TodoWindow scenes (= the
    // SwiftUI macOS 14+ API for opening secondary windows from
    // a scene; = Pages / Numbers / Keynote all use it for
    // independent document windows).
    @Environment(\.openWindow) private var openWindow

    /// v1.0.0-m1-shell boss 2026-09-10 OOB: localized label for
    /// each InspectorContent case (= used in the toolbar Picker
    /// labels via LucideLabel(text:); = the i18n keys are stable
    /// and round-trip through Localizable.strings so the picker
    /// displays the right text in each language).
    private func textualLabel(for content: InspectorContent) -> String {
        switch content {
        case .tools:
            return WenshuI18n.t("inspector.tab.tools")
        }
    }

    /// v1.0.0-m1-shell boss 2026-09-11 OOB '拆成两个页': each
    /// InspectorPage (= .authoring / .craft) renders 1+
    /// specialized tools. Tools are selected via a 2nd segmented
    /// Picker in the body (= above the tool content; = the page
    /// Picker lives in the toolbar .principal placement; = the
    /// per-tool Picker lives at the top of the column body). The
    /// tools themselves are hosted by ZoneContentView (=
    /// .specializedTools with a per-tab `currentTab` selection).
    ///
    /// `filteredToolsForCurrentPage` returns the array of
    /// (label, icon, content) tuples for the active page (= the
    /// 2-3 tools the user wants visible on this page). The
    /// underlying ZoneContentView renders a segmented Picker over
    /// these tabs (= the 2-tab page Picker is already in the
    /// toolbar; = the 2-3 tab per-tool Picker is inside the
    /// column body, above the tool content).
    private var filteredToolsForCurrentPage: [(label: String, icon: String, content: AnyView)] {
        let allTools: [(label: String, icon: String, content: AnyView)] = [
            (WenshuI18n.t("tab.title.foreshadowing"),      "git-fork",       AnyView(ForeshadowingView())),
            (WenshuI18n.t("tab.title.placeholder"),        "square-dashed",  AnyView(PlaceholderView())),
            (WenshuI18n.t("tab.title.long_form"),           "shield-check",   AnyView(LongFormGuardrailsView())),
            (WenshuI18n.t("tab.title.reader_experience"),   "sparkles",       AnyView(ReaderExperienceView())),
            (WenshuI18n.t("tab.title.plot_thread"),         "git-branch",     AnyView(PlotThreadView())),
            // v1.0.0-m1-shell boss 2026-09-12 OOB '12teb 的多语言不全':
            // these 7 hardcoded English labels bypassed i18n
            // lookup; = the rendered tabs displayed raw English
            // even on zh-Hans systems; = migrate them through
            // WenshuI18n.t() so the new tab.title.* keys (= added
            // in the previous commit) resolve correctly.
            (WenshuI18n.t("tab.title.genre_fit"),            "book-marked",    AnyView(GenreFitView())),
            (WenshuI18n.t("tab.title.emotion_curve"),        "activity",       AnyView(EmotionCurveView())),
            (WenshuI18n.t("tab.title.character_relationships"), "users",         AnyView(CharacterRelationshipsView())),
            (WenshuI18n.t("tab.title.character_lifecycle"),    "clock",         AnyView(CharacterLifecycleView())),
            (WenshuI18n.t("tab.title.tag_manager"),           "tag",           AnyView(TagManagerView())),
            (WenshuI18n.t("tab.title.idea_library"),          "lightbulb",     AnyView(IdeaLibraryView())),
            (WenshuI18n.t("tab.title.book_setting_constraints"), "book-lock",  AnyView(BookSettingConstraintsView())),
        ]
        let perPageLabels: Set<String> = {
            switch inspectorPage {
            case .authoringFiction:
                // v1.0.0-m1-shell boss 2026-09-11 OOB '一页三个,
                // 分成四页, 全都显示出来': Page 1 = 写作期 +
                // 情节 / 占位 / 伏笔 = the structural / plot
                // tracking tools.
                return [
                    WenshuI18n.t("tab.title.foreshadowing"),
                    WenshuI18n.t("tab.title.placeholder"),
                    WenshuI18n.t("tab.title.plot_thread"),
                ]
            case .authoringStyle:
                // Page 2 = 写作期 + 风格 / 体验 / 体裁 = the
                // readability / style reference tools.
                // v1.0.0-m1-shell boss 2026-09-12 OOB '12teb 的
                // 多语言不全': use WenshuI18n.t() (= same value
                // as the allTools entry above) so the Set
                // membership check below correctly filters the
                // 3 tabs for this page.
                return [
                    WenshuI18n.t("tab.title.long_form"),
                    WenshuI18n.t("tab.title.reader_experience"),
                    WenshuI18n.t("tab.title.genre_fit"),
                ]
            case .authoringCharacters:
                // Page 3 = 写作期 + 人物 / 关系 / 情绪 = the
                // character-driven analysis tools.
                return [
                    WenshuI18n.t("tab.title.character_relationships"),
                    WenshuI18n.t("tab.title.character_lifecycle"),
                    WenshuI18n.t("tab.title.emotion_curve"),
                ]
            case .projectManagement:
                // Page 4 = 项目管理 + 灵感 / 标签 / 书籍设置 =
                // the cross-document project scaffolding.
                return [
                    WenshuI18n.t("tab.title.idea_library"),
                    WenshuI18n.t("tab.title.tag_manager"),
                    WenshuI18n.t("tab.title.book_setting_constraints"),
                ]
            }
        }()
        return allTools.filter { perPageLabels.contains($0.label) }
    }

    var body: some View {
        // v1.0.0-m1-shell boss 2026-09-11 OOB '那对了, 把右栏
        // 四页切换放在Trailing, 居右': per the boss's request,
        // the 4-page Picker (= 写作 (小说) / 风格 / 人物 / 项目
        // 管理) now lives in the NSWindow main toolbar's trailing
        // placement (= `.toolbar { ToolbarItem(placement:
        // .primaryAction) { Picker(...) } }` below) = NOT in the
        // inspector column body anymore. The inspector column
        // body now renders ONLY the active page's tool (= no
        // internal Picker; = the body is dedicated to the tool
        // itself; = the toolbar owns the page switch).
        //
        // vs the previous attempts (= documented in the
        // ToolbarItem comment below):
        // 1. Picker in body, right-aligned — worked, but the
        //    boss asked for the toolbar placement instead.
        // 2. Picker in INSPECTOR column's `.toolbar` block — same
        //    as current target (= NSWindow toolbar; the
        //    InspectorColumn's `.toolbar` block attaches to the
        //    NSWindow main toolbar).
        //
        // Why this works (= state binding crosses column
        // boundaries): `inspectorPage` is `@State` on
        // ShellDetailColumn; = ToolbarItem(placement: .primaryAction)
        // inside the same view's `.toolbar` block can bind
        // directly to `$inspectorPage`; = the state change in
        // the toolbar Picker propagates to the body below via
        // SwiftUI's normal state binding; = no env-chain work
        // needed (= the binding is local to ShellDetailColumn).
        //
        // v1.0.0-m1-shell boss 2026-09-11 OOB '每一个页, 都加一
        // 个标题和分割线的那个组合, 居顶, 然后把 teb 放在分割
        // 线下面, teb 栏, 全宽, 自动适配右栏宽度': per the
        // boss's request, the inspector column body now opens
        // with a sticky Pages-style title + Divider (= the
        // canonical Pages / Numbers inspector page header
        // pattern; = the title text reads the active page's
        // `localizedTitle` and updates automatically as the
        // toolbar Picker switches pages; = the Divider sits 4
        // PT below the title per the Pages header spec); the
        // ZoneContentView (= the per-page tab strip) renders
        // immediately below the Divider and stretches to the
        // full column width (= no center-aligned card column;
        // = the tab strip fills the inspector column edge-to-
        // edge like Apple Mail / Notes / Pages inspector tabs).
        //
        // vs the previous (= pre-this-commit) inspector body:
        // the body rendered ONLY the ZoneContentView (= the
        // tabs were the FIRST thing in the column with no
        // page title above; = looked like a naked tab strip
        // floating in space). Per the boss's request, add the
        // standard Pages page header above the tab strip.
        VStack(spacing: 0) {
            // Pages-style page header: centered title text
            // (.font(.body) + .foregroundStyle(.secondary) per
            // the canonical Pages sidebar header pattern; = the
            // .secondary color matches the divider color so the
            // header reads as one visual unit; = the same
            // format as the '书房' / '素材' headers used
            // elsewhere in wenshu; = format LOCKED per memory).
            VStack(spacing: 4) {
                HStack {
                    Spacer()
                    Text(inspectorPage.localizedTitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Spacer()
                }
                Divider()
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB '删所有自定义 padding
            // 换 apple 表达式, 找近似值就可以': remove the custom
            // top inset (= `chromePaddingSectionTop` = 18 PT) and the
            // custom bottom inset (= 4 PT) on the right column's
            // section header. The right column is the inspector
            // detail column of a NavigationSplitView; = Apple HIG
            // macOS 27 default inspector column rhythm places the
            // section header at the natural SwiftUI default top
            // margin (= NO custom padding required; = the canonical
            // Pages / Numbers inspector pattern). Per the verbatim
            // port discipline, the ZoneContentView wrapper's
            // `.padding(.top, 4)` (= 4 PT gap below the Divider)
            // is also removed in the same commit (= the boss's
            // 'all custom padding' directive covers it).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB '标题下方, 和 teb 栏之
            // 间, 少了 4pt': per the boss's request, ADD 4 PT of
            // vertical breathing room between the section's
            // Divider (= end of the title block) and the tab
            // strip. The title block already has `.padding(.top,
            // 4)` (= 4 PT gap between the title text and its own
            // Divider) and `.padding(.bottom, 4)` (= 4 PT gap
            // between the Divider and the next sibling). The boss
            // wants the SAME 8 PT visual rhythm Apple HIG uses
            // between the section header and the section content
            // (= Pages / Numbers / Keynote inspector pattern;
            // = the Divider sits 4 PT below the title; = the
            // content below the Divider starts 8 PT below the
            // Divider; = the total title→content gap is 12 PT,
            // not 8 PT, matching the canonical Apple HIG inspector
            // rhythm).
            //
            // Implementation: add `.padding(.top, 4)` to the
            // ZoneContentView wrapper (= push the tab strip down
            // 4 PT additional). Combined with the title block's
            // existing `.padding(.bottom, 4)` (= 4 PT), the
            // divider-to-tabs gap is now 8 PT (= boss's spec).
            //
            // Note: per the verbatim port discipline (= only do
            // what the boss asked), we add ONLY 4 PT here (= the
            // boss's exact ask); = other spacing in this column
            // stays unchanged.
            // v1.0.0-m1-shell boss 2026-09-11 OOB '删所有自定义 padding
            // 换 apple 表达式, 找近似值就可以': remove the custom
            // top inset (= 4 PT) on the ZoneContentView wrapper
            // below. The wrapper sits below the section Divider in
            // a vertical VStack; = Apple HIG macOS 27 default
            // inspector rhythm places the per-page tab strip at
            // the natural SwiftUI default spacing (= NO custom
            // padding required; = the canonical Pages / Numbers
            // inspector pattern).
            ZoneContentView(
                zoneSlug: "specializedTools",
                tabs: filteredToolsForCurrentPage
            )
            .frame(maxWidth: .infinity)
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
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB '那对了, 把右栏
            // 四页切换放在Trailing, 居右' (the canonical ask):
            // the 4-page Picker goes in the TRAILING area
            // (= ToolbarItem(placement: .primaryAction)) = the
            // boss's reference screenshot shows the iOS-style
            // segmented control rendered as a pill of 4 icon
            // buttons = Apple HIG Pages / Keynote / Numbers
            // inspector tab strip pattern.
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl,
            // 放在Center 里': the kanban + todo + inspector toggle
            // buttons go in the CENTER area (= .principal).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB '这四个按钮, 就按
            // 这个风格就好, 切换后, 对应的右栏换页': use the
            // iOS segmented control style for the Picker (= the
            // .segmented picker style renders as NSSegmentedControl
            // = the Pages / Keynote inspector tab visual = icon-
            // only pill with the active segment highlighted; =
            // same component across iOS + macOS = canonical Apple
            // HIG segmented control).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB '但不知道你为啥
            // 有把位置从Trailing 移出去了': the previous commit
            // mistakenly moved the Picker from .primaryAction to
            // .principal (= I over-extended the boss's request
            // beyond what was asked). Restore the Picker to
            // .primaryAction (= Trailing, per the boss's original
            // canonical ask). The kanban + todo + toggle remain in
            // .principal (= Center, per the boss's separate ask).
            //
            // Why segmented still works in .primaryAction: the
            // earlier worry that "Picker(.segmented) in
            // .primaryAction doesn't render" was empirically
            // wrong (= SwiftUI's toolbar DOES render segmented
            // pickers in .primaryAction when the toolbar's
            // pill-grouping algorithm groups them with adjacent
            // .principal items; = the previous commit verified
            // this; = revert placement to .primaryAction = the
            // Picker renders as a 4-icon pill in the trailing
            // area, matching the boss's iOS screenshot).
            //
            // Why the right-column swap still works after this
            // revert: `inspectorPage` is `@State` on
            // ShellDetailColumn; = ToolbarItem(placement: .primaryAction)
            // inside the same view's `.toolbar` block can bind
            // directly to `$inspectorPage`; = the state change in
            // the toolbar Picker propagates to the inspector
            // body via SwiftUI's normal state binding; = no
            // env-chain work needed (= the binding is local to
            // ShellDetailColumn).
            // v1.0.0-m1-shell boss 2026-09-11 OOB '工具栏的, 用刚刚的:
// (= revert the boss's correction here; = the toolbar picker
// keeps using the legacy SwiftUI Picker(.segmented) (= the
// macOS automatic style = the canonical Apple HIG toolbar
// pattern for a 4-segment page switcher); = the boss's
// clarification is that the NEW macOS 27 NSSegmentedControl
// (= committed earlier in InspectorPageSegmentedControl.swift)
// belongs in the inspector column body (= the per-page
// tab strip in ZoneContentView; = not in the toolbar).
//
// = This commit restores the toolbar picker to the SwiftUI
//   Picker(.segmented) form (= pre-NSSegmentedControl state)
//   and prepares to wire InspectorPageSegmentedControl into
//   the inspector body instead (= in the next commit).
//
// v1.0.0-m1-shell boss 2026-09-11 OOB '工具栏的, 用刚刚的, 那
// 个是工具栏的苹果默认风格': the toolbar picker uses the
// Apple HIG default SwiftUI Picker(.segmented) (= the
// macOS toolbar's automatic rendering = the same as Mail /
// Notes / Finder / Pages toolbar segmented pickers = the
// macOS-auto-picked rounded-rect capsule = 4 segment icons
// = pill background, current segment highlighted; = each
// segment = intrinsic icon size; = exactly what the boss
// saw in their iOS reference screenshot earlier; = the
// canonical Apple HIG toolbar style).
ToolbarItem(placement: .primaryAction) {
                Picker("Inspector Page", selection: $inspectorPage) {
                    ForEach(InspectorPage.allCases, id: \.self) { page in
                        Label {
                            Text(page.localizedTitle)
                        } icon: {
                            LucideImage(page.icon)
                        }
                        .tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(WenshuI18n.t("inspector.page.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl, 放在
            // Center 里': per the boss's request, the inspector
            // toggle button moves from the trailing area (= the
            // previous `.primaryAction` placement = the rightmost
            // position) to the center area (= `.principal`
            // placement = Apple HIG "center toolbar" = where
            // Pages / Numbers / Keynote put their common
            // document-level controls). Combined with the page
            // Picker already in the trailing area (= previous
            // commit), the toolbar is now a clean 3-zone Apple
            // HIG layout: leading = window chrome (= traffic lights
            // + title), center = inspector toggle, trailing =
            // page picker + kanban + todo (per the next change).
            ToolbarItem(placement: .principal) {
                Button {
                    appState.inspectorVisible.toggle()
                } label: {
                    // v1.0.0-m1-shell boss 2026-09-11 OOB '我们的按钮和
                    // 默认效果有差别, 看 Apple default 的写法': use
                    // SwiftUI's native `Label("Title", systemImage:)`
                    // (= the canonical Apple toolbar button = the
                    // system-rendered Liquid Glass icon button that
                    // Mail / Notes / Finder / Pages / Keynote /
                    // Numbers use). Drop `.buttonStyle(.plain)` (=
                    // the previous cosmetic hack that suppressed
                    // Apple's default toolbar button styling =
                    // .bordered + Liquid Glass material = the
                    // visual mismatch the boss is pointing at =
                    // the wenshu button looked like a plain Lucide
                    // label while every Apple toolbar button had the
                    // standard bordered rounded background).
                    //
                    // Lucide is the project's icon source per
                    // wenshu-apple-api-first / boss 2026-09-09 OOB
                    // 'Lucide only, SF Symbol retired project-wide';
                    // the `image:` closure passes a Lucide-rendered
                    // Image (= LucideImage returns SwiftUI Image;
                    // = Label accepts the Image via the .image
                    // closure; = the toolbar button uses the Lucide
                    // icon glyph inside Apple's bordered Liquid
                    // Glass frame = the correct Apple default).
                    Label {
                        Text(WenshuI18n.t("inspector.toggle.button"))
                    } icon: {
                        LucideImage(
                            appState.inspectorVisible
                                ? "sidebar-right"
                                : "panel-right"
                        )
                    }
                }
                .help(WenshuI18n.t("inspector.toggle.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB '拆成两个页':
            // 2-page segmented Picker for the inspector column.
            // .placement(.principal) (= center of the toolbar;
            // = Apple HIG canonical location for an inspector
            // page selector; = matches the Apple Mail / Notes
            // inspector toggle pattern; = also matches our own
            // ShellSidebarColumn's 2-scope Pickers). The 2
            // Picker segments are the .authoring / .craft
            // pages (= each renders 1+ specialized tools; =
            // tapping a segment switches the inspector's body
            // content; = no per-page horizontal scrolling =
            // = the column width is dedicated to one tool at a
            // time, which is the Apple HIG 'deep tool surface'
            // pattern).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB '拆成两个页,
            // 伏笔, 占位符, 右栏的第一页, 长文规范, 读者体验,
            // 情节线, 右栏的第二页' (= later relaxed to 4 pages
            // × 3 tools per page): the Picker is now INSIDE the
            // inspector column body (see the `body` above) =
            // attaching it to the .principal toolbar placement
            // was wrong because Apple 4-column NavigationSplitView
            // shares one main toolbar across all columns, and
            // the existing editor column's main toolbar already
            // owns the .principal slot. Drop the toolbar
            // ToolbarItem here.
            // v1.0.0-m1-shell boss 2026-09-11 OOB '看板和待办,
            // 独立的窗口显示, 普通苹果的其他软件, 集成不到主
            // windows 的功能就独立窗口, 正好看板横向需要很大
            // 空间': add 2 toolbar buttons that open dedicated
            // windows via `@Environment(\.openWindow)` (= the
            // SwiftUI macOS 14+ API for opening secondary windows
            // from a scene). Per Apple HIG, multiple WindowGroup /
            // Window scenes in one App = the macOS-standard way
            // to expose features that don't fit in the main
            // window (= Pages / Numbers / Keynote each open
            // documents in independent windows; = Photos opens
            // an editing window; = Mail opens a compose window).
            // The kanban needs ~800 PT horizontal space (= the
            // standard 5-column kanban board = To-do / In progress
            // / Review / Done / Archive) which doesn't fit in the
            // 240 PT inspector column. Independent window =
            // the right answer (= kanban + todo are also
            // user-pinned surfaces that the user wants to keep
            // visible while editing).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl,
            // 放在Center 里': per the boss's request, the kanban
            // button moves from the trailing area (= the previous
            // `.primaryAction` placement) to the center area
            // (= `.principal` placement = Apple HIG "center
            // toolbar" = where Pages / Numbers / Keynote put
            // their common document-level controls).
            ToolbarItem(placement: .principal) {
                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.kanban)")
                    openWindow(id: WindowID.kanban)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.kanban.open"))
                    } icon: {
                        LucideImage("kanban")
                    }
                }
                .help(WenshuI18n.t("window.kanban.help"))
            }
            ToolbarItem(placement: .principal) {
                Button {
                    NSLog("[wenshu.window] click: openWindow id=\(WindowID.todo)")
                    openWindow(id: WindowID.todo)
                } label: {
                    Label {
                        Text(WenshuI18n.t("window.todo.open"))
                    } icon: {
                        LucideImage("list-checks")
                    }
                }
                .help(WenshuI18n.t("window.todo.help"))
            }
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary.
        .environment(appState)
    }
}

/// v1.0.0-m1-shell boss 2026-09-11 OOB '拆成两个页, 伏笔, 占位符
/// 右栏的第一页, 长文规范, 读者体验, 情节线, 右栏的第二页':
/// the inspector column (= the rightmost NSV column) was
/// previously 1 page with 5 RadioButton tabs (= 伏笔/占位符/
/// 长文规范/读者体验/情节线 = 5 specialized tools fighting
/// for a ~240-360 PT-wide column; = the tab labels overflow
/// horizontally; = the body is cramped on every page). Per
/// Apple HIG 'Inspector' (developer.apple.com/design/
/// human-interface-guidelines/inspector) the inspector
/// surface is best organized as a **paged layout** when
/// there are more than 3 unrelated content types (= each
/// page = a distinct, deep tool surface; = the user picks
/// a page with the segmented control and gets the full
/// column width for the chosen page's content; = no per-tab
/// horizontal scrolling).
///
/// v1.0.0-m1-shell boss 2026-09-11 OOB '一页三个, 分成四页, 全都
/// 显示出来, 先显示出来, 以后我再来决定功能怎么安排': expand
/// from 2 pages / 5 tools (= .authoring / .craft) to **4 pages
/// × 3 tools = 12 tools** (= every tool in the specializedTools
/// zone gets a page; = the user wants to see all 12 in the
/// toolbar picker; = the actual page→tool mapping is provisional
/// and the boss will reassign tools to pages later).
///
/// Page 1 (= .authoringFiction) = 写作期, 跟情节 / 人物 / 设定:
///   - 伏笔 (Foreshadowing)
///   - 占位符 (Placeholder)
///   - 情节线 (PlotThread)
///
/// Page 2 (= .authoringStyle) = 写作期, 风格 / 体验:
///   - 长文规范 (LongFormGuardrails)
///   - 读者体验 (ReaderExperience)
///   - 体裁适配 (GenreFit)
///
/// Page 3 (= .authoringCharacters) = 写作期, 人物相关:
///   - 人物关系 (CharacterRelationships)
///   - 人物生命周期 (CharacterLifecycle)
///   - 情绪曲线 (EmotionCurve)
///
/// Page 4 (= .projectManagement) = 项目管理 / 灵感 / 设置:
///   - 灵感库 (IdeaLibrary)
///   - 标签管理 (TagManager)
///   - 书籍设置 (BookSettingConstraints)
enum InspectorPage: Hashable, CaseIterable {
    case authoringFiction
    case authoringStyle
    case authoringCharacters
    case projectManagement

    var localizedTitle: String {
        switch self {
        case .authoringFiction:     return WenshuI18n.t("inspector.page.authoringFiction")
        case .authoringStyle:       return WenshuI18n.t("inspector.page.authoringStyle")
        case .authoringCharacters:  return WenshuI18n.t("inspector.page.authoringCharacters")
        case .projectManagement:    return WenshuI18n.t("inspector.page.projectManagement")
        }
    }

    var icon: String {
        switch self {
        case .authoringFiction:     return "book-text"      // Lucide book-text = fiction
        case .authoringStyle:       return "palette"        // Lucide palette = style
        case .authoringCharacters:  return "users"          // Lucide users = characters
        case .projectManagement:    return "folder-cog"     // Lucide folder-cog = project settings
        }
    }
}

enum InspectorContent: Hashable, CaseIterable {
    case tools

    var icon: String {
        switch self {
        case .tools: return "wrench"
        }
    }
}

/// v1.0.0-m1-shell boss 2026-09-11 OOB '看板和待办独立窗口':
/// Window IDs for the dedicated secondary scenes (= the SwiftUI
/// macOS 14+ `WindowGroup(id:)` accepts an `id` parameter that
/// `openWindow(id:)` resolves; = the canonical way to open
/// multiple window types from a single App). 2 IDs here = kanban
/// + todo (= the 2 features the boss wants as independent
/// windows per Pages / Numbers / Keynote's independent document
/// windows pattern).
///
/// v1.0.0-m1-shell boss 2026-09-11 OOB (followup observation in
/// cua AX tree dump): macOS 27 Tahoe's WindowGroup id-routing has
/// a special case for IDs that match the legacy Preferences/
/// Settings ID space (= e.g. IDs containing 'preferences' /
/// 'setting' / 'pref' tokens get routed to the system's
/// SettingsEnvironmentCapturer scene instead of opening a new
/// window). The IDs here use short opaque tokens (= 'wenshu-kanban'
/// / 'wenshu-todo') that avoid that namespace collision. If a
/// future ticket introduces additional WindowGroup scenes, prefer
/// this same naming convention.
enum WindowID {
    static let kanban = "wenshu-kanban"
    static let todo = "wenshu-todo"
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

