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
        // WO-001 leaves default window behaviour.
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        // LT-01-fix3: layout controls live in the macOS menu bar (HIG:
        // the in-window toolbar carries actions, configuration/info goes
        // to the menu bar). Pages / Numbers / Xcode / Final Cut all do this.
        .commands {
            WenshuAppCommands()
            LayoutCommands()
        }
    }
}

// MARK: - 文枢 menu (LT-01-fix3)
//
// macOS synthesises the leading app menu from `CFBundleDisplayName`
// (= 文枢, see Resources/Info.plist) and already supplies 隐藏文枢 /
// 隐藏其他 / 退出文枢 — re-declaring those would produce duplicates.
// We only replace the system "About" item, so the entry reads
// 文枢 → 关于文枢 and shows our version instead of AppKit's default panel.

struct WenshuAppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于文枢") {
                showAboutPanel()
            }
        }
    }

    /// AppKit's standard about panel, fed our own version string. Keeping
    /// the native panel (rather than a SwiftUI sheet) means we inherit
    /// HIG layout, the app icon, and localisation for free.
    private func showAboutPanel() {
        let info = Bundle.main.infoDictionary
        let name = info?["CFBundleDisplayName"] as? String ?? "文枢"
        let version = info?["CFBundleShortVersionString"] as? String ?? "0.02.0"
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: name,
            .applicationVersion: version,
            .credits: NSAttributedString(
                string: "Apple 全家桶专属长篇虚构小说 AI 创作平台\nMIT License"
            )
        ])
    }
}

// MARK: - 显示 / View menus (LT-01-fix3)
//
// 显示 → 重置布局      : back to AGENTS §8.1 defaults, written to .ws
// View  → 5 panel toggles (Cmd+1…5) + 全显示 (Cmd+Shift+1), FCP 范式
//
// Both drive `LayoutShellViewModel.shared` — the same instance the shell
// View observes. Menu actions are plain closures (not MainActor-isolated),
// so each hop goes through `Task { @MainActor in ... }`.

struct LayoutCommands: Commands {
    var body: some Commands {
        CommandMenu("显示") {
            Button("重置布局") {
                Task { @MainActor in
                    await LayoutShellViewModel.shared.resetToDefaults()
                }
            }
            // v0.04.0 扩展位: 时间线 / 关系图 / 大纲 视图切换
        }

        CommandMenu("View") {
            ForEach(PanelID.allCases, id: \.self) { panel in
                Button(panel.title) {
                    Task { @MainActor in
                        LayoutShellViewModel.shared.togglePanelVisibility(panel)
                    }
                }
                .keyboardShortcut(panel.menuShortcut, modifiers: .command)
            }
            Divider()
            Button("全显示") {
                Task { @MainActor in
                    LayoutShellViewModel.shared.showAllPanels()
                }
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])
            // v0.04.0 扩展位: 时间线 / 关系图 / 大纲 panel
        }
    }
}
