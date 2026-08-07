// App.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-009
//
// SwiftUI App entry point.
// - WO-001: bare WindowGroup + LSUIElement=false Info.plist
// - WO-002: inject `PersistenceController` for WenshuStoreActor
// - WO-004: inject `ChatViewModel` for the project-creation flow
// - WO-005: eagerly touch `WenshuProjectStore.shared` so the
//   `~/Documents/wenshu-projects/` directory exists from the first frame
//   (verification criterion: "swift run 后 目录被建出来")
// - WO-009: add AppDelegate that explicitly calls
//   `NSApp.setActivationPolicy(.regular)` + `NSApp.activate(...)`.
//
// Per AGENTS.md §13 baseline: single-process Swift/SwiftUI desktop app.

import SwiftUI
import AppKit

// WO-009: NSApplicationDelegate that forces a `.regular` activation policy.
//
// Why this is needed (WO-009 spec):
// `swift run` produces a SwiftPM-only Mach-O binary, NOT a proper
// `.app` bundle. AppKit initializes such a process with the default
// activation policy `.prohibited` (a "background helper" without Dock
// icon or foreground rights). Even though we embed Info.plist into
// the __TEXT,__info_plist section (see Package.swift linker flag),
// AppKit on macOS 14/27 still falls back to `.prohibited` for
// SwiftPM-only binaries — `Info.plist::LSUIElement=false` alone does
// NOT upgrade the policy reliably when there's no bundle directory.
//
// Symptom without this fix (装机 user 8/7 实机验):
// - sheet/key window appears visually (blue caret + title bar)
// - but key events still route to the previously-active app
//   (terminal / Hermes / 飞书), because Window Server sees our
//   process as a non-foreground helper and won't grant us key focus.
//
// Fix: explicitly call `NSApp.setActivationPolicy(.regular)` in
// `applicationDidFinishLaunching`, then `NSApp.activate(...)`. This
// upgrades us to a foreground app with Dock presence + key window
// dispatch rights. WindowGroup + sheet/key window now behave normally.
//
// We do NOT set the policy in `App.init()` because at that point
// `NSApp` may not be fully initialized — `applicationDidFinishLaunching`
// is the documented AppKit hook for this.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct WenshuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var persistence = PersistenceController.shared
    @StateObject var chatVM = ChatViewModel()

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
