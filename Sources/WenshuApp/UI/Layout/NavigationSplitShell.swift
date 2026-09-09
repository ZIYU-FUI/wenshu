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

    /// Inspector presentation state. Apple restores this across launches
    /// for trailing-column inspectors, and `InspectorCommands` wires the
    /// standard View > Inspector menu item plus its keyboard shortcut.
    @State private var inspectorVisible: Bool = true

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
        } detail: {
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
            // inspector, which carries the sidebar material. Rebuilt as
            // a 2-column NavigationSplitView whose detail hosts
            // .inspector(): measured 40/255 on both sides = match.
            ShellContentColumn(appState: appState)
                .inspector(isPresented: $inspectorVisible) {
                    ShellDetailColumn(appState: appState)
                        .inspectorColumnWidth(min: 250, ideal: 280, max: 360)
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

    // v0.51 boss 2026-09-09 OOB 'the sidebar toolbar toggle can go now
    // that both regions share one column': the Shelves / Reference
    // Picker is deleted. It switched the whole column between the tree
    // and the cards, which the vertical split made redundant. The scope
    // value it produced was never read either — NewLibraryOutlineView
    // took it as an init parameter and never filtered on it.

    /// Height of the card region at the bottom of the sidebar.
    /// Persisted so the split survives relaunch, the same way AppKit
    /// autosaves a real split-view position.
    @AppStorage("wenshu.sidebar.cardZoneHeight") private var cardZoneHeight: Double = 260
    /// Height at the moment the drag started, so the gesture applies a
    /// delta rather than compounding on every change callback.
    @State private var cardZoneDragStart: Double?

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
        NewLibraryOutlineView()
            // v0.49 boss 2026-09-09 OOB 'split the left column into a
            // tree on top and cards below': the card zone is a bottom
            // safe-area accessory on the sidebar List, which is Apple's
            // API for attaching a fixed region to a sidebar (Mail's
            // account bar and Xcode's filter bar are the same shape).
            //
            // Measured three ways before picking this one. Wrapping the
            // column in VSplitView drags the top region down to the
            // content tier (34/255 against a 40/255 sidebar) — the same
            // material loss that hit the right column. One List with two
            // Sections keeps the material but cannot host a non-List
            // card grid. safeAreaInset keeps the material AND takes an
            // arbitrary view.
            //
            // v0.50: the height is a persisted value with a drag handle
            // on top of the card zone, so the two regions resize like a
            // split view while the accessory keeps the sidebar material.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ZoneModuleView(zoneSlot: .projectPreview)
                    .frame(height: cardZoneHeight)
                    .overlay(alignment: .top) { cardZoneResizeHandle }
            }
            // v0.45 default-first: Apple canonical sidebar width hint
            // (= HIG sidebar 220-320 PT). Without this modifier the
            // NSSplitView autosave frame wins and the columns keep
            // whatever width a prior build left in UserDefaults.
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }

    /// Drag handle between the directory tree and the card zone.
    ///
    /// SwiftUI has no resizable equivalent of `safeAreaInset`, and the
    /// alternative that does resize (`VSplitView`) costs the sidebar
    /// material. This is the smallest thing that gives the split a drag
    /// handle: a 1 PT separator with a 6 PT hit area, the resize cursor,
    /// and a gesture that writes the persisted height.
    private var cardZoneResizeHandle: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .frame(height: 6)                 // hit area, per Apple's 6 PT splitter
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = cardZoneDragStart ?? cardZoneHeight
                        if cardZoneDragStart == nil { cardZoneDragStart = start }
                        // Dragging up grows the card zone, so the delta is
                        // inverted relative to the drag direction.
                        cardZoneHeight = clampCardZoneHeight(start - value.translation.height)
                    }
                    .onEnded { _ in cardZoneDragStart = nil }
            )
    }

    /// Keeps both regions usable: the card zone never eats the whole
    /// column and never collapses to nothing.
    private func clampCardZoneHeight(_ proposed: Double) -> Double {
        min(max(proposed, 120), 600)
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

    /// Whether the chat panel floats over the document.
    /// Persisted so the panel is where the user left it after a relaunch.
    @AppStorage("wenshu.chat.floatingVisible") private var chatVisible: Bool = false
    /// Height of the floating chat panel, also persisted.
    @AppStorage("wenshu.chat.floatingHeight") private var chatHeight: Double = 320
    /// Height at drag start, so the gesture applies a delta instead of
    /// compounding on every change callback.
    @State private var chatDragStart: Double?

    var body: some View {
        // v0.53 boss 2026-09-09 OOB: float a chat panel over the lower
        // half of the middle column.
        //
        // Chat used to be the other half of a Picker: picking it REPLACED
        // the document. Floating means both are on screen at once, so the
        // Picker becomes a show/hide toggle and the panel is an overlay
        // pinned to the bottom edge. The document keeps the full column
        // underneath and is never resized by the panel.
        EditorPlaceholder()
            .overlay(alignment: .bottom) {
                if chatVisible {
                    floatingChatPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: chatVisible)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $chatVisible) {
                        LucideLabel("Chat", icon: "messages-square")
                    }
                    .toggleStyle(.button)
                    .help(chatVisible ? "隐藏聊天" : "显示聊天")
                }
            }
            .environment(appState)
    }

    /// The floating panel itself.
    ///
    /// Liquid Glass is what macOS 26 uses for content floating above other
    /// content, so the panel reads as hovering rather than as another
    /// pane. `.glassEffect` supplies the material, the blur, and the
    /// hairline edge, so the panel adds no colors of its own.
    private var floatingChatPanel: some View {
        ChatZoneView(conductor: nil, store: nil)
            .frame(height: chatHeight)
            .overlay(alignment: .top) { chatResizeHandle }
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            // Inset from the column edges so the panel reads as floating
            // ON the column rather than docked to it.
            //
            // The padding has to be applied by the container, not by the
            // panel: an overlay is sized against its host, so padding on
            // this side of .glassEffect insets the glass while the panel
            // still lays out edge to edge. The container applies it via
            // .safeAreaPadding instead.
    }

    /// Drag handle on the panel's top edge.
    ///
    /// v0.56 boss 2026-09-09 OOB: the panel may only be pulled UP, no
    /// other direction. So the gesture is one-way — it grows the panel
    /// from whatever height the drag started at and never shrinks it.
    /// Verified the old behaviour first by driving a real downward drag
    /// against the running app: the panel collapsed 320 -> 200, which is
    /// exactly what this now refuses.
    ///
    /// The cursor says the same thing: .resizeUp, not .resizeUpDown, so
    /// the handle advertises the one direction it accepts.
    private var chatResizeHandle: some View {
        Rectangle()
            .fill(.separator)
            .frame(height: 1)
            .frame(height: 6)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeUp.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = chatDragStart ?? chatHeight
                        if chatDragStart == nil { chatDragStart = start }
                        // Upward drag = negative translation = growth.
                        // Downward drag would shrink the panel, so clamp
                        // the delta at 0 and ignore it entirely.
                        let growth = max(-value.translation.height, 0)
                        chatHeight = min(start + growth, Self.chatMaxHeight)
                    }
                    .onEnded { _ in chatDragStart = nil }
            )
    }

    /// Upper bound for the panel, so it cannot swallow the document.
    private static let chatMaxHeight: Double = 700
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

