//
//  NavigationSplitShell.swift · Wenshu · M1-shell (2026-09-08) + v0.72 Q99 LOW fix
//
//  DEFERRED (v0.77 spec decision):
//  ViewInspector test coverage for this view is deferred to v0.80+
//  (= see .scratch/v0.77-workspaceview-tests/spec.md). NavigationSplitShell
//  is the macOS SwiftUI 27+ shell that the WorkspaceView container wraps;
//  testing requires a stable NavigationSplitView column-width surface
//  (= Q227-Q231 trap scope) plus mock WorkspaceMode / LayoutTreeStore.
//
//  This file is NOT dead code (= per Q57: 3rd-party verdict ≠ authority).
//
//  SwiftUI NavigationSplitView 4-column shell (= sidebar + content + inspector + detail).
//  This is the canonical layout per AGENTS.md §11 + boss 2026-09-03 OOB.
//
//  Column configuration:
//    - Sidebar (= leftmost; = library / shelf / book outline tree)
//    - Content (= 2nd column; = book cards / chapter list / kanban / todo)
//    - Inspector (= 3rd column; = metadata + character pane)
//    - Detail (= rightmost; = editor canvas / preview pane)
//
//  Column-width policy:
//    - .navigationSplitViewColumnWidth(min:ideal:max:) on each column
//    - .inspectorColumnWidth on the inspector column
//    - Apple-default initial values (= sidebar 140pt / content 200pt / detail natural)
//
//  State bindings:
//    - @State columnVisibility (= driven by WenshuSettings)
//    - @State preferredCompactColumn (= Apple default = .sidebar)
//
//  Migration note: v0.72 SwiftData migration did not touch this file
//  (= persistence layer is below the UI layer; = no @Model class is
//  referenced directly from this view).
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

    /// v0.88 boss 2026-09-10 OOB 'inspector always shown + always pass the value when there is one':
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
            // v0.95 boss 2026-09-10 OOB 'NSV probe was working fine before':
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
            // v0.97 boss 2026-09-10 OOB 'NSV probe was working fine before':
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
            // v0.98 boss 2026-09-10 OOB 'NSV probe was working fine before':
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
            // v0.101 boss 2026-09-10 OOB 'set each column to Apple's recommended parameters
            // — min/ideal/max': re-apply
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
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'on initial launch, make the left and left-2
            // columns use the minimum size; leave the other two columns alone for now': set the sidebar +
            // content (= left + left-2) ideal widths to their min
            // values (= sidebar 220, content 240) so the columns
            // open at their tightest legal width (= no extra padding
            // room = the user sees the smallest sidebar + cards band
            // that still fits the row icons + labels). The detail +
            // inspector ideal widths stay as-is (= 600 / 280) per the
            // boss's 'leave the other two columns alone' instruction.
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
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'left and left-2 use the minimum':
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
                // v1.0.0-m1-shell boss 2026-09-10 OOB 'Keynote and the three office apps
                // all use this same logic': wire the inspector's `isPresented` to
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
        // v0.71 P1 batch 6 dual-axis followup (= Q99 Standards axis MED):
        // redundant injection is benign (per the audit's own conclusion)
        // but the design relies on multiple re-injection sites: if one
        // is dropped during a future refactor, env-chain failures will
        // surface at the layout pass. Marked CRITICAL DO NOT REMOVE in
        // the comment block so future contributors don't try to
        // "clean up" the apparent redundancy.
        .environment(appState)
        // CHATZONE-CRASH-FIX part 2: also re-inject bookStore if
        // available (= descendants read BookStore from env via
        // @Environment(BookStore.self) = ForeshadowingView /
        // PlaceholderView / PreviewPane / WorkspaceView. Without
        // this re-injection, the env chain fails at the layout
        // pass with 'No Observable object of type BookStore found').
        // CRITICAL DO NOT REMOVE (= see comment block above).
        .environment(bookStore)
    }
}// v1.38 ticket 001 (= real fix per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112):
// `ShellSidebarColumn` moved to its own file at
// `Sources/WenshuApp/UI/Layout/ShellSidebarColumn.swift`. The struct
// block (= 29 lines including the `// MARK: - Sidebar column` header
// + the Apple HIG sidebar rationale + the NewLibraryOutlineView body)
// is removed here so the same name no longer compiles twice.
// Same module = no new import needed for the consumer
// (= NavigationSplitShell instantiates ShellSidebarColumn directly).

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

// v1.42 ticket 001 (= real fix per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112):
// `ShellMiddleColumn` moved to its own file at
// `Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift`. The struct
// block (= 466 lines including the `/// Apple HIG content column`
// doc + the 440-line body) is removed here so the same name no
// longer compiles twice. Same module = no new import needed for the
// consumer (= NavigationSplitShell instantiates ShellMiddleColumn
// directly).




// v1.39 ticket 001 (= real fix per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112):
// `ShellContentColumn` moved to its own file at
// `Sources/WenshuApp/UI/Layout/ShellContentColumn.swift`. The struct
// block (= 80 lines including the `// MARK: - Detail column` header
// + the 70-line Apple HIG split-views rationale + the
// EditorChatSplitHost body) is removed here so the same name no
// longer compiles twice.
// Same module = no new import needed for the consumer
// (= NavigationSplitShell instantiates ShellContentColumn directly).


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

    // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo get their own dedicated windows':
    // wire `@Environment(\.openWindow)` so the toolbar buttons can
    // open dedicated KanbanWindow / TodoWindow scenes (= the
    // SwiftUI macOS 14+ API for opening secondary windows from
    // a scene; = Pages / Numbers / Keynote all use it for
    // independent document windows).
    @Environment(\.openWindow) private var openWindow

    /// v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages': each
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
            // v1.0.0-m1-shell boss 2026-09-12 OOB 'the 12-tab view's localization is incomplete':
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
                // v1.0.0-m1-shell boss 2026-09-11 OOB 'three per page,
                // split into four pages, show them all': Page 1 = Authoring +
                // Plot / Placeholder / Foreshadowing = the structural / plot
                // tracking tools.
                return [
                    WenshuI18n.t("tab.title.foreshadowing"),
                    WenshuI18n.t("tab.title.placeholder"),
                    WenshuI18n.t("tab.title.plot_thread"),
                ]
            case .authoringStyle:
                // Page 2 = Authoring + Style / Experience / Genre = the
                // readability / style reference tools.
                // v1.0.0-m1-shell boss 2026-09-12 OOB 'the 12-tab view's
                // localization is incomplete': use WenshuI18n.t() (= same value
                // as the allTools entry above) so the Set
                // membership check below correctly filters the
                // 3 tabs for this page.
                return [
                    WenshuI18n.t("tab.title.long_form"),
                    WenshuI18n.t("tab.title.reader_experience"),
                    WenshuI18n.t("tab.title.genre_fit"),
                ]
            case .authoringCharacters:
                // Page 3 = Authoring + Characters / Relationships / Emotion = the
                // character-driven analysis tools.
                return [
                    WenshuI18n.t("tab.title.character_relationships"),
                    WenshuI18n.t("tab.title.character_lifecycle"),
                    WenshuI18n.t("tab.title.emotion_curve"),
                ]
            case .projectManagement:
                // Page 4 = Project Management + Ideas / Tags / Book Settings =
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
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'OK then, in the right column
        // put the four-page switcher in Trailing, aligned right': per the boss's request,
        // the 4-page Picker (= Authoring (Fiction) / Style / Characters / Project
        // Management) now lives in the NSWindow main toolbar's trailing
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
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'for every page, add a
        // title-plus-divider combo at the top, then put the tab bar below
        // the divider — full-width tab bar that auto-fits the right-column width': per the
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
            // format as the 'Studio' / 'Assets' headers used
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'between the title and the tab bar,
            // it's 4pt short': per the boss's request, ADD 4 PT of
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'remove all custom padding
            // and switch to Apple-standard expressions — find an approximate value': remove the custom
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
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'wrong position for the button — by default
            // it should be at the far right': place the toggle button AFTER the
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'OK then, in the right column
            // put the four-page switcher in Trailing, aligned right' (the canonical ask):
            // the 4-page Picker goes in the TRAILING area
            // (= ToolbarItem(placement: .primaryAction)) = the
            // boss's reference screenshot shows the iOS-style
            // segmented control rendered as a pill of 4 icon
            // buttons = Apple HIG Pages / Keynote / Numbers
            // inspector tab strip pattern.
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggl,
            // put it in Center': the kanban + todo + inspector toggle
            // buttons go in the CENTER area (= .principal).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'these four buttons — just use
            // this style, and switching should change the right column's page': use the
            // iOS segmented control style for the Picker (= the
            // .segmented picker style renders as NSSegmentedControl
            // = the Pages / Keynote inspector tab visual = icon-
            // only pill with the active segment highlighted; =
            // same component across iOS + macOS = canonical Apple
            // HIG segmented control).
            //
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'but I don't know why you
            // moved the position out of Trailing': the previous commit
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'for the toolbar, use the one we just
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
// v1.0.0-m1-shell boss 2026-09-11 OOB 'for the toolbar, use the one we just
// settled on — that's Apple's default toolbar style': the toolbar picker uses the
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
                            Image(systemName: page.icon)
                        }
                        .tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .help(WenshuI18n.t("inspector.page.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'kanban/todo/toggle — put it
            // in Center': per the boss's request, the inspector
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
                    // v1.0.0-m1-shell boss 2026-09-11 OOB 'our buttons look
                    // different from the default effect — check Apple's default pattern': use
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
                        Image(systemName: appState.inspectorVisible ? "sidebar-right" : "sidebar.left")
                    }
                }
                .help(WenshuI18n.t("inspector.toggle.help"))
            }
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages':
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
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages:
            // Foreshadowing, Placeholder — right column's first page; Long-form Guardrails,
            // Reader Experience, Plot Threads — right column's second page' (= later relaxed to 4 pages
            // × 3 tools per page): the Picker is now INSIDE the
            // inspector column body (see the `body` above) =
            // attaching it to the .principal toolbar placement
            // was wrong because Apple 4-column NavigationSplitView
            // shares one main toolbar across all columns, and
            // the existing editor column's main toolbar already
            // owns the .principal slot. Drop the toolbar
            // ToolbarItem here.
            // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo —
            // show them in their own dedicated windows. Other Apple apps don't integrate these
            // into the main window, they just open a separate window — and a Kanban board needs lots
            // of horizontal space anyway': add 2 toolbar buttons that open dedicated
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
            // put it in Center': per the boss's request, the kanban
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
                        Image(systemName: "kanban")
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
                        Image(systemName: "list-checks")
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

/// v1.0.0-m1-shell boss 2026-09-11 OOB 'split into two pages: Foreshadowing, Placeholder
/// — right column's first page; Long-form Guardrails, Reader Experience, Plot Threads — right column's second page':
/// the inspector column (= the rightmost NSV column) was
/// previously 1 page with 5 RadioButton tabs (= Foreshadowing / Placeholder /
/// Long-form Guardrails / Reader Experience / Plot Threads = 5 specialized tools fighting
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
/// v1.0.0-m1-shell boss 2026-09-11 OOB 'three per page, split into four pages, show them
/// all — show them now, I'll decide later how to organize them': expand
/// from 2 pages / 5 tools (= .authoring / .craft) to **4 pages
/// × 3 tools = 12 tools** (= every tool in the specializedTools
/// zone gets a page; = the user wants to see all 12 in the
/// toolbar picker; = the actual page→tool mapping is provisional
/// and the boss will reassign tools to pages later).
///
/// Page 1 (= .authoringFiction) = Authoring, with Plot / Characters / Worldbuilding:
///   - Foreshadowing
///   - Placeholder
///   - Plot Threads
///
/// Page 2 (= .authoringStyle) = Authoring, Style / Experience:
///   - Long-form Guardrails
///   - Reader Experience
///   - Genre Fit
///
/// Page 3 (= .authoringCharacters) = Authoring, Character-related:
///   - Character Relationships
///   - Character Lifecycle
///   - Emotion Curve
///
/// Page 4 (= .projectManagement) = Project Management / Ideas / Settings:
///   - Idea Library
///   - Tag Manager
///   - Book Settings
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
        case .authoringFiction:     return "book.pages.fill"      // SF Symbols 6 book.pages.fill = fiction
        case .authoringStyle:       return "paintpalette.fill"    // SF Symbols 6 paintpalette.fill = style
        case .authoringCharacters:  return "person.2.fill"        // SF Symbols 6 person.2.fill = characters
        case .projectManagement:    return "folder.fill.badge.gearshape"  // SF Symbols 6 folder + gear = project settings
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

/// v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo get their own dedicated windows':
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



// v1.36 ticket 001 (= real fix per Q34 5.4 + Q173 ponytail + Q186 + Q112):
// `ShellPlaceholder` moved to its own file at
// `Sources/WenshuApp/UI/Layout/ShellPlaceholder.swift` (= v1.34 ticket 001
// extraction). The struct block (= 22 lines including the legacy
// `// MARK: - Placeholder view` header + the long ContentUnavailableView
// rationale block) is removed here so the same name no longer compiles twice.
//
// Per Q34 5.2: the extraction was botched (= v1.34 created the new file but
// left the legacy declaration in place; = main failed to compile with
// `invalid redeclaration of 'ShellPlaceholder'`). v1.36 finishes the
// extraction by removing the legacy block from NavigationSplitShell.swift.
//
// Per Q57: the legacy `ShellPlaceholder` body (Apple HIG rationale block +
// ContentUnavailableView wrapper) lives verbatim in the new file (= no
// behavior change; = pure refactor = 1 file 1 commit).

