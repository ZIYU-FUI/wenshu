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

    /// Inspector presentation state.
    /// Apple default for `.inspector(isPresented:)` is `false` on first launch;
    /// user reveals it via the inspector chevron rendered automatically by
    /// the modifier. The previous hardcoded `true` was a v0.48 boss OOB that
    /// pre-set the inspector visible — per boss 2026-09-10 "Apple default",
    /// SwiftUI's own default behavior takes over.
    ///
    /// Apple HIG Inventory 2026-09-06 listed `@SceneStorage` as a
    /// missing API (0 hits). Per boss 2026-09-10 'add HIG APIs that
    /// are currently absent', persist inspector visibility per
    /// scene (= each window owns its own toggle state).
    @SceneStorage("wenshu.inspectorVisible") private var inspectorVisible: Bool = false

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
            ShellSidebarColumn(appState: appState)
        } content: {
            // v0.69 boss 2026-09-10 OOB 'land the canonical 6-zone
            // layout from the probe (= NavigationSplitView 3 columns
            // + .inspector() + VSplitView in the detail +
            // .safeAreaInset on the sidebar)': the middle column
            // (= the section between sidebar and detail) is the
            // outline + cards band, exactly as in the probe's
            // ContentZone. The probe measured window = 1449, sidebar
            // = 240, content = 280, detail = 648 with this layout.
            ShellMiddleColumn(appState: appState)
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
                .inspector(isPresented: $inspectorVisible) {
                    // v0.71: inspector width follows SwiftUI's default
                    // range (= no `.inspectorColumnWidth` modifier; =
                    // Mail / Notes inspector range).
                    ShellDetailColumn(appState: appState)
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
    let appState: AppState

    /// Sort order for the preview pane card grid. Owned locally
    /// (= PreviewPane requires @Binding; = AppState migration is
    /// out of ticket scope).
    @State private var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

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
        PreviewPane(
            scope: .referenceScope(nil),
            onDoubleClick: { _ in },
            previewSortOrder: $previewSortOrder
        )
    }
}


// MARK: - Detail column (= 2 vertical sub-areas)

struct ShellContentColumn: View {
    let appState: AppState

    var body: some View {
        VSplitView {
            EditorPlaceholder()
            ChatZoneView(
                conductor: WenshuAppDelegate.sharedConductor,
                store: WenshuAppDelegate.sharedChatStoreRef
            )
        }
        .environment(appState)
    }
}


// MARK: - Detail column (= 2 vertical sub-areas)

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

    var body: some View {
        // v0.43 boss 2026-09-09 OOB 'no divider line':
        // Apple HIG canonical detail/inspector pattern = the column
        // body is a single View that switches via the toolbar Picker.
        // NavigationSplitView auto-applies floating Liquid Glass
        // when the column body is a SwiftUI-native View. The Group
        // wrapper is a transparent container (= no visual effect,
        // = preserves the M6 1-view-per-column pattern).
        //
        // v0.43 boss 2026-09-09 OOB 'right column is not liquid glass':
        // explicitly apply .glassEffect(.regular) to the column body
        // (= forces the macOS 27 Liquid Glass material on the
        // column = matches the left sidebar's visual depth; =
        // no opaque layer underneath).
        Group {
            switch inspectorContent {
            case .tools:
                ZoneModuleView(zoneSlot: .specializedTools)
            case .dynamic:
                ZoneModuleView(zoneSlot: .aiDynamic)
            }
        }
        // v0.48: width is set by .inspectorColumnWidth at the
        // .inspector() call site, which is the matching API for an
        // inspector (navigationSplitViewColumnWidth is for columns).
        // v0.42: column-level .toolbar following ShellSidebarColumn's
        // exact pattern: leading .navigation icon + .primaryAction
        // Picker(.segmented) 2-toggle. The 2 icons at the top
        // right (= wrench + grid) come from the Picker labels
        // (= Picker(.segmented) renders Label icons when labels
        // are hidden and the icons are the only visible content).
        // Note: NO .toolbarBackground modifier (= same as sidebar)
        // because NavigationSplitView 3-column default already
        // provides the Liquid Glass chrome.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Inspector", selection: $inspectorContent) {
                    // v0.46 boss OOB 'SF Symbol dropped, use Lucide'.
                    LucideLabel("Tools", icon: "wrench")
                        .tag(InspectorContent.tools)
                    LucideLabel("Dynamic", icon: "layout-grid")
                        .tag(InspectorContent.dynamic)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary.
        .environment(appState)
    }
}

/// v0.42 boss 2026-09-09 OOB 'simplify the right column':
/// defines the 2 modes of the right-column inspector content
/// (= tools / dynamic). The picker in the .toolbar toggles
/// between them.
enum InspectorContent: Hashable {
    case tools
    case dynamic
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

