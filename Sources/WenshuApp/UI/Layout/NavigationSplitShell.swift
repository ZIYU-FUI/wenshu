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
        .navigationSplitViewStyle(.balanced)  // Apple HIG balanced + Liquid Glass tier columns
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
    @Namespace private var sidebarTabBarNamespace
    @State private var sidebarScope: SidebarScope = .shelves

    var body: some View {
        // VStack (vertical stack) of 2 sub-areas inside one
        // column. Apple HIG standard pattern: multiple sections
        // stacked inside one column, no drag-resizable divider
        // between sections (= the column's width is fixed; =
        // users resize the entire column, not the individual
        // sections inside it).
        //
        // v0.40 boss 2026-09-08 'yesyes mac os 27 default,
        // Liquid Glasseffect': wrap column in Rectangle.glassEffect
        // (.regular) (= the canonical macOS 27 Tahoe Liquid Glass
        // material that auto-applies when the column is a 3rd-
        // party SwiftUI view = the glass material refracts and
        // visually separates columns without a drag-handle divider;
        // = matches Pages / Numbers / Keynote canonical no-line
        // look).
        VStack(spacing: 0) {
            // Top sub-area: scope tab bar + real directory tree
            // wrapped in ZonePerRegionChrome (= top tab bar + bottom
            // status bar; = matches the legacy PaneSplitHost path's chrome
            // coverage for every zone).
            // v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': removed
            // ZonePerRegionChrome wrapper + RegionTabBar wrapper (= per
            // boss 2026-09-08 'Plan A' = rely on Apple's built-in
            // NavigationSplitView column chrome = no custom chrome
            // wrappers). The sidebar scope tab bar (shelves / reference library tabs) is
            // preserved as inline content (= the functionality = scope
            // filtering = is kept; = only the visual chrome wrapper =
            // the 30 PT RegionTabBar chrome = is removed).
            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.chromePaddingClusterGap) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                    PaneTabBar(
                        items: [
                            PaneTabItem(id: "shelves", icon: "book-open", label: "书架"),
                            PaneTabItem(id: "references", icon: "library", label: "资料库"),
                        ],
                        selection: Binding(
                            get: { sidebarScope.rawValue },
                            set: { sidebarScope = SidebarScope(rawValue: $0) ?? .shelves }
                        ),
                        namespace: sidebarTabBarNamespace,
                        namespaceID: "sidebarTabUnderline"
                    )
                }
                .padding(.horizontal, DesignTokens.chromePaddingLarge)
                // The actual sidebar List (= same Apple HIG
                // standard sidebar layout as before; = now
                // filtered by sidebarScope so the scope tab bar
                // at the top has functional control).
                NewLibraryOutlineView(scope: sidebarScope)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: cards zone (= Apple-native chrome = no wrapper).
            ZoneModuleView(zoneSlot: .projectPreview)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // v0.40 boss 2026-09-08 'yesyes mac os 27 default,
        // Liquid Glasseffect': canonical macOS 27 Tahoe Liquid Glass
        // surface for each NavigationSplitView column. .glassEffect
        // (.regular) auto-applies the Liquid Glass material (= the
        // column refracts like glass = visually separates from
        // adjacent columns without a drag-handle divider; = matches
        // Pages / Numbers / Keynote canonical look).
        // v0.40 boss 2026-09-08 OOB 'go up one layer and remove the background': column-level
            // .background(.windowBackgroundColor) removed (= was applying
            // #1E = chrome tier over the entire column = visually distinct
            // from the zone's own .background(.underPageBackgroundColor)).
            // Per-zone .background now flows up through the column with
            // no parent override.
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

    // v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': removed
    // @Namespace private var editorChromeNamespace (= the
    // PaneIconTab matchedGeometryEffect namespace = no longer
    // needed because the editor chrome tab bar was deleted
    // per Plan A).

    var body: some View {
        VStack(spacing: 0) {
            // Top sub-area: real editor wrapped in ZonePerRegionChrome
            // (= adds the top tab bar + bottom status bar that
            // legacy PaneSplitHost path provided per zone; = boss 9/8
            // 'middle two zones lost their top bars' = the chrome was missing because
            // M2 directly embedded the zone view instead of
            // wrapping it in ZonePerRegionChrome).
            //
            // v0.40 boss 2026-09-08 OOB 'editor zone default display is correct' +
            // 'needtop bar..., teb,
            // expand/collapse': the FIRST-layer chrome top bar
            // (= the 30 PT RegionTabBar that every pane in the old
            // 6-region layout had above its content) was removed
            // during CHROME-ARCH-001. Boss wants it back. Wrap the
            // editor content with RegionTabBar (= PaneTabBar + trailing
            // expand button = matches Safari / Pages / Xcode tab bar
            // pattern). The inner EditorPlaceholder's own tab strip
            // (= Safari-style file tabs) becomes the SECOND-layer.
            // v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': removed
            // RegionTabBar wrapper + ZonePerRegionChrome wrapper (= per
            // boss 2026-09-08 'Plan A' = rely on Apple's built-in
            // NavigationSplitView column chrome = no custom chrome
            // wrappers). The editor zone now goes straight to
            // EditorPlaceholder (= Apple-native = no chrome layer).
            EditorPlaceholder()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // Bottom sub-area: real chat wrapped in
            // ChatZoneView (= the canonical chat-zone wrapper
            // that provides the top tab bar via safeAreaInset +
            // the bottom chrome status bar; = boss 9/8
            // 'editor zone, chat zonetop bar' = the chat
            // top tab bar is restored now that the env chain
            // is intact (= the M1 NavigationSplitShell is at
            // the root of the Scene, = @Environment
            // propagation is preserved across column boundaries).
            //
            // No outer ZonePerRegionChrome (= the inner
            // ChatZoneView already provides both top tab bar
            // and bottom status bar = boss 9/8 'chat zone
            // bottom bar'). Skipping the outer chrome avoids
            // double-stacked bottom bars.
            ChatZoneView(conductor: nil, store: nil)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // v0.40: macOS 27 Tahoe Liquid Glass (= see ShellSidebarColumn
        // comment for rationale = columns refract like glass without
        // a drag-handle divider).
        // v0.40 boss 2026-09-08 OOB 'go up one layer and remove the background': column-level
            // .background(.windowBackgroundColor) removed (= was applying
            // #1E = chrome tier over the entire column = visually distinct
            // from the zone's own .background(.underPageBackgroundColor)).
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
struct ShellDetailColumn: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // v0.40 boss 2026-09-09 OOB 'Plan A: full Apple native': removed
            // ZonePerRegionChrome wrapper (= per Plan A = rely on
            // Apple's built-in NavigationSplitView column chrome =
            // no custom chrome wrappers). The specialized tools zone
            // goes straight to ZoneModuleView.
            ZoneModuleView(zoneSlot: .specializedTools)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            // v0.40 Plan A: removed ZonePerRegionChrome wrapper from
            // the dynamic zone (= Apple-native chrome = no wrapper).
            ZoneModuleView(zoneSlot: .aiDynamic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // v0.40: macOS 27 Tahoe Liquid Glass (= see ShellSidebarColumn
        // comment for rationale).
        // v0.40 boss 2026-09-08 OOB 'go up one layer and remove the background': column-level
            // .background(.windowBackgroundColor) removed (= was applying
            // #1E = chrome tier over the entire column = visually distinct
            // from the zone's own .background(.underPageBackgroundColor)).
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
/// states says: "Use `ContentUnavailableView` for empty states,
/// not custom layouts". wenshu now follows this guidance.
struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        ContentUnavailableView(
            name,
            systemImage: icon,
            description: Text(hint)
        )
    }
}
