// Sources/WenshuApp/App/AppRootScene.swift
// … (= 12 rationale lines collapsed; = A112 docblock collapse per §1.8)
// in, not constructed here.
import AppKit
import SwiftUI
import WenshuData

// / Window IDs for the dedicated secondary scenes (= the SwiftUI
// … (= 18 rationale lines collapsed; = A112 docblock collapse per §1.8)
// / scenes, prefer this same naming convention.
enum WindowID {
    static let kanban = "wenshu-kanban"
    // SwiftData library upgrade panel window (see OOB.md #2026-10-06). Single-instance Window (= macOS
    // … (= 5 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // must walk through the panel's 重试 / 退出 button path).
    // This one has no toolbar button: it is opened by the migration
    // pipeline itself when a library upgrade starts, and it is the only
    // way out of a failed upgrade.
    static let libraryMigration = "wenshu-library-migration"
}

struct AppRootScene: Scene {
    let library: WenshuLibrary
    @Binding var appearanceMode: AppearanceMode
    let appState: AppState
    // / ShellState was removed in 2026-10-03 overabstraction cleanup
    // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / class holding duplicated cross-column state).
    let workspaceUI: WorkspaceUIState
    // / Sheet-request triggers (= fire-and-forget counters for the
    // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // / at every scene root (= WindowGroup content + Settings scene).
    let sheetRequests: SheetRequestState
    let editorCounters: EditorCounters
    let repositories: WSRepositoryContainer

    // the kanban + todo Windows each construct their own BookStore /
    // … (= 10 rationale lines collapsed; = A112 docblock collapse per §1.8)
    // the shared on-disk JSON files).
    var body: some Scene {
        // title set to empty string (= no NSWindow title shown). Combined
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // dropped CommandPaletteHost + SettingsEnvironmentCapturer
            // … (= 8 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // view layers total = Apple canonical).
            LibraryRootView(library: library, appearanceMode: appearanceMode)
                .environment(appState)
                .environment(workspaceUI)
                .environment(sheetRequests)
                .environment(editorCounters)
                .environment(repositories)
        }
// .windowToolbarStyle(.unified) = 52 PT macOS native titlebar
// … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
// goes blank). Stick with .unified.
        .windowToolbarStyle(.unified)
        // wenshu-verification-fix: .contentMinSize (window doesn't shrink below initial
        // … (= 64 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // (= drag stops at the NSV's frame boundaries).
        .defaultSize(width: 1400, height: 980)
        // : the
        // … (= 11 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // macOS 13+ (= wenshu target = macOS 27).
        .defaultPosition(.center)
        // Apple HIG default restoration (= `.automatic` = SwiftUI
        // … (= 34 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // standard macOS zoom gesture working as expected.
        .windowResizability(.contentMinSize)
        // the inspector toggle button
        // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // `.inspector(isPresented:)` modifier binds.
        .commands {
            // NSV .inspector(isPresented:) modifier already renders a
            // … (= 31 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // submenu + Import at ⇧⌘I) is preserved.
            CommandGroup(after: .newItem) {
                // macOS-standard cross-component sync ((see OOB.md #2026-08-27)):
                // … (= 30 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // triggered flow).
                Menu(String(localized: "menu.file.new_project")) {
                    Button(String(localized: "menu.file.new_project.submenu.new_book")) {
                        sheetRequests.newBook += 1
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    Button(String(localized: "menu.file.new_project.submenu.new_shelf")) {
                        sheetRequests.newShelf += 1
                    }
                }
                // (see OOB.md #2026-08-27) — menu-sync toolbar 'import'
                // … (= 9 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // listen + implement.
                Button(String(localized: "menu.file.import")) {
                    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button(String(localized: "export.menu.file")) {
                    sheetRequests.exportSheet += 1
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button(String(localized: "menu.edit.undo"), action: {})
                    .keyboardShortcut("z", modifiers: .command)
                Button(String(localized: "menu.edit.redo"), action: {})
                    .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            // is a zone that can be shown/hidden, but the toggle lives in the menu bar, there is no dedicated
            // … (= 25 rationale lines collapsed; = A112 docblock collapse per §1.8)
            // the flag.
            CommandGroup(after: .toolbar) {
                Toggle(String(localized: "menu.view.show_chat_zone"), isOn: Binding(
                    get: { workspaceUI.chatVisible },
                    set: { newValue in
                        workspaceUI.chatVisible = newValue
                    }
                ))
                .keyboardShortcut("k", modifiers: [.command, .option])
            }
        }
        Settings {
            SettingView()
        }
        // inject AppState into the Settings scene so
        // … (= 6 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // modifier (= only the WindowGroup's content view had one).
        .environment(appState)
        .environment(repositories)
        // Apple-default `Settings { }` uses `.windowResizability(.contentSize)`
        // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // = SwiftUI default = `.infinity`).
        .windowResizability(.contentMinSize)
        // The Settings window's initial size on first launch (= the
        // … (= 14 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // or larger (= SwiftUI default `.infinity`).
        .defaultSize(width: 950, height: 517)
        // Add 2 dedicated `Window` scenes (= the SwiftUI macOS
        // … (= 64 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // by default (= no `.defaultSize` modifier needed).
        Window("看板", id: WindowID.kanban) {
            KanbanWindow(workspaceUI: workspaceUI)
        }
        .windowResizability(.contentSize)
        // macOS 27 doc-alignment: kanban + todo secondary windows
        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // macOS toolbar) for consistency.
        .windowToolbarStyle(.unified)
        // SwiftData library upgrade panel (= boss OOB 2026-10-06
        // … (= 26 rationale lines collapsed; = A112 docblock collapse per §1.8)
        // arguments from outside).
        Window(String(localized: "library.migration.title"), id: WindowID.libraryMigration) {
            if let state = WenshuAppDelegate.sharedMigrationState {
                LibraryMigrationPanel(
                    state: state,
                    onRetry: {
                        // Re-run the migration. WenshuAppDelegate
                        // … (= 1 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // prepare / execute / finalize pipeline.
                        WenshuAppDelegate.sharedMigrationRetry?()
                    },
                    onExit: {
                        // Clean termination of the upgrade flow
                        // … (= 2 rationale lines collapsed; = A112 docblock collapse per §1.8)
                        // contract (panel only-escapes are 重试/退出; = see OOB.md #2026-10-06).
                        NSApp.terminate(nil)
                    }
                )
            } else {
                // Defensive placeholder. The Window body only renders
                // … (= 4 rationale lines collapsed; = A112 docblock collapse per §1.8)
                // instead of a fatalError.
                EmptyView()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
