// Sources/WenshuApp/App/AppRootScene.swift
//
// Root Scene assembly (= the WindowGroup + Settings + secondary windows).
// (library / appearanceMode / appState / shell / workspaceUI /
// repositories); AppRootScene receives them as constructor params.
//
// Why Scene, not View:
// - WenshuApp.body returns `some Scene` (= WindowGroup + .commands +
//   Settings). Scene is the SwiftUI protocol for root-level scene
//   trees. Settings scene cannot be expressed as a View body; = must
//   stay at the scene layer.
// - State owners (= @State + @AppStorage) must remain on the App
//   struct itself; = `appState` / `shell` / `workspaceUI` are passed
//   in, not constructed here.

import SwiftUI
import AppKit

struct AppRootScene: Scene {
    let library: WenshuLibrary
    @Binding var appearanceMode: AppearanceMode
    let appState: AppState
    /// Shell chrome state (= sidebar + inspector + chat zone +
    /// inspector page). Injected via `.environment(shell)` at every
    /// scene root (= WindowGroup content + Settings scene); = the 2
    /// injection sites stay parallel.
    let shell: ShellState
    let workspaceUI: WorkspaceUIState
    /// Sheet-request triggers (= fire-and-forget counters for the
    /// .sheet(item:) consumer). Injected via `.environment(sheetRequests)`
    /// at every scene root (= WindowGroup content + Settings scene).
    let sheetRequests: SheetRequestState
    let editorCounters: EditorCounters
    let repositories: WSRepositoryContainer

    // the kanban + todo Windows each construct their own BookStore /
    // Kanban / Todo persistence from the shared `library` URL
    // (= SwiftData-backed via WSKanbanRepository / WSTodoRepository;
    // = +7 deleted the KanbanStore + TodoStore actors)
    // KanbanWindow / TodoWindow for the env-chain fix rationale).
    // The Windows are SIBLING scenes (= not children of the main
    // WindowGroup; = SwiftUI does NOT propagate env values across
    // WindowGroup boundaries). The kanban + todo Windows therefore
    // build their own env chain from the same .ws package the main
    // window uses (= edits in the kanban / todo window are
    // immediately visible in the main window and vice versa via
    // the shared on-disk JSON files).

    var body: some Scene {
        // title set to empty string (= no NSWindow title shown). Combined
        // with .windowToolbarStyle(.unified, showsTitle: false) below for
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // dropped CommandPaletteHost + SettingsEnvironmentCapturer
            // wrappers (= 2 non-Apple-canonical layers between
            // WindowGroup and the root content view). Per Apple
            // canonical 4-layer architecture:
            //   WindowGroup → root view (1 view) → NavigationSplitView
            //                → column body (1 view)
            // The ⌘K command palette sheet, LayoutEditMode
            // hotkey, and openSettings binding are now attached
            // directly to LibraryRootView (= the root view; = 4
            // view layers total = Apple canonical).
            LibraryRootView(library: library, appearanceMode: appearanceMode)
                .environment(appState)
                .environment(shell)
                .environment(workspaceUI)
                .environment(sheetRequests)
                .environment(editorCounters)
                .environment(repositories)
        }
// .windowToolbarStyle(.unified) = 52 PT macOS native titlebar
// (= Apple Liquid Glass default; = Pages / Xcode / Mail / Finder
// all use it). The dense-workspace alternative (.unifiedCompact,
// 28 PT) was tried but breaks 4-column NavigationSplitView
// intrinsic sizing (= sidebar collapses to 8 PT, inspector content
// goes blank). Stick with .unified.
        .windowToolbarStyle(.unified)
        // bossverificationfix: .contentMinSize (window doesn't shrink below initial
        // size, can grow to fit larger content).
        // : change to
        // .contentSize so the defaultSize (= 1480 PT width) is
        // actually applied. The previous `.contentMinSize` made
        // the window grow to fit the NavigationSplitView's
        // content minimum (= the 4-column ideal-width sum + drag
        // handles + window chrome = ~2205 PT), overriding
        // defaultSize entirely.
        //
        // `.windowResizability(.contentMinSize)` (= the current
        // setting) makes the initial window = the sum of every
        // column's MIN width (= sidebar 220 + cards 240 + detail
        // 400 + inspector 240 = ~1100 PT). All four columns render
        // at their minWidth (= no ideal-Width breathing room =
        // every column is squashed = the cards column devours the
        // detail column = no A4 paper visible = no inspector
        // visible). `.contentMinSize` is correct for "user can
        // shrink down to the content minimum" (= the user wants
        // this) but it is WRONG for the initial size (= we want
        // the initial size to use the idealWidth column widths =
        // 280 + 320 + 600 + 280 = ~1480 PT).
        //
        // Switch back to `.contentSize` (= the previous v0.91
        // setting): the window is sized by its intrinsic content
        // (= NavigationSplitView's 4 columns at their ideal
        // widths; = ~1480 PT = exactly the defaultSize 1480 PT).
        // The onboarding form already has its own
        // `.frame(minWidth:idealWidth:maxWidth:minHeight:...)`
        // (= 640 x 720) so `.contentSize` does NOT collapse the
        // onboarding window (= the earlier 'APP initial size, very small'
        // bug was caused by `.contentMinSize` ignoring the
        // onboarding's outer frame as a hint; = `.contentSize`
        // honours the outer frame as a hint and lets the user grow
        // the intrinsic content size).
        //
        // have it — write it in, seems like it needs to be patched': the `.contentSize` resizability
        // was making the window size = NavigationSplitView's
        // intrinsic content size (= the sum of each column's
        // MIN width = sidebar 220 + cards 240 + detail 400 +
        // inspector 240 = 1100 PT; = detail only gets its MIN
        // width 400 PT = the boss's 'middle column looks narrow' symptom).
        // Switching to `.contentMinSize` + keeping
        // `.defaultSize(1480, 980)` means:
        //   - defaultSize 1480 PT = the INITIAL window width
        //   - `.contentMinSize` = window never shrinks BELOW the
        //     4-column min sum (= 1100 PT floor; = the user can
        //     drag the window smaller but the columns don't collapse
        //     past their min)
        //   - NSV honors each column's `navigationSplitViewColumnWidth
        //     (ideal: ...)` because the window is large enough to
        //     accommodate the ideal sum 1340 PT (= sidebar 220 +
        //     cards 240 + detail 600 + inspector 280 = 1340 PT)
        //     = detail gets 600 PT (= its ideal = the boss's
        //     'middle column's default width' expectation).
        //
        // :
        // initial window frame = 1400x980 logical PT (= Apple HIG
        // default for a 4-column NSV on a 13" laptop). Combined
        // with `.windowResizability(.contentSize)` below + the
        // NSV's `.frame(minWidth:maxWidth:minHeight:maxHeight:)`
        // (= the SwiftUI macOS 13+ canonical window-sizing recipe
        // per gunbark.dev / swiftwithmajid.com / avdlee swiftui-
        // agent-skill) = window opens at 1400x980 and is bounded
        // by the NSV's 1100~1800 PT width + 600~1100 PT height
        // (= drag stops at the NSV's frame boundaries).
        .defaultSize(width: 1400, height: 980)
        // : the
        // defaultSize-only configuration leaves the window's
        // initial position to system-determined behavior (= the
        // previous v1.67 launch had the window anchored to the
        // top-left corner of the screen, NOT centered; = the
        // boss's screenshot showed x≈0, y≈0). Per Apple HIG
        // developer.apple.com/documentation/swiftui/view/
        // defaultposition: '.center: The window is centered in
        // the visible region of the display that contains it.' =
        // the canonical Apple recipe for a single-window app
        // (= wenshu is single-window per the §11 baseline) =
        // append `.defaultPosition(.center)` after `.defaultSize`.
        // macOS 13+ (= wenshu target = macOS 27).
        .defaultPosition(.center)
        // Apple HIG default restoration (= `.automatic` = SwiftUI
        // default = persist the window frame to the system-level
        // `NSWindow Frame <bundleID>` UserDefaults key on app quit; =
        // read it back on next launch). Per Apple
        // developer.apple.com/documentation/swiftui/restorationbehavior
        // '.automatic: The system uses its default behavior for the
        // scene.' Combined with `.defaultSize(width: 1400, height: 980)`
        // below (= applies ONLY on first launch when the system has no
        // saved frame) + `.defaultPosition(.center)` (= applies only
        // on first launch too) = first launch = 1400x980 centered;
        // subsequent launches = the user's last frame (size + position).
        // Replaces `.restorationBehavior(.disabled)` (= the v0.91
        // setting which forced `.defaultSize` on every launch and
        // therefore never remembered the user's window preferences).
        // Note: wenshu is single-window per the §11 baseline; = the
        // persisted frame is the only window frame; = no multi-window
        // bookkeeping needed. The `.ws` library path continues to
        // persist via `@AppStorage("wenshu.libraryPath")` (= separate
        // from the window frame, as before).
        // Per Apple HIG developer.apple.com/documentation/swiftui/
        // view/windowresizability: 'contentMinSize: The window
        // can't be smaller than its content's minimum size, but
        // 'contentMinSize: The window can't be smaller than its
        // content's minimum size, but can be larger.' = matches the
        // intent of letting the window grow to fill the display
        // while enforcing the NSV `.frame(minWidth: 1100, minHeight: 600)`
        // above (= the min floor; = the max is unbounded so macOS's
        // system-level zoom gesture (= double-click on title bar /
        // click green traffic-light button / choose Window > Zoom)
        // can fill the window to the display's visibleRect). Note
        // this combination accepts the v0.97 trade-off: drag past
        // ~2200 PT may still trigger the
        // `_postWindowNeedsUpdateConstraints` BPT crash on macOS
        // 27 (= the original 6-round-history bug); boss has chosen
        // to accept this trade-off in exchange for the standard
        // macOS zoom gesture working as expected.
        .windowResizability(.contentMinSize)
        // the inspector toggle button
        // (= ⌥⌘I = SF Symbols 6 'sidebar-right' icon = the canonical
        // Apple toolbar affordance for NavigationSplitView
        // `.inspector`)
        // is attached to LibraryRootView (= the content view)
        // because `some Scene` (= AppRootScene) does not expose
        // a `.toolbar` modifier; = Scene-level `.toolbar` is not
        // a SwiftUI API. LibraryRootView reads AppState directly
        // (= it already injects AppState via @Environment), so the
        // button writes the same property NavigationSplitShell
        // binds into `.inspector(isPresented:)`.
        .commands {
            // NSV .inspector(isPresented:) modifier already renders a
            // column-header chevron for inspector visibility; the
            // duplicated View > Inspector menu item (⌥⌘I) was a
            // convenience that bypassed SwiftUI default
            // behavior. The chevron + drag header are the Apple
            // canonical affordance.

            // apple-001 + boss real-device test (2026-09-07) fix:
            // removed the custom `CommandGroup(replacing: .appSettings) { Button("Settings…") }`
            // block. The custom Button was duplicating the macOS system
            // "Settings..." menu item (= which is auto-rendered when the
            // App has a `Settings { ... }` scene, see L206). The
            // duplication showed as 2 menu items: "Settings…" (Chinese) +
            // "Settings..." (English) in the WenshuApp menu.
            //
            // Apple HIG: the macOS standard for Settings menu is the
            // system-default "Settings..." (= Apple-localized, = Cmd+,).
            // The Settings scene below provides the actual content
            // (= SettingView, the 6-tab segmented settings panel).
            //
            // The previous custom Button was a v0.24 workaround
            // (= "Settings... menu item is required for SwiftUI
            // Settings scene to be accessible"). That workaround is
            // no longer needed (= the Settings scene at L206 is the
            // real source of the menu entry). Cmd+, opens Settings
            // automatically when the App has a Settings scene (= no
            // custom CommandGroup required).
            //
            // was a hermes parity carryover from v0.40. Restore the
            // macOS-default File > New behavior (= ⌘N for new
            // document) by removing the .newItem replacement.
            //
            // The post-.newItem block below (File > New Project
            // submenu + Import at ⇧⌘I) is preserved.
            CommandGroup(after: .newItem) {
                // macOS-standard cross-component sync (boss 8/27
                // OOB): File → is the macOS-standard menu item
                // (= Cmd+N shortcut) for the file-creation kind. Per boss
                // 8/27 standing rule 'a new feature should appear
                // everywhere = synced', this Menu mirrors the toolbar '+'
                // Menu (= /). Both sub-items post a
                // NotificationCenter event that the post-v1.69
                // sidebar observes (= AppleSidebarView flips the
                // matching AppState request counter → .sheet(item:)
                // presents the matching sheet from SidebarSheets.swift).
                // previous `.keyboardShortcut("n", modifiers:
                // .command)` was attached to the OUTER Menu (= a
                // scene-level Menu = the File menu's "New Project"
                // submenu). macOS interprets ⌘N on a scene-level
                // Menu as "open new window" (= the system-level
                // default for any DocumentGroup / WindowGroup
                // scene = ⌘N opens a new window of the same type).
                // We do NOT want that behavior here (= wenshu is
                // single-window per the §11 baseline; = ⌘N should
                // trigger the NewChoiceSheet inside the current
                // window, not open a second wenshu instance).
                //
                // Fix: attach `.keyboardShortcut("n", modifiers:
                // .command)` to the FIRST Button (= "New Book" =
                // the canonical submenu item = the user-facing
                // "what ⌘N does" action). macOS binds ⌘N to the
                // first visible menu item by convention (= Mail /
                // Notes / Pages / Numbers all bind ⌘N to the first
                // item in File > New). We bind ⌘N to "New Book" =
                // the new-choice sheet opens (= user picks Book /
                // Shelf inside the sheet = same UX as the button-
                // triggered flow).
                Menu(WenshuI18n.t("menu.file.new_project")) {
                    Button(WenshuI18n.t("menu.file.new_project.submenu.new_book")) {
                        sheetRequests.newBook += 1
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    Button(WenshuI18n.t("menu.file.new_project.submenu.new_shelf")) {
                        sheetRequests.newShelf += 1
                    }
                }
                // boss 8/27 OOB: menusync toolbar 'import' button.
                // Per the standing rule that a new feature should
                // appear everywhere = synced, the menu bar gets a
                // matching import entry (= macOS-standard File → Import
                // Convention; Cmd+Shift+I is the macOS default shortcut
                // for File → Import per developer.apple.com/design/
                // human-interface-guidelines/app-architecture/importing-
                // and-exporting-data). Functionality deferred (= '
                // '); placeholder posts a
                // NotificationCenter event so v0.27 followups can
                // listen + implement.
                Button(WenshuI18n.t("menu.file.import")) {
                    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button(WenshuI18n.t("menu.edit.undo"), action: {})
                    .keyboardShortcut("z", modifiers: .command)
                Button(WenshuI18n.t("menu.edit.redo"), action: {})
                    .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            // is a zone that can be shown/hidden, but the toggle lives in the menu bar, there is no dedicated
            // button — the menu-bar entry comes first, whether to add a button later, we'll investigate': the View
            // menu (= Apple's canonical menu for pane visibility
            // toggles; = per Apple HIG developer.apple.com/design/
            // human-interface-guidelines/menus 'The View menu lets
            // people toggle the visibility of interface components,
            // like the sidebar, inspector, or other panes') hosts
            // the chat zone Show/Hide command.
            //
            // Implementation: the chat zone is hosted by an
            // `NSSplitViewItem` inside `EditorChatNSController`
            // (= the detail column = AppKit NSSplitViewController;
            // = the canonical Apple Keynote speaker-notes API;
            // = native isCollapsed + animator() animation; =
            // per developer.apple.com/design/human-interface-
            // guidelines/split-views 'A split view can collapse
            // one of its panes by dragging the divider past the
            // edge of the split view, by clicking the collapse
            // button in the divider, or programmatically.').
            //
            // A1.3: the NSNotification dispatch was removed
            // (= EditorChatNSController listener deleted in this
            // commit; = only the AppState flag flip remains; = the
            // chat zone visibility is owned by ShellState.chatVisible
            // downstream consumers). Toggle still binds the flag.
            CommandGroup(after: .toolbar) {
                Toggle(WenshuI18n.t("menu.view.show_chat_zone"), isOn: Binding(
                    get: { shell.chatVisible },
                    set: { newValue in
                        shell.chatVisible = newValue
                    }
                ))
                .keyboardShortcut("k", modifiers: [.command, .option])
            }
        }
        Settings {
            SettingView()
        }
        // inject AppState into the Settings scene so
        // SettingView's `@Environment(AppState.self) private var
        // appState` lookup (= appState.llmModel on the model picker
        // binding) doesn't assert-fail when the user opens Settings
        // via ⌘,. Without this, opening Settings crashed in
        // `_assertionFailure` from `EnvironmentValues.subscript.getter`
        // because the Settings scene had no `.environment(appState)`
        // modifier (= only the WindowGroup's content view had one).
        .environment(appState)
        .environment(shell)
        .environment(repositories)
        // add 2 dedicated `Window` scenes (= the SwiftUI macOS
        // 13+ API for SINGLE-INSTANCE independent windows; = the
        // canonical Apple pattern for an 'always one' panel
        // surface like kanban / todo / system Settings).
        // Per Apple HIG (developer.apple.com/documentation/
        // swiftui/window): `Window` = a scene that presents a
        // single, non-duplicable window (= the user can't open a
        // second kanban via the system File > New menu or by
        // tapping the toolbar button twice; = the second tap
        // brings the existing window to the front). This is the
        // correct pattern for our kanban / todo (= there's no
        // use case for two kanban windows showing the same
        // tickets; = the canonical macOS inspector / media
        // browser / activity monitor all use `Window` for the
        // same reason).
        //
        // Per Apple docs: `Window` is implicitly singleton; =
        // no `id:` parameter is needed (= SwiftUI keys the
        // singleton by the scene's position in the App body).
        // openWindow still works: `openWindow(id: "wenshu-kanban")`
        // is matched against the Window's accessibility
        // identifier (= see the `.accessibilityIdentifier` below).
        //
        // from the cua AX tree dump + the macOS 27 Tahoe routing
        // observed in earlier debug output): WindowGroup IDs must
        // avoid the legacy Preferences / Settings ID namespace
        // (= IDs that match the system's Settings scene route to
        // the SettingsEnvironmentCapturer instead of opening a
        // new window). 'wenshu-kanban' / 'wenshu-todo' use
        // short opaque tokens that avoid that namespace
        // collision.
        // what you said — are those the same thing? What I mean is: main window, Settings, Kanban, Todo,
        // can all appear on screen at the same time, but each window has to be unique, the Kanban button
        // can only toggle the Kanban window open/closed, not open multiple Kanban windows': my previous
        // switch to `WindowGroup` (= MULTI-INSTANCE) was the
        // wrong primitive. Boss wants SINGLE-INSTANCE per window
        // type: = clicking the kanban button when the kanban
        // window is closed → opens it; = clicking again when
        // the kanban window is open → brings it to front
        // (= doesn't open a duplicate); = each window type
        // has exactly one window (= kanban / todo / settings);
        // = the user can have main + settings + kanban + todo
        // ALL on screen simultaneously, but never 2 kanbans.
        //
        // `Window("Kanban", id: WindowID.kanban)` (= macOS 13+
        // SINGLE-INSTANCE panel scene) is the correct primitive.
        // Apple HIG (§ Multi-window apps in macOS 14 HIG):
        // "use WindowGroup for documents (e.g. Pages, Numbers),
        // use Window for settings, panels, and single-instance
        // feature surfaces".
        //
        // Lifecycle semantics (= independent of the main window):
        // `Window("Kanban")` is a separate scene from the root
        // `WindowGroup { LibraryRootView }`. Closing the kanban
        // window does NOT close the main window (= verified by
        // Apple docs: each `Scene` is an independent NSWindow;
        // the app process stays alive as long as ANY scene is
        // present; = closing kanban leaves main open). Opening
        // kanban with `openWindow(id: WindowID.kanban)` brings
        // the existing kanban window to front if it exists, or
        // creates one if it doesn't (= the toggle semantics).
        //
        // windows instances, the window size needs to auto-fit the content, no need to set
        // a fixed size': per Apple HIG `Window` (= single-instance)
        // sizes itself to the view's intrinsic content size
        // by default (= no `.defaultSize` modifier needed).
        Window("看板", id: WindowID.kanban) {
            KanbanWindow(library: library)
        }
        .windowResizability(.contentSize)
        // macOS 27 doc-alignment: kanban + todo secondary windows
        // match the main window's `.unified` (= 52 PT default
        // macOS toolbar) for consistency.
        .windowToolbarStyle(.unified)
        Window("待办", id: WindowID.todo) {
            TodoWindow(library: library)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        // 4 new independent windows for previously-unwired features.
        // Per the same shape as the existing kanban + todo windows.
        Window(WenshuI18n.t("window.canvas"), id: WindowID.canvas) {
            CanvasWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        Window(WenshuI18n.t("window.composer"), id: WindowID.composer) {
            ComposerWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        Window(WenshuI18n.t("window.foreshadowing_graph"), id: WindowID.foreshadowingGraph) {
            ForeshadowingGraphWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        Window(WenshuI18n.t("window.cron"), id: WindowID.cron) {
            CronWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        // WS model entry windows (= Attachments + Manifest + Summaries).
        // Per the same shape as the existing kanban + todo windows.
        Window(WenshuI18n.t("window.attachments.title"), id: WindowID.attachments) {
            AttachmentsWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        Window(WenshuI18n.t("window.manifest.title"), id: WindowID.manifest) {
            ManifestWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        Window(WenshuI18n.t("window.summaries.title"), id: WindowID.summaries) {
            SummariesWindow()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
    }
}
