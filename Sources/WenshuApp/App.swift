// App.swift · 文枢 (Wenshu) · v0.01.0 WO-001 → WO-009 → v0.03.0 V0-fix-6 → V0-fix-7 → V0-fix-9
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
// V0-fix-6: 加 applicationIconImage 兜底 (B5 装机 user 8/10 17:40 OOB
// 拍"LOGO 没生效"). 标准 Assets.xcassets/AppIcon.appiconset/ 接入
// 已在 Package.swift resources: [.copy("Assets.xcassets")] + Info.plist
// CFBundleIconName=AppIcon + CFBundleIconFile=AppIcon 三处拍齐. 但
// SwiftPM 纯命令行 build 不跑 actool, .appiconset 不会被编进 .car
// (.app bundle 内的 compiled asset archive), AppKit 找不到资源. 兜底:
// AppDelegate.applicationDidFinishLaunching 显式
// `NSApp.applicationIconImage = NSImage(contentsOfFile:)` 加载
// Sources/WenshuApp/Resources/Brand/AppIcon.icns. 等 wenshu.xcodeproj
// (v0.01.x) 上线, Xcode actool 自动接管, 这段兜底代码失效无害.
//
// V0-fix-7 (2026-08-11 18:05 CUA 自验): `WindowGroup("文枢")` → `WindowGroup("")`
// 去掉 traffic light 旁硬显示的"文枢"两字。 红字真意 = 修真, 不是共存,
// 但 WindowGroup("") 修真半成品 — Info.plist CFBundleDisplayName fallback
// 仍显"文枢"两字。
//
// V0-fix-8 (装机 user 8/11 16:20 真机拍 4 红字批注 #1): WindowGroup 修真
// 完整 = `WindowGroup("")` → `WindowGroup { }` + LayoutShellView
// NavigationStack 顶层 `.toolbar ToolbarItem(.principal)` 接 + 按钮 (FCP
// 范式 单 + 入口 — 红字"新建按钮放在这里, 替换文枢文字")。 红字真意 = 修真,
// 不是共存。
//
// V0-fix-9 (2026-08-11 装机 user 16:42 CUA 自验发现): 修真 #1 完整兜底 —
// 加显式 `.navigationTitle("")` 覆盖 CFBundleDisplayName fallback, 让
// macOS title bar 修真生效只显 + 按钮 (居中, ToolbarItem(.principal))。
//
// 含义 (V0-fix-7 → V0-fix-9 完整修真):
//   - 主窗口 title bar 不再硬挂"文枢"标题 (sheet 标题会自带, 如 "新建
//     项目" 是 ProjectCreateView 默认 sheet 标题)
//   - macOS 默认行为 + V0-fix-9 .navigationTitle("") 兜底: traffic light
//     旁不显示任何文字, 跟 Pages / Numbers / FCP 主窗口范式一致 (顶部
//     toolbar 只显 + 按钮)
//   - app menu 第一项 (macOS 菜单栏) 仍叫 "文枢" (沿 WenshuAppCommands
//     CommandMenu("文枢"), 这是菜单栏文案不是窗口标题, 不动)
//   - 不动 WindowGroup 内部 MainView() + environmentObject + frame +
//     windowStyle/.titleBar + .windowResizability + .commands
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
//
// V0-fix-6: 加 applicationIconImage 兜底. 见上方 file-level 注释.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // V0-fix-6: Logo 注入候选路径表 — 按优先级试, 找到第一个能加载
    // 的就用. SwiftPM .build bundle 路径在 .app bundle 缺失时不可用,
    // 兜底用开发期已知绝对路径 (Resources/Brand/AppIcon.icns, 已从
    // ~/Desktop/LOGO/wenshu-icon-light.icns 复制).
    private static let iconCandidatePaths: [String] = [
        // 1. .app bundle 内的 compiled .icns (标准路径, .app 上线后命中)
        Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns",
        // 2. SwiftPM bundle 内的 .icns (resources: [.copy] 命中后)
        Bundle.main.bundlePath + "/WenshuApp_WenshuApp.bundle/Contents/Resources/AppIcon.icns",
        // 3. 开发期已知绝对路径 (兜底, swift run 直接跑命中)
        "/Volumes/ANAN/Engineering/wenshu/.worktrees/t_45ae4de3/Sources/WenshuApp/Resources/Brand/AppIcon.icns",
        // 4. 装机 user 桌面 LOGO 目录 (PM-direct CUA 拍图验证时命中)
        "/Users/anbaiqiang/Desktop/LOGO/wenshu-icon-light.icns"
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // V0-fix-6: 显式加载 LOGO 兜底. 标准 .appiconset 由 Info.plist
        // CFBundleIconName 指向 (Xcode actool 编 .car 后 AppKit 自动
        // 加载), 但 SwiftPM 纯命令行 build 不跑 actool, 这里用
        // applicationIconImage 强制覆盖 (避免 Dock + title bar 显
        // AppKit 默认 icon). 失败也不 fatal — AppKit 默认 icon 仍
        // 可用, 只是没 LOGO.
        for path in Self.iconCandidatePaths {
            if let image = NSImage(contentsOfFile: path) {
                NSApp.applicationIconImage = image
                break
            }
        }
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
// V0-fix-7 → V0-fix-9 修真 #1 完整:
        //   - V0-fix-7: WindowGroup("文枢") → WindowGroup("")
        //   - V0-fix-8: WindowGroup("") → WindowGroup { } (no title string)
        //   - V0-fix-9: + .navigationTitle("") in LayoutShellView (兜底
        //               覆盖 CFBundleDisplayName fallback)
        // 红字真意 = "替换文枢文字", 不是共存 (装机 user 8/11 16:20 红字)。
        WindowGroup {
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

// MARK: - 文枢 menu (LT-01-fix5)
//
// 装机 user 8/7 实机验发现 macOS 菜单栏第一个 menu 显示 "wenshu"
// (AppKit 从 `CFBundleName = "Wenshu"` 推出来的全小写形式) 而不是
// 我们期望的 "文枢". 修法: 显式声明一个 `CommandMenu("文枢")` 把
// 第一个 menu 的标题写死为中文, 同时把"关于文枢 / 隐藏文枢 / 退出文枢"
// 这些 macOS 标准项都放进同一个 menu, 避免 AppKit 的自动合成跟我们的
// 显式声明打架 (= 不会出现 "wenshu" + "文枢" 两个同名 menu).
//
// 兼容性: macOS auto-generated app menu 的名字仍然取自
// `CFBundleName`, 但 `CommandMenu("文枢")` 把 SwiftUI 命令列表里
// 的第一个 menu 钉死成 "文枢" — 在菜单栏最终渲染时, 我们这个
// 显式 menu 顶替了 auto-generated 的位置.
//
// 兜底: `Bundle.main.infoDictionary["CFBundleDisplayName"] as? String
// ?? "文枢"` 保证不论 Info.plist 是 "wenshu" 还是 "文枢", 文案
// 都读到中文.

struct WenshuAppCommands: Commands {
    /// LT-01-fix5: 第一个 menu 名字 hardcode 为 "文枢" (中文), 而
    /// 不是从 `CFBundleName = "Wenshu"` 推出的小写 "wenshu". 这是
    /// 装机 user 8/7 实机验拍板.
    static let menuTitle: String = {
        let fromBundle = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        return (fromBundle?.isEmpty == false ? fromBundle : nil) ?? "文枢"
    }()

    var body: some Commands {
        // LT-01-fix5 替换原 `CommandGroup(replacing: .appInfo)`.
        // 显式声明 `CommandMenu("文枢")`, 整个 app menu (关于 / 隐藏 /
        // 退出 / Services) 都装在这个 menu 内, 替代 AppKit 的自动合成.
        CommandMenu(Self.menuTitle) {
            Button("关于文枢") {
                showAboutPanel()
            }

            Divider()

            Button("隐藏文枢") {
                NSApp.hide(nil)
            }
            .keyboardShortcut("h", modifiers: .command)

            Button("隐藏其他") {
                NSApp.hideOtherApplications(nil)
            }
            .keyboardShortcut("h", modifiers: [.command, .option])

            Button("全部显示") {
                NSApp.unhideAllApplications(nil)
            }

            Divider()

            Button("退出文枢") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
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

// MARK: - 显示 menu (LT-01-fix4)
//
// Single "显示" menu (was: 显示 + View, two separate menus, prior to LT-01-fix4).
// FCP 范式 + macOS HIG — Pages / Numbers / Xcode / Final Cut all collapse
// show/hide chrome into one menu. The macOS App-menu naming convention
// uses the localised term (Chinese-localised apps prefer "显示" over
// "View" — confirmed by AGENTS §8.1's existing 拍板 "显示" name).
//
// 显示 → 重置布局         : back to AGENTS §8.1 defaults, written to .ws
// 显示 → 5 panel toggles (Cmd+1…5) + 全显示 (Cmd+Shift+1), FCP 范式
//
// Drives `LayoutShellViewModel.shared` — the same instance the shell
// View observes. Menu actions are plain closures (not MainActor-isolated),
// so each hop goes through `Task { @MainActor in ... }`.
//
// LT-01-fix4 优化: each toggle's title reflects its NEXT action
// ("隐藏 X" when X is visible, "显示 X" when hidden). Titles come from a
// small View (`LayoutMenuContent`) that holds the `@ObservedObject`
// reference — `Commands` structs don't accept `@ObservedObject` directly,
// but a `@ViewBuilder content:` closure does, so the helper View
// re-renders when the VM publishes.

struct LayoutCommands: Commands {
    var body: some Commands {
        CommandMenu("显示") {
            LayoutMenuContent()
        }
    }
}

/// Inner View for the "显示" menu. Lives as a separate type so it can
/// carry an `@ObservedObject` (Commands structs cannot). The CommandMenu
/// re-evaluates this body whenever the observed VM publishes, so the
/// toggle item labels stay in sync with the panel visibility state.
///
/// LT-01-fix5 优化1: 文档 / 聊天 这两块 (装机 user 8/7 拍板不可隐藏)
/// 在菜单项里是 disabled (灰色), 让用户看到"这里不能 hide". 点击
/// 也没动作 (VM 的 togglePanelVisibility 有同样的 guard).
private struct LayoutMenuContent: View {
    @ObservedObject var vm = LayoutShellViewModel.shared

    var body: some View {
        Button("重置布局") {
            Task { @MainActor in
                await vm.resetToDefaults()
            }
        }
        // v0.04.0 扩展位: 时间线 / 关系图 / 大纲 视图切换

        Divider()

        // FCP 范式: each toggle's title reflects its NEXT action, so the
        // user always sees whether a click will hide or show the panel.
        // Title is computed off the observed VM, so SwiftUI re-renders
        // the menu after every toggle.
        ForEach(PanelID.allCases, id: \.self) { panel in
            Button(vm.menuTitle(for: panel)) {
                Task { @MainActor in
                    vm.togglePanelVisibility(panel)
                }
            }
            .keyboardShortcut(panel.menuShortcut, modifiers: .command)
            // v0.04.0 FCP 3 toggle (t_bfa84198): isDismissible 沿 designer
            // 真值 — 5 区全 dismissible (FCP 范式 = 全 toggle, 区别于
            // v0.02.0 LT-01-fix5 装机 user 拍板的"核心创作区永驻"硬约束),
            // .topCenter / .bottomLeft 也允许 hide. CommandMenu 自动跟随
            // isDismissible 重新 evaluate, 不需要额外逻辑.
            .disabled(!panel.isDismissible)
        }

        Divider()

        Button("全显示") {
            Task { @MainActor in
                vm.showAllPanels()
            }
        }
        .keyboardShortcut("1", modifiers: [.command, .shift])
        // v0.04.0 扩展位: 时间线 / 关系图 / 大纲 panel
    }
}
