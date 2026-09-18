// AppRootScene.swift · Wenshu · v0.40 apple-001 phase 1 Q1 slice 2
//
// Q1 boss split App.swift. After slice 1 (= extract WenshuAppDelegate
// to App/WenshuAppDelegate.swift), the next slice pulls the Scene
// assembly out of `WenshuApp.body` so the @main struct itself becomes
// a minimal composition root (= declares the state owners + delegates
// scene composition to AppRootScene).
//
// Why a Scene struct, not a View struct:
// WenshuApp.body returns `some Scene` (= WindowGroup + .commands +
// Settings). Scene is a SwiftUI protocol that hosts the root-level
// scene tree. The composition logic = `WindowGroup { ... }
// .windowToolbarStyle(.unified) ... .commands { ... }` then a
// sibling `Settings { ... }` scene. Both pieces are Scene-level
// concerns (= window chrome, command palette bindings, settings
// environment injection) and must stay at the scene layer; lifting
// them into a View would be a downgrade (= Settings scene cannot be
// expressed as a View body).
//
// Why state stays on WenshuApp (= not AppRootScene):
// @State + @AppStorage require an @DynamicMemberLookup storage
// instance (= the App struct itself). The state owners
// (library / appearanceMode / appState) must remain on WenshuApp;
// AppRootScene receives them as constructor parameters. The
// `@AppStorage("appearanceMode")` binding is forwarded as
// `@Binding var appearanceMode` to AppRootScene so the
// SettingsEnvironmentCapturer inside WindowGroup can still observe
// the same single source of truth.

import SwiftUI
import AppKit

struct AppRootScene: Scene {
    let library: WenshuLibrary
    @Binding var appearanceMode: AppearanceMode
    let appState: AppState

    // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo get their own dedicated windows':
    // the kanban + todo Windows each construct their own BookStore /
    // Kanban / Todo persistence from the shared `library` URL
    // (= SwiftData-backed via WSKanbanRepository / WSTodoRepository;
    // = Phase 5 tickets 6+7 deleted the KanbanStore + TodoStore actors)
    // KanbanWindow / TodoWindow for the env-chain fix rationale).
    // The Windows are SIBLING scenes (= not children of the main
    // WindowGroup; = SwiftUI does NOT propagate env values across
    // WindowGroup boundaries). The kanban + todo Windows therefore
    // build their own env chain from the same .ws package the main
    // window uses (= edits in the kanban / todo window are
    // immediately visible in the main window and vice versa via
    // the shared on-disk JSON files).

    var body: some Scene {
        // v0.24 fix (Boss 8/25 17th OOB 'hide Wenshu title'): WindowGroup
        // title set to empty string (= no NSWindow title shown). Combined
        // with .windowToolbarStyle(.unified, showsTitle: false) below for
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // v0.44 M8.1: dropped CommandPaletteHost + SettingsEnvironmentCapturer
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
        }
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'persistence after opening a .ws,
        // no idea why, but it disappears, the last N times I had to manually re-open the .ws library every time':
        // the previous `WindowGroup` (= no `restorationBehavior`)
        // inherited the macOS system-wide state-restoration setting.
        // On this machine (= state restoration ON), the system
        // restored the previously-saved window frame (= 1134 PT
        // wide, captured from an earlier launch when the window
        // was smaller than the current `.defaultSize(1480, 980)`).
        // The restored frame overrode `.defaultSize`, so the
        // window opened at 1134 PT (= the saved frame), which is
        // narrower than the 4-column `ideal` sum (1340 PT) = NSV
        // had to compress each column from `ideal` down to ~`min`,
        // making the sidebar + cards + detail + inspector all
        // visibly squished. Worse: the saved frame did NOT match
        // the saved `.ws` library path on disk, so on every
        // subsequent launch the user saw a too-narrow window AND
        // had to manually re-open the `.ws` (= the boss's 'persistence
        // disappears' symptom = the saved frame and the saved library
        // path drifted apart over time).
        //
        // Fix: `.restorationBehavior(.disabled)` (= the canonical
        // Apple HIG way to opt a window OUT of state restoration;
        // = per developer.apple.com/documentation/swiftui/
        // restorationbehavior 'Use disabled for windows that should
        // not reopen on next launch, such as About panels,
        // transient support/info windows, or first-run welcome
        // surfaces.' = wenshu is a single-window app where the
        // `.defaultSize(1480, 980)` IS the desired initial state
        // every launch; = the saved frame is never the correct
        // frame; = opt out of restoration so `.defaultSize` always
        // wins).
        //
        // Note: we DO still persist the `.ws` library path via
        // `@AppStorage("wenshu.libraryPath")` (= UserDefaults) and
        // the editor's split-position via
        // `NSSplitView.autosaveName` (= AppKit-side, separate from
        // the window frame). Only the WINDOW FRAME restoration is
        // disabled (= the right choice for a single-window app
        // with a fixed initial size).
        .restorationBehavior(.disabled)
        // Boss 8/24 feedback: 'use the 52 PT one'. Apple SwiftUI macOS 14+ windowToolbarStyle
        // options: .automatic, .unified (52 PT), .unifiedCompact (28 PT), .expanded.
        // v0.24 fix (Boss 8/25 28th OOB 'use default size' + Apple docs):
        // use .unified (52 PT) = macOS default toolbar style. Per Apple
        // developer.apple.com/documentation/SwiftUI/WindowToolbarStyle,
        // .unified is the default style (52 PT). .unifiedCompact is
        // COMPACT (= smaller, NOT default). Boss spec 'default size' = .unified.
        // v0.28 followup Boss UX round 12 (Boss 2026-08-29 OOB ',
        // apple, 52 title,
        // button, remove, Liquid Glass'):
        // = adopt Apple Liquid Glass design language fully per
        // developer.apple.com/documentation/technologyoverviews/
        // liquid-glass. Use .unified (= 52 PT default macOS chrome)
        // = the full Liquid Glass titlebar experience (= traffic lights
        // + grouped toolbar items in 1 unified capsule = the macOS 26
        // Tahoe canonical look that Pages / Xcode / Mail / Finder all
        // use). Remove .toolbarBackground(.clear) (= let the default
        // Liquid Glass material render). 100% native macOS look.
        //
        // Final titlebar = 1 macOS native .unified 52 PT titlebar
        // (= Apple standard = Liquid Glass = 1 unified capsule
        // containing 8 toolbar items + traffic lights). No custom
        // chrome above or below (= fully Apple-native = ' apple
        // ' per Boss spec).
        // v0.93 boss 2026-09-10 OOB 'NSV probe was working fine before':
        // the probe (/tmp/wenshu_full/Full.swift, = the
        // 2026-09-10 morning NSV test) used
        // `.windowToolbarStyle(.unifiedCompact)` (= 28 PT compact
        // chrome) and showed all 4 columns at their Apple HIG
        // ideal widths. Switching to `.unified` (= 52 PT default
        // chrome) on the wenshu shell broke columnWidth (=
        // sidebar collapsed to 8 PT, inspector content went
        // blank). The 52-PT titlebar reserves more vertical
        // space at the top of the window, which apparently
        // changes NavigationSplitView's intrinsic-content-size
        // calculation (= the 4-column minimum widens
        // disproportionately). Per Apple docs, `.unifiedCompact`
        // is the recommended style for dense workspace apps
        // (= Mail / Notes / Finder all use it = their toolbars
        // do not steal vertical space from the work area). Match
        // the probe's style.
        // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
        // audit ticket 3 + 4): switch from
        // `.windowToolbarStyle(.unified)` (= 52 PT titlebar) to
        // `.windowToolbarStyle(.unifiedCompact)` (= 28 PT compact
        // toolbar) per the v0.93 boss 9/10 OOB 'NSV probe was
        // working fine before' (= the probe used .unifiedCompact
        // and showed all 4 columns at Apple HIG ideal widths).
        // Per Apple docs, `.unifiedCompact` is the recommended
        // style for dense workspace apps (= Mail / Notes /
        // Finder all use it = their toolbars do not steal
        // vertical space from the work area). The previous
        // 52-PT titlebar reserves more vertical space at the
        // top of the window, which pushes NavigationSplitView's
        // intrinsic-content-size calculation past the 4-column
        // minimum widening disproportionately. Match the
        // probe's style.
        // v0.96 boss 2026-09-10 OOB 'NSV probe was working fine before': the
        // probe (/tmp/wenshu_full/Full.swift) had no
        // `.defaultSize(width:height:)` (= SwiftUI used the
        // window's natural default size = ~1429 PT). With no
        // explicit defaultSize, NavigationSplitView's auto
        // layout takes over (= columns get their canonical
        // SwiftUI default widths: sidebar ~140, content ~200,
        // detail = remaining). Adding `defaultSize(1480, 980)`
        // (= earlier boss OOB) and `.unified` (= 52 PT titlebar)
        // seems to push NavigationSplitView into a degenerate
        // layout pass that collapses the sidebar to ~8 PT and
        // ignores every `navigationSplitViewColumnWidth`
        // modifier. Comment out defaultSize to restore SwiftUI's
        // default window sizing (= matches the working probe).
        // v0.101 boss 2026-09-10 OOB 'set each column to Apple's recommended parameters
        // — min/ideal/max': re-enable `defaultSize(1480, 980)`
        // (= Apple HIG ideal-sum for sidebar 280 + content 320 +
        // detail 600 + inspector 280). With the toolbar style
        // now `.unifiedCompact` (= matches probe) + 4 columns
        // each declaring their columnWidth ranges, NSV now
        // respects the defaultSize (= the previous collapse was
        // caused by defaultSize + .unified pushing NSV into a
        // degenerate layout; that combo is no longer in effect).
        // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
        // audit ticket 3): strip `.defaultSize(width:height:)`
        // (= per the v0.95/v0.97 boss OOB "NSV probe was working
        // fine before" = the probe (/tmp/wenshu_full/Full.swift)
        // had no `.defaultSize` + `.unifiedCompact` (= 28 PT) =
        // all 4 columns at Apple HIG ideal widths. Adding
        // `.defaultSize(1480, 980)` + `.unified` (= 52 PT titlebar)
        // pushes NavigationSplitView into a degenerate layout
        // pass that collapses the sidebar to ~8 PT and ignores
        // every `navigationSplitViewColumnWidth` modifier.
        // The canonical answer per
        // wenshu-visual-alignment/SKILL.md reverse-pattern =
        // strip `.defaultSize` + let SwiftUI's window auto-size
        // from NavigationSplitView intrinsic content.
        //
        // See .scratch/2026-09-18-macos27-doc-align/audit.md
        // ticket 3 for the canonical rationale + v0.95/v0.97/v0.101
        // iteration history (= 5 rounds trying to make defaultSize
        // + columnWidth work; all 5 failed; the working state was
        // "no defaultSize + .unifiedCompact + no columnWidth").
        // v1.77 boss 2026-09-18 'toolbar was 52 PT, change back':
        // restored .windowToolbarStyle(.unified) (= 52 PT default
        // macOS toolbar = the size boss originally approved; =
        // Apple docs developer.apple.com/documentation/swiftui/
        // view/windowtoolbarstyle: '.unified is the canonical
        // macOS default toolbar style (= 52 PT)').
        .windowToolbarStyle(.unified)
        // v0.24 bossverificationfix: .contentMinSize (window doesn't shrink below initial
        // size, can grow to fit larger content).
        // v0.91 boss 2026-09-10 OOB '1480 is also OK': change to
        // .contentSize so the defaultSize (= 1480 PT width) is
        // actually applied. The previous `.contentMinSize` made
        // the window grow to fit the NavigationSplitView's
        // content minimum (= the 4-column ideal-width sum + drag
        // handles + window chrome = ~2205 PT), overriding
        // defaultSize entirely.
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'compute each column's initial size using the minimum':
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
        // onboarding window (= the previous v1.0.0-m1-shell OOB
        // 'APP initial size, very small' was caused by `.contentMinSize`
        // ignoring the onboarding's outer frame as a hint; =
        // `.contentSize` actually DOES honour the outer frame as
        // the intrinsic content size).
        //
        // v1.0.0-m1-shell boss 2026-09-10 OOB 'the middle column's default width doesn't
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
        // Per Apple HIG developer.apple.com/documentation/swiftui/
        // view/windowresizability: 'contentMinSize: The window
        // can't be smaller than its content's minimum size, but
        // can be larger.' = the right resizability mode for a
        // window whose ideal content size is larger than its min
        // (= 4-column NSV; = sidebar+cards+detail+inspector).
        .windowResizability(.contentMinSize)
        // v0.81 boss 2026-09-10 OOB: the inspector toggle button
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
            // Boss 2026-09-10 OOB "Apple default": drop InspectorCommands().
            // NSV .inspector(isPresented:) modifier already renders a
            // column-header chevron for inspector visibility; the
            // duplicated View > Inspector menu item (⌥⌘I) was a
            // v0.48 convenience that bypassed SwiftUI default
            // behavior. The chevron + drag header are the Apple
            // canonical affordance.

            // v0.40 apple-001 + boss real-device test (2026-09-07) fix:
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
            // Boss 2026-09-10 OOB "drop menu items": ⌘K Command Palette
            // was a hermes parity carryover from v0.40. Restore the
            // macOS-default File > New behavior (= ⌘N for new
            // document) by removing the .newItem replacement.
            //
            // The post-.newItem block below (File > New Project
            // submenu + Import at ⇧⌘I) is preserved.
            CommandGroup(after: .newItem) {
                // v0.27 macOS-standard cross-component sync (boss 8/27
                // OOB): File → is the macOS-standard menu item
                // (= Cmd+N shortcut) for the file-creation kind. Per boss
                // 8/27 standing rule 'a new feature should appear
                // everywhere = synced', this Menu mirrors the toolbar '+'
                // Menu (= /). Both sub-items post a
                // NotificationCenter event that NewLibraryOutlineView
                // listens for and triggers the matching sheet.
                // v1.0.0-m1-shell boss 2026-09-10 OOB '⌘N opens a new Wenshu document': the
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
                        appState.newBookRequestCount += 1
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    Button(WenshuI18n.t("menu.file.new_project.submenu.new_shelf")) {
                        appState.newShelfRequestCount += 1
                    }
                }
                // v0.27 boss 8/27 OOB: menusync toolbar 'import' button.
                // Per boss 8/27 standing rule 'a new feature should
                // appear everywhere = synced', the menu bar gets a
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
            // v1.0.0-m1-shell boss 2026-09-10 OOB 'NSV is the default; the chat zone
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
            // v1.28 A1.3: the NSNotification dispatch was removed
            // (= EditorChatNSController listener deleted in this
            // commit; = only the AppState flag flip remains; = the
            // chat zone visibility is owned by AppState.chatVisible
            // downstream consumers). Toggle still binds the flag.
            CommandGroup(after: .toolbar) {
                Toggle(WenshuI18n.t("menu.view.show_chat_zone"), isOn: Binding(
                    get: { appState.chatVisible },
                    set: { newValue in
                        appState.chatVisible = newValue
                    }
                ))
                .keyboardShortcut("k", modifiers: [.command, .option])
            }
        }
        Settings {
            SettingView()
        }
        // B-11: inject AppState into the Settings scene so
        // SettingView's `@Environment(AppState.self) private var
        // appState` lookup (= appState.llmModel on the model picker
        // binding) doesn't assert-fail when the user opens Settings
        // via ⌘,. Without this, opening Settings crashed in
        // `_assertionFailure` from `EnvironmentValues.subscript.getter`
        // because the Settings scene had no `.environment(appState)`
        // modifier (= only the WindowGroup's content view had one).
        .environment(appState)
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'Kanban and Todo get their own dedicated windows':
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
        // v1.0.0-m1-shell boss 2026-09-11 OOB followup (= observation
        // from the cua AX tree dump + the macOS 27 Tahoe routing
        // observed in earlier debug output): WindowGroup IDs must
        // avoid the legacy Preferences / Settings ID namespace
        // (= IDs that match the system's Settings scene route to
        // the SettingsEnvironmentCapturer instead of opening a
        // new window). 'wenshu-kanban' / 'wenshu-todo' use
        // short opaque tokens that avoid that namespace
        // collision.
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'what I said about multi-instance and
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
        // v1.0.0-m1-shell boss 2026-09-11 OOB 'for Kanban, Settings, Todo
        // windows instances, the window size needs to auto-fit the content, no need to set
        // a fixed size': per Apple HIG `Window` (= single-instance)
        // sizes itself to the view's intrinsic content size
        // by default (= no `.defaultSize` modifier needed).
        Window("看板", id: WindowID.kanban) {
            KanbanWindow(library: library)
        }
        .windowResizability(.contentSize)
        // macOS 27 doc-alignment (audit ticket 3): kanban + todo
        // secondary windows match the main window's
        // `.unified` (= 52 PT default macOS toolbar) for
        // consistency.
        .windowToolbarStyle(.unified)
        Window("待办", id: WindowID.todo) {
            TodoWindow(library: library)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
    }
}
