//
//  NavigationSplitShell.swift · Wenshu
//
//  SwiftUI NavigationSplitView 4-column shell (= sidebar + content +
//  detail + inspector) for the macOS 27 workspace.
//
//  Column configuration:
//    - Sidebar (= leftmost; = library / shelf / book outline tree)
//    - Content (= 2nd column; = book cards / chapter list / kanban / todo)
//    - Detail (= 3rd column; = editor canvas / preview pane)
//    - Inspector (= rightmost; = metadata + character pane)
//
//  Column-width policy: `.navigationSplitViewColumnWidth(min:ideal:max:)`
//  + `.inspectorColumnWidth`. Apple-default initial values (= sidebar
//  ~220/280/360 PT; = content ~240/320/480 PT; = detail ~400/600/900 PT;
//  = inspector ~240/280/360 PT).
//
//  State bindings: columnVisibility driven by AppState; =
//  preferredCompactColumn = .sidebar (= Apple default).
//
//  Apple HIG layout (single outer NavigationSplitView, not 2 stacked):
//  the user-facing red line is 1 continuous vertical divider that runs
//  the full window height. Only 1 outer NavigationSplitView with each
//  column containing 2 vertically-stacked sub-areas (= VStack) achieves
//  this; = 2 stacked NavigationSplitView would produce 2 separate
//  vertical dividers (= 4 dividers total = wrong).
//
//    Outer: NavigationSplitView (3 columns, Apple HIG canonical)
//    ├── sidebar (1 column, 2 vertical sub-areas, no inner divider):
//    │ ├── top: directory tree
//    │ └── bottom: card
//    ├── content (1 column, 2 vertical sub-areas, no inner divider):
//    │ ├── top: editor
//    │ └── bottom: chat
//    └── detail (1 column, 2 vertical sub-areas, no inner divider):
//    ├── top: tools zone
//    └── bottom: dynamic zone
//
//  Activation: `LayoutTreeState.useThreeColumnSplit` (= optional Bool =
//  default `nil`/off = `PaneSplitHost` path = zero regression).
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
    /// ShellState was removed in 2026-10-03 overabstraction cleanup
    /// (= sidebar / inspector / chat visibility / inspector page
    /// all migrated to WorkspaceUIState + NavigationSplitShell
    /// @State; = ShellState held 0 fields after Phase 1a-1c).

    // Column-local UI state. Threaded into ShellMiddleColumn
    // (= the @Bindable entry the PreviewPane binding reads).
    // Same lifetime as WorkspaceView's owner; = passed by reference.
    var workspaceUI: WorkspaceUIState
    /// Optional BookStore for env injection (= descendants
    /// like ForeshadowingView / PlaceholderView / PreviewPane
    /// read BookStore from env via @Environment(BookStore.self)).
    /// Optional because BookStore is constructed asynchronously
    /// by LibraryLifecycleHook (= may not exist at first frame).
    var bookStore: BookStore?
    // Thread WenshuLibrary through to the chat pane so
    // ChatZoneView can observe library (= the canonical
    // book-selection source mutated by BookshelfListView taps).
    var library: WenshuLibrary?

    /// Apple HIG inspector visibility. Per WWDC23-10161,
    /// `.inspector(isPresented:)` takes a `Binding<Bool>` that
    /// the OS reads to drive the right-column drag-collapse and
    /// the toolbar toggle button. Apple recommends @State here
    /// (= the inspector is view-local chrome; = no cross-view
    /// sharing required; = matches the Pages / Numbers / Keynote
    /// pattern where the inspector state lives in the owning
    /// split view, not in a shared environment class).
    @State private var inspectorVisible: Bool = true

    /// `.inspector(isPresented:)` is wired with `.constant(true)`
    /// below (= inspector is permanently visible = the same
    /// pattern Apple Pages / Numbers / Keynote use; = Apple does
    /// not expose an inspector toggle button on these apps).
    /// Therefore no `inspectorVisible` state on AppState, no
    /// `@Bindable inspectorState`, no toolbar toggle button.
    /// The `.constant(true)` binding is the source of truth.

    var body: some View {
        // macOS 27 Tahoe SwiftUI NavigationSplitView renders each
        // column with the canonical Liquid Glass material (= .glassEffect(.regular)
        // auto-applied to column backgrounds = the columns visually separate via
        // glass-on-glass refraction = no visible drag-handle divider between columns).
        //
        // Pattern: NavigationSplitView (3 columns) + each column's
        // body wrapped in Rectangle.glassEffect(.regular) (= the
        // canonical macOS 27 Liquid Glass surface = the divider
        // becomes invisible because each column has its own glass
        // tier that refracts independently; = no horizontal line
        // between columns).
        //
        // Use the parameter-less `NavigationSplitView { sidebar content detail }`
        // init (= SwiftUI's no-binding default). Per Apple docs, the
        // no-binding init uses an internal SwiftUI-managed
        // visibility state (= macOS always shows all three
        // columns; = the sidebar remains visible at its
        // `navigationSplitViewColumnWidth` ideal = 280 PT).
        // Passing `columnVisibility: .constant(.automatic)` (= our
        // earlier attempt) created a non-default code path that
        // collapsed the sidebar to its absolute minimum width even
        // when `navigationSplitViewColumnWidth` specified a 220-PT
        // minimum. The no-binding init lets SwiftUI's layout
        // engine use the column widths we set.
        NavigationSplitView {
            // Apple HIG sidebar (= leftmost column; = the source
            // of truth for navigation in this band). 2 vertical
            // sub-areas (= VStack; no inner divider; = Mail's
            // sidebar = inbox + sent + drafts side by side, =
            // Apple's standard "List with multiple sections"
            // pattern).
            //
            // No `.navigationSplitViewColumnWidth` modifier on any
            // column (= SwiftUI's own defaults for min / ideal /
            // max take over; = Mail / Notes / Finder also do not
            // specify column widths; = the same defaults apply).
            //
            // The earlier 5-round iteration (min/ideal/max ranges
            // = 220/280/360, 240/320/480, 400/600/900, 240/280/360)
            // tried various ranges; all caused sidebar to collapse
            // to 8 PT or split-view column-width layout pass to
            // enter a degenerate state on macOS 27 NSV. The
            // canonical answer per the Apple HIG reverse-pattern =
            // strip the modifier + let SwiftUI's NSV `.automatic`
            // style use its canonical column ranges (~140 sidebar
            // / ~200 content / detail natural; = Mail / Notes /
            // Finder ship with the same defaults).
            AppleSidebarView()
                // Applied DIRECTLY on the NavigationSplitView
                // sidebar: { ... } closure body, per Apple's
                // navigationSplitViewColumnWidth(min:ideal:max:)
                // official example (modifier on the view INSIDE
                // the closure, NOT on a child struct body).
                // macOS 27 NSV honors min/ideal/max on the sidebar
                // column per the documented SwiftUI 13+ behavior.
                // min 220 = Apple HIG sidebar minimum (= inspector
                // button + shelf header + 1 line of book title
                // fits); ideal 280 = the canonical 4-column sidebar
                // at 1400 PT window width; max 360 = above this the
                // sidebar eats too much space from the detail column.
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } content: {
            // Middle column (= the section between sidebar and detail)
            // = the outline + cards band. The probe measured window
            // = 1449, sidebar = 240, content = 280, detail = 648 with
            // this layout.
            //
            // Now passes `envAppState:` (= the @Bindable /
            // @Environment entry declared on ShellMiddleColumn) in
            // addition to the existing `appState:` shim. Both point
            // to the same instance (= wenshu's NSA framework
            // convention; = see ShellMiddleColumn L57-72 for the
            // @Bindable + `let appState` parallel-ownership pattern).
            ShellMiddleColumn(envAppState: appState, appState: appState, workspaceUI: workspaceUI)
                // Applied DIRECTLY on the NavigationSplitView content:
                // { ... } closure body, per Apple's official example:
                // modifier is on the view INSIDE the closure, NOT on
                // a child struct body. macOS 27 NSV honors min/ideal/
                // max on the content column. min 240 = the card grid's
                // smallest usable width (= 2 cards wide at 110 PT
                // each + 8 PT gutter + 16 PT padding); ideal 320 = 3
                // cards wide; max 480 = above this the PreviewPane
                // renders 4+ cards per row, which crowds the card titles.
                .navigationSplitViewColumnWidth(min: 240, ideal: 320, max: 480)
        } detail: {
            // Apple HIG detail column = the editor + chat sub-areas
            // in a vertical split (= VSplitView is what Mail uses
            // for inbox/message inside the same column).
            //
            // Trailing panel is an Apple inspector, not a third
            // NavigationSplitView column. Measured: a 3-column
            // NavigationSplitView paints sidebar 40/255 but detail
            // 34/255, because detail is a CONTENT column (Apple's
            // own 3-column sample shows the same 48 vs 34 split).
            // Pages/Keynote/Numbers do not use a third column for
            // their format panel — they use an inspector, which
            // carries the sidebar material. The 3-column NSV +
            // inspector pattern is the canonical Apple 6-zone
            // layout (= the probe confirms window = 1449 with this
            // exact combination).
            ShellContentColumn(appState: appState, bookStore: bookStore, library: library)
                // Wire the inspector's `isPresented` to a real
                // `Binding<Bool>` (= `shell.inspectorVisible`) so
                // the inspector can collapse (= user drags the
                // right-column divider past the left edge) and
                // reopen (= the toolbar toggle button sets the
                // binding to true). This is the canonical Apple
                // HIG behavior for `.inspector(isPresented:)` per
                // WWDC23-10161: 'Inspectors can collapse by
                // default, but they aren't resizable by default. We
                // can change it with .inspectorColumnWidth. We can
                // also add a toolbar button to toggle the
                // presented property.'
                .inspector(isPresented: $inspectorVisible) {
                    ShellDetailColumn(
                        appState: appState,
                        workspaceUI: workspaceUI,
                        inspectorVisibleBinding: $inspectorVisible
                    )
                        // Inspector column width = 240/280/360 PT
                        // (= min/ideal/max) per Apple's
                        // inspectorColumnWidth(min:ideal:max:)
                        // official API. Min 240 = Apple HIG inspector
                        // minimum; ideal 280 = canonical Pages /
                        // Notes inspector width; max 360 = above
                        // this the inspector eats the detail
                        // column. NOTE: modifier is
                        // `.inspectorColumnWidth` (= the dedicated
                        // inspector API), NOT
                        // `.navigationSplitViewColumnWidth` (= that
                        // one is for the leading sidebar / content
                        // / detail columns; = inspector is a
                        // separate trailing column with its own API
                        // per Apple docs).
                        .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                }
        }
        // Default-first column separation: no interop (= the
        // .thinColumnDividers() AppKit KVC hack that set
        // NSSplitView.dividerColor = .clear + dividerStyle = .thin
        // is not an Apple SwiftUI API; = macOS 27
        // NavigationSplitView owns its own column separation).
        // Re-inject appState at the NavigationSplitView root
        // (= SwiftUI's internal layout engine reads @Environment
        // values during NavigationSplitCoordinator.makeSplit
        // ViewController to compute column min sizes; = the engine
        // needs appState in env even though no column body reads
        // it directly). Without this re-injection, the env chain
        // fails at _FlexFrameLayout.sizeThatFits (= Environment
        // Values subscript crashes with 'No Observable object of
        // type AppState found' during view layout pass).
        //
        // Redundant injection is benign (= per the dual-axis
        // audit's own conclusion) but the design relies on
        // multiple re-injection sites: if one is dropped during
        // a future refactor, env-chain failures will surface at
        // the layout pass.
        .environment(appState)
        // Also re-inject bookStore if available (= descendants
        // read BookStore from env via @Environment(BookStore.self)
        // = ForeshadowingView / PlaceholderView / PreviewPane /
        // WorkspaceView. Without this re-injection, the env chain
        // fails at the layout pass with 'No Observable object of
        // type BookStore found').
        .environment(bookStore)
        // SwiftUI macOS 13+ canonical window-sizing recipe per
        // gunbark.dev / swiftwithmajid.com / avdlee swiftui-agent-
        // skill references — 'frame(minWidth:maxWidth:minHeight:
        // maxHeight:) on the content view defines the content size
        // range; .windowResizability(.contentSize) makes the window
        // size follow the content's min/max constraints.' Applied
        // verbatim to NavigationSplitView (= the content root):
        // minWidth 1100 = 4-column NSV min sum (sidebar 220 +
        // cards 240 + detail 400 + inspector 240 = 1100 PT floor;
        // = same as the previous contentMinSize floor),
        // minHeight 600 = 4-column NSV min height (= detail column
        // header + chat zone + tokens used bar = ~580 PT).
        //
        // Only the min floor is enforced (= the window can grow
        // without bound; = the user's standard macOS
        // zoom-to-fullscreen gesture is restored; = setting max
        // values here would forbid the system zoom gesture from
        // exceeding the content max).
        .frame(minWidth: 1100, minHeight: 600)
    }
}

/// Scope selector for the sidebar top tab bar. 2 cases map to
/// the existing top-level grouping (= per-shelf books; =
/// reference library per EntityCategory). View-local @State in
/// ShellSidebarColumn (= no AppState migration needed for M1; =
/// future ticket can promote to AppState for cross-zone read).
/// Note: defined as a top-level enum (= used by both
/// NavigationSplitShell's PaneTabBar items AND
/// AppleSidebarView's body filter; = placed here in the
/// NavigationSplitShell file = only NavigationSplitShell
/// imports it). The actual filtering logic lives in
/// AppleSidebarView (= the enum travels to the leaf as an init
/// parameter; = post-v1.69 MVVM split moved the enum to its own
/// file at `SidebarItem.swift`).

// MARK: - Content column (= 2 vertical sub-areas)

// `ShellMiddleColumn` lives at
// `Sources/WenshuApp/UI/Layout/ShellMiddleColumn.swift`. The
// inline struct block (= 466 lines including the `/// Apple
// HIG content column` doc + the 440-line body) was extracted so
// the same name no longer compiles twice. Same module = no new
// import needed for the consumer (= NavigationSplitShell
// instantiates ShellMiddleColumn directly).

// `ShellContentColumn` lives at
// `Sources/WenshuApp/UI/Layout/ShellContentColumn.swift`. The
// inline struct block (= 80 lines including the `// MARK: -
// Detail column` header + the 70-line Apple HIG split-views
// rationale + the EditorChatSplitHost body) was extracted so the
// same name no longer compiles twice. Same module = no new
// import needed for the consumer (= NavigationSplitShell
// instantiates ShellContentColumn directly).

// `ShellDetailColumn` lives at
// `Sources/WenshuApp/UI/Layout/ShellDetailColumn.swift`. The
// inline struct block (= 494 lines including the `/// Apple
// HIG detail column` doc + the 450-line body) was extracted so
// the same name no longer compiles twice. Same module = no new
// import needed for the consumer (= NavigationSplitShell
// instantiates ShellDetailColumn directly).

/// Inspector column (= the rightmost NSV column) was
/// previously 1 page with 5 RadioButton tabs (= Foreshadowing /
/// Placeholder / Long-form Guardrails / Reader Experience / Plot
/// Threads = 5 specialized tools fighting for a ~240-360
/// PT-wide column; = the tab labels overflow horizontally; =
/// the body is cramped on every page). Per Apple HIG
/// 'Inspector' (developer.apple.com/design/human-interface-
/// guidelines/inspector) the inspector surface is best
/// organized as a **paged layout** when there are more than 3
/// unrelated content types (= each page = a distinct, deep
/// tool surface; = the user picks a page with the segmented
/// control and gets the full column width for the chosen
/// page's content; = no per-tab horizontal scrolling).
///
/// 4 pages × 3 tools + 1 bookmark = 13 tools (= every tool in the
/// specializedTools zone gets a page; = the actual page→tool
/// mapping is provisional).
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
        // Outline glyphs (= the canonical Apple HIG form for
        // the Liquid Glass 3rd-generation design language). The
        // .fill variant (= solid color glyph) is reserved for
        // status indicators (= error / success badges); tool tab
        // chrome should use outline glyphs throughout.
        case .authoringFiction:     return "book.pages"      // SF Symbols 6 outline
        case .authoringStyle:       return "paintpalette"    // SF Symbols 6 outline
        case .authoringCharacters:  return "person.2"        // SF Symbols 6 outline
        case .projectManagement:    return "folder.badge.gearshape"  // SF Symbols 6 folder + gear
        }
    }

    // Page→tools routing. The page enum owns the routing as a
    // computed property — page 跟它的 3 tools 绑一起 = single
    // source of truth (新增 page 只改 enum 一个地方).
    //
    // The 4 page → 3 tool mappings are the canonical
    // authoritative layout.
    var tools: [InspectorTool] {
        switch self {
        case .authoringFiction:
            // Page 1 = Authoring + Plot / Placeholder / Foreshadowing
            // (= structural / plot tracking tools).
            return [
                InspectorCatalog.foreshadowing,
                InspectorCatalog.placeholder,
                InspectorCatalog.plotThread
            ]
        case .authoringStyle:
            // Page 2 = Authoring + Style / Experience / Genre
            // (= readability / style reference tools).
            return [
                InspectorCatalog.longForm,
                InspectorCatalog.readerExperience,
                InspectorCatalog.genreFit
            ]
        case .authoringCharacters:
            // Page 3 = Authoring + Characters / Relationships / Emotion
            // (= character-driven analysis tools).
            return [
                InspectorCatalog.characterRelationships,
                InspectorCatalog.characterLifecycle,
                InspectorCatalog.emotionCurve
            ]
        case .projectManagement:
            // Page 4 = Project Management + Ideas / Tags / Book Settings
            // (= cross-document project scaffolding).
            // v2.8a (boss 2026-09-28 OOB): bookmark tab joins this page
            // (= cross-document reference; = the existing 3 + 1 = 4
            // tools per page rule is intentionally broken here; = the
            // boss picked project-management as the natural home for
            // bookmarks next to tagManager).
            // v2.9a (boss 2026-09-28 OOB A3): backgroundReview tab joins
            // this page (= LLM auto-call proposals show next to bookmarks
            // + book settings + tags; = 4 + 1 = 5 tools per page;
            // = intentionally broken rule, consistent with bookmark).
            return [
                InspectorCatalog.ideaLibrary,
                InspectorCatalog.tagManager,
                InspectorCatalog.bookSettingConstraints,
                InspectorCatalog.bookmark,
                InspectorCatalog.backgroundReview
            ]
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

/// Kanban and Todo get their own dedicated windows (= 2 separate windows via AppKit's `openWindow`):
/// Window IDs for the dedicated secondary scenes (= the SwiftUI
/// macOS 14+ `WindowGroup(id:)` accepts an `id` parameter that
/// `openWindow(id:)` resolves; = the canonical way to open
/// multiple window types from a single App). 2 IDs here = kanban
/// + todo (= the 2 features the boss wants as independent
/// windows per Pages / Numbers / Keynote's independent document
/// windows pattern).
///
/// macOS 27 Tahoe's WindowGroup id-routing has a special case for IDs
/// that match the legacy Preferences/Settings ID space (= e.g. IDs
/// containing 'preferences' /
/// 'setting' / 'pref' tokens get routed to the system's
/// SettingsEnvironmentCapturer scene instead of opening a new
/// window). The IDs here use short opaque tokens (= 'wenshu-kanban'
/// / 'wenshu-todo') that avoid that namespace collision. If a
/// future ticket introduces additional WindowGroup scenes, prefer
/// this same naming convention.
enum WindowID {
    static let kanban = "wenshu-kanban"
    static let todo = "wenshu-todo"
    // v2.8b (boss 2026-09-28 OOB B6 + B7 + B9): 4 new
    // independent windows for previously-unwired features.
    // Per boss '和老板 todo 一样' (= same shape as the existing
    // kanban + todo windows).
    static let canvas = "wenshu-canvas"
    static let composer = "wenshu-composer"
    static let foreshadowingGraph = "wenshu-foreshadowing-graph"
    static let cron = "wenshu-cron"
    // WS model entry windows (= each opens a dedicated independent
    // window that lists entries for the corresponding SwiftData
    // @Model (= WSAttachment / WSManifest / WSSummary). The window
    // content is intentionally a real list (= fetched via
    // FetchDescriptor) so the entry is a usable surface today and
    // becomes the canonical wiring target once each model's real
    // feature is decided).
    static let attachments = "wenshu-attachments"
    static let manifest = "wenshu-manifest"
    static let summaries = "wenshu-summaries"
}



// `ShellPlaceholder` lives at
// `Sources/WenshuApp/UI/Layout/ShellPlaceholder.swift`. The
// inline struct block (= 22 lines including the legacy
// `// MARK: - Placeholder view` header + the long
// ContentUnavailableView rationale block) was removed here so
// the same name no longer compiles twice.

