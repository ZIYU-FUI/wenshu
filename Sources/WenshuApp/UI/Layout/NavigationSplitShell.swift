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
            ShellSidebarColumn(appState: appState)
        } content: {
            // Apple HIG content (= middle column; = context list
            // showing the items from the sidebar selection). 2
            // vertical sub-areas (= VStack).
            ShellContentColumn(appState: appState)
        } detail: {
            // Apple HIG detail (= rightmost column; = the
            // selected item's detail / inspector). 2 vertical
            // sub-areas (= VStack).
            ShellDetailColumn(appState: appState)
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

/// Apple HIG sidebar column (= 2 vertical sub-areas: directory tree +
/// cardgrid). Per boss 9/8 'directory+cardmerge, yes
///, in progress' = the 2 sub-areas share
/// one column without a drag-resizable divider between them
/// (= Apple HIG's standard "List with multiple sections" pattern
/// = Mail's sidebar = inbox + sent + drafts stacked vertically
/// inside one column).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: NewLibraryOutlineView (real sidebar tree
///   from v0.34+; = the source of truth for the library
///   shelf/book/folder hierarchy)
/// - bottom sub-area: ZoneModuleView(zoneSlot: .projectPreview)
///   (real card grid from v0.34+; = displays the documents
///   for the current sidebar selection)
struct ShellSidebarColumn: View {
    let appState: AppState

    // v0.40 boss 2026-09-08 OOB 'directory tree top bar is also missing': sidebar
    // needs its own top tab bar (= matches chat zone's 3 fixed
    // tabs pattern + editor zone's tab strip). Apple HIG
    // canonical pattern: PaneTabBar at the top of the column
    // (= like Notes.app / Mail.app = scope selector at top of
    // the sidebar). The 2 tabs map to the existing top-level
    // grouping (= = per-shelf books; = = per-category
    // reference library). The NewLibraryOutlineView receives
    // the scope via initializer (= so it can filter which
    // rows are visible).
        // v0.42 boss 2026-09-09 OOB 'use the right column's tab-switch
    // pattern for all 3 columns (= column body = single view, switch
    // via Picker in .toolbar)': the sidebar column body is a
    // single NewLibraryOutlineView (or the cards zone) selected
    // by sidebarScope. The 2-toggle Picker in the .toolbar above
    // switches the column content (= Apple canonical inspector
    // pattern = same as ShellDetailColumn).
    @State private var sidebarScope: SidebarScope = .shelves

    var body: some View {
        // v0.43 boss 2026-09-09 OOB 'no divider line':
        // Apple HIG canonical sidebar pattern = the column body
        // IS a List (= NewLibraryOutlineView wraps a List with
        // .listStyle(.sidebar)). This is the ONLY pattern that
        // makes NavigationSplitView render the column with
        // floating Liquid Glass material (= column-to-column
        // seam disappears = Pages/Keynote look).
        //
        // Apple HIG NavigationSplitView canonical sidebar:
        //   NavigationSplitView { List(...) } content: ... detail: ...
        // Note: NOT wrapped in Group or any other view (= the
        // List must be the direct first child of the column).
        //
        // The scope toggle in the .toolbar filters the List
        // rows (= when scope = .shelves, outline shows only
        // bookshelf rows; when scope = .references, only the
        // reference library rows). This preserves the M6
        // 1-view-per-column pattern while making the column
        // body a direct List (= Apple canonical).
        NewLibraryOutlineView(scope: sidebarScope)
            // v0.45 default-first: Apple canonical sidebar width hint
            // (= HIG sidebar 220-320 PT). Without this modifier the
            // NSSplitView autosave frame wins and the columns keep
            // whatever width a prior build left in UserDefaults.
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Sidebar Scope", selection: $sidebarScope) {
                    // v0.46 boss 2026-09-09 OOB 'SF Symbol is dropped, use
                    // the third-party icon library': every icon in the shell
                    // comes from Lucide (= lucide-swift 1.25.0). Names below
                    // verified against the package's icon catalog.
                    Label { Text("Shelves") } icon: { LucideIcon("library", size: 16) }
                        .tag(SidebarScope.shelves)
                    Label { Text("Reference") } icon: { LucideIcon("book-open", size: 16) }
                        .tag(SidebarScope.references)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
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

/// Apple HIG content column (= 2 vertical sub-areas: editor +
/// chat). Per boss 9/8 ' sidebar / content / detail' +
/// ' sidebar / content / detail' but the columns are
/// CONTINUOUS (1 outer NavigationSplitView, NOT 2 stacked).
///
/// M2 (= this commit): swap the M1 placeholders for the real
/// wenshu zone views:
/// - top sub-area: EditorPlaceholder (real editor from v0.34+;
///   = routes to EditorEditContent internally with the markdown
///   engine + word count + auto-save)
/// - bottom sub-area: ChatView (real chat from v0.34+; = the
///   LLM conversation surface with attachment upload)
struct ShellContentColumn: View {
    let appState: AppState

    // v0.40 boss 2026-09-09 OOB 'macOS 27 official API + segmented picker':
    // replaces the previous custom PaneIconTab + matchedGeometryEffect
    // namespace with Apple's canonical Picker(.segmented). The
    // @State holds the selected editor mode; future ticket can wire
    // to EditorPlaceholder's mode toggle.
    @State private var editorMode: EditorMode = .edit
    // v0.42 boss 2026-09-09 OOB 'use the right column tab-switch
    // pattern for all 3 columns': the content column body is a
    // single EditorPlaceholder (or ChatZoneView) selected by
    // contentScope.
    @State private var contentScope: ContentScope = .editor
    // v0.40: removed @Namespace editorChromeNamespace (= no longer
    // needed because the Apple Picker(.segmented) handles its own
    // selection animation = no custom matchedGeometryEffect needed).

    var body: some View {
        // v0.43 boss 2026-09-09 OOB 'no divider line':
        // Apple HIG canonical for non-sidebar columns = the column
        // body is a single View that switches via the toolbar Picker.
        // NavigationSplitView auto-applies floating Liquid Glass
        // when the column body is a SwiftUI-native View. The Group
        // wrapper is a transparent container (= no visual effect,
        // = preserves the M6 1-view-per-column pattern).
        Group {
            switch contentScope {
            case .editor:
                EditorPlaceholder()
            case .chat:
                ChatZoneView(conductor: nil, store: nil)
            }
        }
        // v0.45 default-first: the content column absorbs the window's
        // slack (= Apple HIG "give every column a minimum width and let
        // the content column absorb slack"). min only, no max.
        .navigationSplitViewColumnWidth(min: 420, ideal: 640)
        // v0.40 boss 2026-09-09 OOB '100% Apple standard + restore all
        // top bars': attaches the editor chrome top bar via Apple's
        // canonical .toolbar(id:) API (= the column-level toolbar
        // appears at the column's chrome position = the top edge
        // of the content column). Uses Apple-native ToolbarContent
        // (= no custom HStack / no custom chrome background colors).
        // Per WWDC25-323 'Build a SwiftUI app with the new design',
        // .toolbar(id:) on a NavigationSplitView column IS the
        // canonical Apple column chrome top bar (= no custom
        // RegionTabBar wrapper needed).
        // v0.40 boss 2026-09-09 OOB 'macOS 27 official API + use segmented picker':
        // replaced the custom PaneIconTab with Apple's canonical
        // Picker(...).pickerStyle(.segmented) for the editor mode tabs
        // (= preview / edit). Per WWDC25-323 'Build a SwiftUI app with
        // the new design' (the official macOS 27 sample code):
        //
        //   Picker("View", selection: $selection) {
        //     Text("Map").tag(ViewMode.map)
        //     Text("List").tag(ViewMode.list)
        //   }
        //   .pickerStyle(.segmented)
        //
        // Apple HIG rationale:
        // - Segmented pickers transform into Liquid Glass during
        //   interaction (= automatic WWDC25-323 visual upgrade).
        // - 2-5 segments = the canonical Apple range (= wenshu's
        //   2 tabs for editor + 5 tabs for tools fit perfectly).
        // - No custom matchedGeometryEffect / no custom PaneIconTab
        //   wrapper needed (= Apple handles the underline animation).
        // v0.42: the preview/edit editor mode toggle was inside the
        // editor content (= EditorPlaceholder's own tab strip).
        // Now that the column body is a single view switchable via
        // contentScope, the preview/edit toggle stays inside
        // EditorPlaceholder (no need to surface it in the column
        // toolbar). The .primaryAction slot is now used by the
        // Editor / Chat Picker.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Content", selection: $contentScope) {
                    // v0.46 boss OOB 'SF Symbol dropped, use Lucide'.
                    Label { Text("Editor") } icon: { LucideIcon("square-pen", size: 16) }
                        .tag(ContentScope.editor)
                    Label { Text("Chat") } icon: { LucideIcon("messages-square", size: 16) }
                        .tag(ContentScope.chat)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        // v0.40: macOS 27 Tahoe Liquid Glass (= see ShellSidebarColumn
        // comment for rationale = columns refract like glass without
        // a drag-handle divider).
        // v0.40 boss 2026-09-08 OOB 'go up one layer and remove the background': column-level
            // .background(.windowBackgroundColor) removed (= was applying
            // #1E = chrome tier over the entire column = visually distinct
            // from the zone's own ).
            // Per-zone .background now flows up through the column with
            // no parent override.
        // CHATZONE-CRASH-FIX (2026-09-08): re-inject AppState into
        // the env chain. SwiftUI 6+ breaks the @Environment chain
        // across NavigationSplitView's 3-column boundary (= the
        // child column views are re-rooted in their own env
        // subgraph). Without this re-injection, ChatZoneView /
        // ZoneModuleView / NewLibraryOutlineView all crash with
        // 'No Observable object of type AppState found' on access.
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
        // v0.45 default-first: Apple HIG inspector column is a narrow
        // fixed-ish trailing column (250-280 PT), NOT half the window.
        // Removed the manual .glassEffect(.regular) too — macOS 27
        // NavigationSplitView applies the column material itself.
        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 360)
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
                    Label { Text("Tools") } icon: { LucideIcon("wrench", size: 16) }
                        .tag(InspectorContent.tools)
                    Label { Text("Dynamic") } icon: { LucideIcon("layout-grid", size: 16) }
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
/// between them (= same pattern as SidebarScope).
enum InspectorContent: Hashable {
    case tools
    case dynamic
}

/// v0.42 boss 2026-09-09 OOB 'column body = 1 view, no VStack':
/// scope enum for the ShellContentColumn's tab switch
/// (= Apple canonical inspector pattern: 1 column = 1 view,
/// the Picker above drives the switch). 2 modes:
/// - .editor: EditorPlaceholder (the markdown editor + tabs)
/// - .chat: ChatZoneView (the LLM chat surface)
enum ContentScope: Hashable {
    case editor
    case chat
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
            Label { Text(name) } icon: { LucideIcon(icon, size: 36) }
        } description: {
            Text(hint)
        }
    }
}

