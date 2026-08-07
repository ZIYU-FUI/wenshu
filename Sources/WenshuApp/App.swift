// App.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-005
//
// SwiftUI App entry point.
// - WO-001: bare WindowGroup + LSUIElement=false Info.plist
// - WO-002: inject `PersistenceController` for WenshuStoreActor
// - WO-004: inject `ChatViewModel` for the project-creation flow
// - WO-005: eagerly touch `WenshuProjectStore.shared` so the
//   `~/Documents/wenshu-projects/` directory exists from the first frame
//   (verification criterion: "swift run 后 目录被建出来")
//
// Per AGENTS.md §13 baseline: single-process Swift/SwiftUI desktop app.

import SwiftUI

@main
struct WenshuApp: App {
    @StateObject var persistence = PersistenceController.shared
    @StateObject var chatVM = ChatViewModel()

    // NOTE (WO-001): We do NOT customize NSApp.activationPolicy here.
    // The Info.plist's LSUIElement=false + NSPrincipalClass=NSApplication
    // already grants us a regular foreground application. Confirm via
    // `swift run` and check that the window titled "文枢" appears + the
    // Dock icon shows.

    init() {
        // WO-005: trigger WenshuProjectStore.shared so the projects
        // directory is created synchronously (the actor's init only does
        // FileManager work, so touching the static let from here is safe
        // and doesn't need `await`). This satisfies the verification
        // "swift run 后 ~/Documents/wenshu-projects/ 目录被建出来"
        // independently of whether the user clicks through the 8-step flow.
        _ = WenshuProjectStore.shared
    }

    var body: some Scene {
        WindowGroup("文枢") {
            MainView()
                .environmentObject(chatVM)
                .environmentObject(persistence)
                // WO-002+ wires the WenshuStore actor via environmentObject;
                // WO-004 adds the ChatViewModel. Both injected here.
                .frame(minWidth: 900, minHeight: 600)
        }
        // WO-001 leaves default window behaviour. macOS-only SwiftUI
        // commands come later when we have something to act on.
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}
