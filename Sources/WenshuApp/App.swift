// App.swift · 文枢 (Wenshu) · v0.01.0 WO-001
//
// SwiftUI App entry point. Bare-minimum scaffold:
// - @main entry
// - One WindowGroup titled "文枢"
// - macOS-only activation policy handled via Info.plist (LSUIElement=false)
//
// Per AGENTS.md §13 baseline: single-process Swift/SwiftUI desktop app.
// WO-001 has no business logic, no CoreData, no LLM client — those
// arrive in WO-002 / WO-003 (see CLAUDE.md §9 deliverable list).

import SwiftUI

@main
struct WenshuApp: App {
    @StateObject var persistence = PersistenceController.shared

    // NOTE (WO-001): We do NOT customize NSApp.activationPolicy here.
    // The Info.plist's LSUIElement=false + NSPrincipalClass=NSApplication
    // already grants us a regular foreground application. Confirm via
    // `swift run` and check that the window titled "文枢" appears + the
    // Dock icon shows.

    var body: some Scene {
        WindowGroup("文枢") {
            MainView()
                // WO-002+ will inject @EnvironmentObject for the
                // WenshuStore actor. Not wired yet.
                .frame(minWidth: 900, minHeight: 600)
        }
        // WO-001 leaves default window behaviour. macOS-only SwiftUI
        // commands come later when we have something to act on.
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}
