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
import Lucide

struct AppRootScene: Scene {
    let library: WenshuLibrary
    @Binding var appearanceMode: AppearanceMode
    let appState: AppState

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
        // v0.93 boss 2026-09-10 OOB '之前 NSV probe 好好的':
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
        .windowToolbarStyle(.unifiedCompact)  // 28 PT compact chrome (matches probe / Mail / Notes / Finder)
        // .windowToolbarStyle(.unifiedCompact(showsTitle: false))  // 28 PT compact chrome, no unified toolbar background
        // v0.96 boss 2026-09-10 OOB '之前 NSV probe 好好的': the
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
        // v0.101 boss 2026-09-10 OOB '各列按 Apple 推荐参数
        // 设置 min/ideal/max': re-enable `defaultSize(1480, 980)`
        // (= Apple HIG ideal-sum for sidebar 280 + content 320 +
        // detail 600 + inspector 280). With the toolbar style
        // now `.unifiedCompact` (= matches probe) + 4 columns
        // each declaring their columnWidth ranges, NSV now
        // respects the defaultSize (= the previous collapse was
        // caused by defaultSize + .unified pushing NSV into a
        // degenerate layout; that combo is no longer in effect).
        .defaultSize(width: LayoutTokens.designW, height: LayoutTokens.designH)  // 1480 x 980 (4-col Apple HIG ideal sum)
        // v0.24 bossverificationfix: .contentMinSize (window doesn't shrink below initial
        // size, can grow to fit larger content).
        // v0.91 boss 2026-09-10 OOB '1480 也可以': change to
        // .contentSize so the defaultSize (= 1480 PT width) is
        // actually applied. The previous `.contentMinSize` made
        // the window grow to fit the NavigationSplitView's
        // content minimum (= the 4-column ideal-width sum + drag
        // handles + window chrome = ~2205 PT), overriding
        // defaultSize entirely. .contentSize lets the window
        // resize freely (= not anchored to content minimum), so
        // defaultSize 1480 PT is the initial window size and the
        // user can shrink or grow from there.
        .windowResizability(.contentSize)
        // v0.81 boss 2026-09-10 OOB: the inspector toggle button
        // (= ⌥⌘I = Lucide "panel-right" icon = the canonical Apple
        // toolbar affordance for NavigationSplitView `.inspector`)
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
                Menu(WenshuI18n.t("menu.file.new_project")) {
                    Button(WenshuI18n.t("menu.file.new_project.submenu.new_book")) {
                        NotificationCenter.default.post(name: .wenshuNewBookRequested, object: nil)
                    }
                    Button(WenshuI18n.t("menu.file.new_project.submenu.new_shelf")) {
                        NotificationCenter.default.post(name: .wenshuNewShelfRequested, object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
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
    }
}
