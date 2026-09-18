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
            // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
            // audit ticket 4): strip
            // `.navigationSplitViewColumnWidth(min:ideal:max:)`
            // (= per boss 9/10 'Apple default' OOB = let
            // `.automatic` style pick columns = Mail / Notes /
            // Finder default). The previous 5-round iteration
            // (= v0.83 / v0.95 / v0.97 / v0.98 / v0.101) tried
            // various min/ideal/max ranges; all caused sidebar
            // to collapse to 8 PT or split-view column-width
            // layout pass to enter a degenerate state. The
            // canonical answer per wenshu-visual-alignment/SKILL.md
            // reverse-pattern = strip the modifier + let
            // SwiftUI's NSV `.automatic` style use its Apple HIG
            // canonical column ranges (~140 / ~200 / detail natural).
            // v1.64 boss 2026-09-18 'sidebar has a real problem —
            // Apple API has other methods, not necessarily outline
            // tree': switch from NewLibraryOutlineView() (= List(
            // .sidebar) = NSTableView = NSTableRowData NSLayout
            // Constraint conflict on window resize per
            // WenshuApp-2026-09-18-143621.ips) to LazySidebarView
            // (= pure-SwiftUI ScrollView + LazyVStack + Button rows;
            // = no NSTableView = no CoreAutoLayout conflict during
            // window resize). LazySidebarView is in
            // Sources/WenshuApp/Views/Library/LazySidebarView.swift.
            LazySidebarView()
        } content: {
            // v0.69 boss 2026-09-10 OOB 'land the canonical 6-zone
            // layout from the probe (= NavigationSplitView 3 columns
            // + .inspector() + VSplitView in the detail +
            // .safeAreaInset on the sidebar)': the middle column
            // (= the section between sidebar and detail) is the
            // outline + cards band, exactly as in the probe's
            // ContentZone. The probe measured window = 1449, sidebar
            // = 240, content = 280, detail = 648 with this layout.
            // v1.27 component-architecture (2026-09-17): now passes
            // `envAppState:` (= the @Bindable / @Environment entry
            // declared on ShellMiddleColumn) in addition to the
            // existing `appState:` shim. Both point to the same
            // instance (= wenshu's NSA framework convention; =
            // see ShellMiddleColumn L57-72 for the @Bindable +
            // `let appState` parallel-ownership pattern).
            // macOS 27 doc-alignment (audit ticket 4): strip
            // `.navigationSplitViewColumnWidth(min:ideal:max:)`
            // (= canonical Apple default; see comment above).
            ShellMiddleColumn(envAppState: appState, appState: appState)
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
            // macOS 27 doc-alignment (audit ticket 4): strip
            // `.navigationSplitViewColumnWidth(min:ideal:max:)`
            // (= canonical Apple default; see comment above).
            ShellContentColumn(appState: appState, bookStore: bookStore)
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
                // macOS 27 doc-alignment (audit ticket 4): strip
                // `.inspectorColumnWidth(min:ideal:max:)` (= canonical
                // Apple default for inspector; matches Mail / Notes /
                // Reminders / Pages inspector width).
                .inspector(isPresented: Binding(
                    get: { appState.inspectorVisible },
                    set: { newValue in appState.inspectorVisible = newValue }
                )) {
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


// v1.43 ticket 001 (= real fix per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112):
// `ShellDetailColumn` moved to its own file at
// `Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift`. The struct
// block (= 494 lines including the `/// Apple HIG detail column` doc
// + the 450-line body) is removed here so the same name no longer
// compiles twice. Same module = no new import needed for the
// consumer (= NavigationSplitShell instantiates ShellDetailColumn
// directly). This completes the NavigationSplitShell sibling split
// arc (= 4 of 4 siblings extracted).



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
        // v1.0.0-m1-shell boss 2026-09-16 OOB '所有 ICON，都不要 .fill':
        // migrated to outline glyphs (= the canonical Apple HIG
        // form for the Liquid Glass 3rd-generation design language).
        // The .fill variant (= solid color glyph) is reserved for
        // status indicators (= error / success badges); tool tab
        // chrome should use outline glyphs throughout.
        case .authoringFiction:     return "book.pages"      // SF Symbols 6 outline
        case .authoringStyle:       return "paintpalette"    // SF Symbols 6 outline
        case .authoringCharacters:  return "person.2"        // SF Symbols 6 outline
        case .projectManagement:    return "folder.badge.gearshape"  // SF Symbols 6 folder + gear
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

