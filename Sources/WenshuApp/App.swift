// App.swift · Wenshu · v0.09.0 6-zone layout shell (老板 8/18 组件化真值, 1920×984 PT)
// 数据源: Sketch AF7B1C87 / page 文枢 / Artboard 首页
// 组件化真值: mcp__sketch__run_code (2026-08-18) = 6 SymbolMaster + 13 SymbolInstance
// 单元: 1 PT = 1 PX (macOS 27 1x), 1:1 落, 不缩放.
//
// 6 master (老板 8/18 组件化规划):
//   1. 标题栏                (1920×39)
//   2. 区域顶部工具栏        (758×30)   ← zone 顶栏复用
//   3. 区域底部工具栏        (200×30)   ← zone 底栏复用
//   4. 区域模块              (200×472)  ← zone 主容器复用
//   5. 拖拽线-竖             (1×472)
//   6. 拖拽线-横             (1920×1)
//
// 13 instance 全部 1:1 落 SwiftUI, 详见 LayoutTokens.

import SwiftUI
import AppKit

// 老板 8/18 拍 "重置界面布局" 通知桥 (LayoutShellView 用 @State 私有 vm,
// 顶层 .commands 拿不到 vm 实例, 走 NotificationCenter 转发)
extension Notification.Name {
    static let wenshuResetLayout = Notification.Name("com.wenshu.resetLayout")
}

// MARK: - Layout tokens (比例算子 0~1, 老板 8/18 答 "1:1 PT 真值" + 8/18 再拍 "换算成比例")
//
// 数据源: Sketch AF7B1C87 / Artboard 首页 1920×984 PT 1:1 落
// 公式: layoutPT(token) = totalW * ratio (e.g. projectSidebar ratio = 200/1920 = 0.1042)
// Apple HIG responsive: GeometryReader 拿窗口实际尺寸 × 比例 = 任何窗口大小 1:1 自适应

/// Apple Semantic Color — 全 dark mode 适配, 0 RGB 硬编码 (DesignTokens.swift v0.10.6 移到 App.swift)
enum DesignColor {
    /// 标题栏 (boss Sketch #393939) → NSColor.windowBackgroundColor
    static let titleBar: Color = Color(nsColor: .windowBackgroundColor)
    /// 内容区底色 (boss Sketch #202020) → NSColor.controlBackgroundColor
    static let zoneSurface: Color = Color(nsColor: .controlBackgroundColor)
    static let dynamicZoneSurface: Color = Color(nsColor: .underPageBackgroundColor)
    /// 强调蓝 (Apple 系统亮色)
    static let accentBlue: Color = Color(nsColor: .controlAccentColor)  // Apple 系统亮色 (dark/light 自适应)
    /// 拖拽线 / 分割线 (Apple 系统 divider 色, dark/light 自适应)
    static let splitterLine: Color = Color(nsColor: .separatorColor)
}

enum LayoutTokens {
    // 设计基准 (Apple macOS 27 1x 下 1 PT = 1 PX)
    static let designW: CGFloat = 1600  // v0.15 ticket 024 修: 老板 2026-08-19 拍默认启动大小 1600×980 PT (老板实测真机桌面 大小)
    static let designH: CGFloat = 980

    // 比例算子 (0~1, 基准 1920×984)
    // 老板 2026-08-19 拍: 标题栏走 macOS .windowStyle(.titleBar) 52 PT unified chrome, 不再自写
    // v0.15 ticket 001: 删 LayoutTokens.titleBarHeight / titleRatio 死代码 (Apple window chrome 自带)
    static let bandRatio: CGFloat = 465.0 / 984.0        // = 0.4726 (老板 8/18 改 465 PT, 总 52+465+2+465 = 984)
    // v0.15 ticket 008 修: toolbar 高度 = 老板 Sketch 真值 30 PT 硬编码, 1:1 实现不做 PT→PX 换算 (老板 2026-08-19 拍)
    // 之前 toolbarRatio = 30/465 = 0.0645 算法 base = 465 写死, 但实际 bandH 由 932 算出来 → toolbarH = 932*0.4726*0.0645 ≈ 28 PT (跟老板 30 PT 不符, 视觉上不够)
    static let toolbarHeight: CGFloat = 30  // 老板 Sketch master 真值: 顶/底栏 30 PT (1:1 实现)
    // v0.15 重写后改名: editorInset 是单一垂直方向 (左右 flush, spec §3.2 故意两层设计)
    static let editorVerticalInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041 (编辑器 4 PT 上下 inset)
    // v0.15 ticket 005: 删 LayoutTokens.horizontalSplitterRatio 死代码 (NativeSplitter 自己管 thickness)

    // 上 band 4 zone 数对公式: (200, 中间 1, 中间 2, 400) = 1920
    // 老板 8/18 拍 "数对" = 拖拽线 1 PT 视觉线摊给左右 zone (各 0.5 PT)
    // 中间 1 + 中间 2 = 1920 - 200 - 400 = 1320
    // 维持原值 558 + 762 (中间 1 + 中间 2 = 1320) = 上 band 4 zone 1920 ✓
    static let projectSidebarRatio: CGFloat = 200.0 / 1920.0
    static let projectPreviewRatio: CGFloat = 520.0 / 1920.0  // 老板 8/18 改 520 PT (201,52,520,465)
    static let editorWRatio: CGFloat = 794.0 / 1920.0         // v0.15 ticket 012 修: 老板 2026-08-19 改 794 PT (724,52,794,465) (mcp__sketch__run_code 真值)
    static let toolsWRatio: CGFloat = 400.0 / 1920.0

    // 下 band 2 区 (老板 8/18 拍 "上四下两"): AI聊天 1518 + AI 动态 400 = 1918 (+ 2 PT 拖拽线)
    static let aiChatRatio: CGFloat = 1518.0 / 1920.0      // v0.15 ticket 012 修: 老板 2026-08-19 改 1518 PT (0,519,1518,465) (mcp__sketch__run_code 真值)
    static let dynamicWRatio: CGFloat = 400.0 / 1920.0

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041


    // 顶栏色块比例 (老板 8/18 Q3 答: 22/82/142 起点 + 38 PT 宽 + 60 PT 等距)
    static let iconLeadingRatio: CGFloat = 18.0 / 1920.0  // 起点 18 PT (老板 8/18 改 18 PT, 旧 22 PT)
    static let iconSizeRatio: CGFloat = 18.0 / 1920.0     // 18 PT 边长 (老板 8/18 改 18x18, 旧 38x38)
    static let iconSpacingRatio: CGFloat = 18.0 / 1920.0  // 18 PT 等距 (老板 8/18 改 18 PT = icon 间距, 起点 18/54/90 相邻 36 - 18 = 18)

    // 底栏占位元素 (老板 8/18 拍 "icon 18×18, 占位文字苹果字符样式正文尺寸") — 绝对 PT 不走比例
    static let bottomLeading: CGFloat = 18                 // 18 PT 距左 (左占位文字)
    static let bottomTrailing: CGFloat = 18                // 18 PT 距右 (右占位 icon)
    static let placeholderIconSize: CGFloat = 18          // 18 PT 占位 icon 边长 (绝对值)
    static let placeholderTextLeadingRatio: CGFloat = 0.09  // 占位文字起点 18/200 = 9%
}

// MARK: - Self screenshot (老板 8/14 12:38 + 8/15 14:48: 每次代码改完必 screenshot)

enum SelfScreenshot {
    @MainActor
    static func run() {
        let env = ProcessInfo.processInfo.environment
        let path = env["WS_SCREENSHOT_PATH"] ?? "/tmp/wenshu-selfshot.png"
        let delay = Double(env["WS_SCREENSHOT_DELAY"] ?? "5.0") ?? 5.0  // v0.10.7: 5s 避免 layout race condition
        let shouldExit = env["WS_SCREENSHOT_EXIT"] != "0"

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            captureOnce(path: path, exitAfter: shouldExit)
        }
    }

    @MainActor
    private static func captureOnce(path: String, exitAfter: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard
                let window = NSApp.keyWindow
                    ?? NSApp.windows.first(where: { $0.contentViewController != nil }),
                let contentView = window.contentView
            else {
                if exitAfter { exit(2) }
                return
            }
            window.layoutIfNeeded()
            contentView.layoutSubtreeIfNeeded()
            let bounds = contentView.bounds
            guard bounds.width > 0, bounds.height > 0,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds)
            else {
                if exitAfter { exit(2) }
                return
            }
            bitmap.size = bounds.size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: bounds.size).fill()
            NSGraphicsContext.restoreGraphicsState()
            contentView.cacheDisplay(in: bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                if exitAfter { exit(3) }
                return
            }
            try? png.write(to: URL(fileURLWithPath: path))
            if exitAfter { exit(0) }
        }
    }
}

// MARK: - App entry

// wenshu 外观三态 (system / dark / light), 用于 Settings 弹窗 + 持久化 @AppStorage
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case dark
    case light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .dark:   return "深色"
        case .light:  return "浅色"
        }
    }
    /// 映射到 SwiftUI ColorScheme (system 传 nil 让 SwiftUI 跟系统)
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

@main
struct WenshuApp: App {
    @NSApplicationDelegateAdaptor(WenshuAppDelegate.self) var appDelegate

    @State private var library = WenshuLibrary(
        store: FileSystemLibraryStore(rootURL: LibraryRoot.ensureDefault())
    )
    // v0.21 ticket 01 (重做 #11): 加回 @AppStorage("appearanceMode") (撤回 commit 4ef3e2e77 硬解字符串, 改回 @AppStorage 真值响应式)
    // 真因 (Standards sub-agent report H3 真硬违反): preferredColorScheme 之前用 UserDefaults.standard.string 硬解, 跟 SettingView 的 $appearanceMode 不是同一个 binding source-of-truth
    // 撤回 commit 4ef3e2e77 的 UserDefaults.standard.string 硬解, 改用 @AppStorage 真值响应式 (跟 SettingView 共享同一 key)
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some Scene {
        WindowGroup("文枢") {
            // v0.21 ticket 01 (重做 #10): 撤回 SettingsEnvironmentCapturer wrapper (commit a78d758bc Q15 翻车 #11 dead code)
            // SettingsEnvironmentCapturer 之前包 LayoutShellView 注入 OpenSettingsAction, 但 openSettings?() → nil (Q15 翻车 #11), 现在 NSMenu 自己装 + 自创建 NSWindow 装 SettingView 不需要 capture
            LayoutShellView()
                .environment(library)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowStyle(.titleBar)  // 老板 8/18 拍 macOS 52 PT unified titlebar chrome = 老板自定义 52 PT 顶栏, 视觉合一
        .defaultSize(width: LayoutTokens.designW, height: LayoutTokens.designH)  // 老板 Sketch 设计基准 1920×984 PT (v0.15 ticket 005 响应式: LayoutShellView 删 fixed frame, window 用 defaultSize 给 SwiftUI 初始 size hint)
        .windowResizability(.contentSize)  // 内容驱动窗口大小 (GeometryReader × 比例算子自适应 resize)
        // v0.21 ticket 01 (重做 #4): 删 .commands { CommandGroup(.appSettings) { SettingsLink() } } 段
        // (Q15 翻车链 #8 总结: SwiftUI .commands 段在 macOS 27 lazy populate 覆盖了 .commands 注入的 SettingsLink, NSMenu "设置…" 没装 = 老板 8/21 19:30 反馈"设置菜单没有了")
        // 真因 (Q28 Stack Overflow 76359975 真值): SwiftUI macOS 14+ NSMenu 装 "Settings…" 必须自己 NSWindow + NSHostingController 范式 (Settings { } Scene 是 SwiftUI App body 标准 cmd+, handler)
        // v0.20 ticket 08 老真值保留: NSMenu 已装 6 项中文 (文枢/文件/编辑/显示/窗口/帮助, 见 WenshuAppDelegate.installMainMenu)
        // SettingsView 真值保留在 Settings { ... } Scene, NSMenu "设置…" action 接 WenshuAppDelegate.openSettingsWindow 自定义 @objc (自己创建 NSWindow 弹设置)
        Settings {
            SettingView()
        }
    }
}

/// v0.21 ticket 01 (重做 #5): SettingView 复用 (Settings { } Scene + NSHostingView 装 NSWindow 设置弹窗 共享同一 view)
/// v0.21 ticket 02: 重写 Apple macOS 27 标准范式 (老板 8/21 20:50 拍 "参考苹果官方软件的设置页, 用 macOS 27 的组件")
/// Apple 官方范式真值: TabView + Tab API (SwiftUI 14+) toolbar 自动显示 tab, Form + Picker + Toggle (Apple HIG macOS)
struct SettingView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.model") private var llmModel: String = MiniMaxModel.m3.rawValue  // v0.21 ticket 04: 配完省略显示
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "通用"
        case model = "模型"
        case shortcuts = "快捷键"
        var id: String { rawValue }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Text(SettingsTab.general.rawValue) }
                .tag(SettingsTab.general)
            modelTab
                .tabItem { Text(SettingsTab.model.rawValue) }
                .tag(SettingsTab.model)
            shortcutsTab
                .tabItem { Text(SettingsTab.shortcuts.rawValue) }
                .tag(SettingsTab.shortcuts)
        }
        .frame(width: 480, height: 360)
    }

    private var generalTab: some View {
        Form {
            Picker("外观", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .formStyle(.grouped)
    }

    private var modelTab: some View {
        Form {
            // v0.21 ticket 04: 配完省略显示 (老板原话 "不写当前值 label")
            Picker("模型", selection: $llmModel) {
                ForEach(MiniMaxModel.allCases, id: \.self) { model in
                    Text(model.label).tag(model.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            // 占位 (后续添加快捷键真值)
            Text("快捷键配置 (待补)")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

/// v0.21 ticket 01 (重做 #7): 透明 helper view — 在 view tree 内捕获 @Environment(\.openSettings) OpenSettingsAction,
/// 注入到 WenshuAppDelegate.openSettings 静态字段, NSMenu "设置…" action 调 closure 弹 SwiftUI Settings { { } Scene
/// (Stack Overflow 65355696 + orchetect/SettingsAccess 真值)
private struct SettingsEnvironmentCapturer: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        LayoutShellView()
            .onAppear { WenshuAppDelegate.openSettings = openSettings }
    }
}

// v0.21 ticket 01 (重做 #10): 删 SettingsEnvironmentCapturer (Q15 翻车链 #11 dead code) + VibeMeter Mirror reflection NSApp.openSettings extension (Q15 翻车链 #12 dead code)
// Spec sub-agent 报告 (deleg_10289a6b): installMainMenu 装 6 项 + 自创建 NSWindow 装 SettingView = 真稳方案
// Settings { } Scene 留着 (ticket 04 commit 984ea556b 已装 模型 Picker, 老板 8/21 拍 "配完省略显示")

/// AppDelegate: WenshuCore runtime + macOS app init
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    // v0.21 ticket 01 (重做 #7): 持 SwiftUI 14+ OpenSettingsAction (LayoutShellView .onAppear 注入, OpenSettingsAction.callAsFunction() 触发)
    nonisolated(unsafe) static var openSettings: OpenSettingsAction?

    static let sharedRuntime = AgentRuntime()
    static let sharedVerifier = MiniMaxVerifier()
    static let sharedChatStore: ChatSessionStore? = {
        // v0.21 ticket 06: actor init 不能在 static let 闭包里直接调用 (Swift 6 strict concurrency)
        // 退回 nil, applicationDidFinishLaunching 重新创建并赋值给 var sharedChatStore
        return nil
    }()
    static nonisolated(unsafe) var sharedConductor: WenshuConductor?

    static nonisolated(unsafe) var sharedChatStoreRef: ChatSessionStore?  // code-review H1 修法: 用 unsafe var 替代 let nil

    static let sharedkanbanStore: KanbanStore? = nil  // 同上, 在 applicationDidFinishLaunching 赋值

    // v0.21 ticket 01 (重做 #7): "显示" → "恢复默认布局" NSMenu action (Q28 真值: 走 NSMenu 自己装中文 6 项, 不靠 SwiftUI commands 范式)
    @MainActor @objc func resetLayout(_ sender: Any?) {
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
    }

    // v0.21 ticket 01 (重做 #10): "设置…" NSMenu action — 自己创建 NSWindow + NSHostingController 装 SettingView (commit e0c204fea 真值, 加 SettingView 内容修法)
    // Q32 audit 真因 (Spec sub-agent report 候选 b 修正): commit 9cb2ad0f0 "撤回 NSMenu 装" 让 SwiftUI 默认接管 cmd+, 但 SwiftUI 默认 Settings Scene 弹空白 sheet (SettingView 没装进 SwiftUI 自动接管的 sheet).
    // 真修法: installMainMenu 装 "设置…" item + 自创建 NSWindow 装 SettingView (NSHostingView), sheet 浮在原 windows (Apple 真值 modal悬浮 sheet 行为).
    @MainActor @objc func openSettingsWindow(_ sender: Any?) {
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "wenshu.settings" }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "文枢 设置"
        settingsWindow.identifier = NSUserInterfaceItemIdentifier("wenshu.settings")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()
        settingsWindow.contentView = NSHostingView(rootView: SettingView())
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    /// v0.21 ticket 01 (重做): installMainMenu 装 6 项中文 (v0.02.0 spec 老板 8/10 01:43 拍: 文枢/文件/编辑/显示/窗口/帮助)
    /// Apple 官方范式: SwiftUI 不自动装 File/Edit/View/Window/Help 系统级菜单, 老板 macOS 27 系统语言中文 → NSMenu title 中文
    /// 真因 (Q28 查 SwiftUI 真值 + Apple Forum 695325): Settings { } Scene 自动注册 cmd+, Settings NSMenuItem 在 macOS 27 由 SwiftUI 接管,
    /// 我们装 '设置…' action 走 showSettingsWindow @objc (NSApp.sendAction dispatch 'showSettingsWindow:' selector, SwiftUI 已注册 target)
    @MainActor private func installMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // 文枢 (App menu) — v0.21 ticket 01 (重做 #10): '设置…' action 接 openSettingsWindow 自定义 @objc
        // (Q32 audit Spec sub-agent 真因: SwiftUI 默认接管 Settings { } Scene 弹空白 sheet, installMainMenu 必须装 + 自创建 NSWindow 装 SettingView 真值)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "文枢")
        appMenu.addItem(NSMenuItem(title: "关于文枢", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "设置…", action: #selector(openSettingsWindow(_:)), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出文枢", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 文件 (cmd+N 新建项目)
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(NSMenuItem(title: "新建项目", action: nil, keyEquivalent: "n"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 编辑 (cmd+Z 撤销 / cmd+shift+Z 重做, 走 first responder 自动 enable/disable)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 显示 (含 "恢复默认布局" 接 resetLayout NotificationCenter)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(NSMenuItem(title: "恢复默认布局", action: #selector(resetLayout(_:)), keyEquivalent: "R"))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 窗口
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 帮助
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "帮助")
        helpMenu.addItem(NSMenuItem(title: "文枢帮助", action: nil, keyEquivalent: ""))
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        // NSApplication 用来定位 Window / Help 菜单 (v0.20 ticket 08 老真值, 保留)
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu

        return mainMenu
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // v0.21 ticket 01 (重做 #9): 不装 NSMenu — 让 macOS 27 SwiftUI 默认装 (老板 8/21 17:50 拍"原厂所有都亮出来, 系统自动本地化")
        // Q15 翻车链 #12 总结: 我们 NSMenu 自己装 6 项中文 + VibeMeter Mirror reflection + OpenSettingsAction capture 全失败.
        // 撤回整个 NSMenu 装路径, 让 SwiftUI App body 默认 Settings { } Scene + WindowGroup + 标准 commands 自动接管 NSMenu.
        // Settings { } Scene 自动装 'Settings…' NSMenuItem (macOS 14+ 真值, VibeMeter 真值)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // v0.21 ticket 06: 同步创建 ChatSessionStore + KanbanStore + WenshuConductor (不能在 static let 闭包里调 actor init)
        // 用 unsafeMutablePointer / 临时 instance var 临时持有 — 因为 static let 是 immutable, 不能后续赋值
        let chatStore: ChatSessionStore?
        do {
            let store = try ChatSessionStore()
            try store.bootstrap()
            chatStore = store
        } catch {
            chatStore = nil
        }
        Self.sharedChatStoreRef = chatStore  // code-review H1 修法
        let kanbanStore: KanbanStore?
        do {
            let store = try KanbanStore()
            try store.bootstrap()
            kanbanStore = store
        } catch {
            kanbanStore = nil
        }
        if let kanbanStore = kanbanStore {
            Self.sharedConductor = WenshuConductor(
                runtime: Self.sharedRuntime,
                verifier: Self.sharedVerifier,
                kanbanStore: kanbanStore,
                sessionStore: chatStore
            )
        }
        // v0.21 ticket 01 (重做 #10): applicationDidFinishLaunching 末尾强制装中文 6 项 NSMenu (commit 9f77ffa9c 真值)
        // Q32 audit 真因 (Spec sub-agent report): 撤回 commit 9cb2ad0f0 "撤回 NSMenu 装" 路径反而破坏菜单栏 (老板 17:00 反馈 "缺编辑项 + 显示缺恢复布局" still reproduces today)
        // 真值真值: installMainMenu() 函数本身已经定义正确 6 项 (commit 9f77ffa9c L343-399), 但 commit 9cb2ad0f0 撤回调用 → dead code
        // 修法: 撤回 commit 9cb2ad0f0, 重新装 applicationDidFinishLaunching 末尾 NSApp.mainMenu = installMainMenu()
        // 同时删 SettingsEnvironmentCapturer (Q15 翻车 #11 dead code) + VibeMeter Mirror reflection NSApp.openSettings extension (Q15 翻车 #12 dead code)
        // Settings { } Scene 留着 (ticket 04 commit 984ea556b 已装 模型 Picker, 老板 8/21 拍 "配完省略显示")
        NSApp.mainMenu = installMainMenu()
        // v0.20 ticket 01: 启动时注册 wenshu 主 agent (左下 zone chat UI 调用)
        let card = AgentCard(
            name: "wenshu",
            description: "wenshu 本地主 agent, 接 MiniMax key, 支持 chat UI",
            skills: ["chat", "memory", "kanban"],
            endpoint: "in-process://wenshu"
        )
        let protocol_ = AgentProtocol(agentCard: card, verifier: Self.sharedVerifier)
        Task { @MainActor in
            await Self.sharedRuntime.register(AgentRegistration(
                name: "wenshu", card: card, process: protocol_
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}


// MARK: - 6 区 layout shell (1:1 落 6 master) — v0.15 Apple HIG 重写
//
// 老板 2026-08-19 拍板: 改 Canvas 重画 → 改 Apple HIG 真值范式 HStack + ZoneModule + NativeSplitter(view)
// 标题栏: 删自写 TitleBarZone (Canvas 重画 + macOS .titleBar chrome 双层), 走 macOS 52 PT unified chrome
// 区域组件: 全用 ZoneModule (顶栏 ZoneTopToolbar + 内容 + 底栏 ZoneBottomToolbar), 不再 Canvas + SwiftUI overlay 混搭
// 拖拽线: 全用 NativeSplitter(view) (DragGesture + .pointerStyle + hover 4 PT accent capsule), 不再 NSView hit area
//
// 真值选择 (老板 2026-08-19 ticket 005 改 comment):
// - 不用 Apple HSplitView / VSplitView (官方 macOS 10.15+ Split Views), 公开已知限制 = divider 颜色改不了
//   参考: developer.apple.com/design/human-interface-guidelines/split-views (NSSplitView 不是 SwiftUI Split Views 真值)
// - 不用 NavigationSplitView (3 列导航范式, 跟 Sketch 6 区布局不对应)
// - 用 HStack + 自写 NativeSplitter(view): DragGesture + .pointerStyle(.columnResize / .rowResize) + hover 4 PT accent capsule
//   Apple HIG 官方 API: developer.apple.com/documentation/swiftui/pointerstyle
// - 标题栏走 macOS .windowStyle(.titleBar) 52 PT unified chrome (Apple HIG standard titlebar)

struct LayoutShellView: View {
    /// v0.10.1 拖拽交互: VM 持有 6 个 offset (5 竖 + 1 横), 6 splitter 的 onDrag 调 vm.adjust*
    @State private var vm = LayoutShellViewModel()

    var body: some View {
        // GeometryReader 拿窗口实际尺寸, 比例算子 × 实 PT = 任何窗口大小 1:1 自适应 (Apple HIG responsive)
        // macOS .titleBar 52 PT chrome 由 WindowGroup windowStyle 提供 (老板 2026-08-19 拍不写自定标题栏)
        // 不加 fixed frame + 不加 max(...) floor (v0.15 ticket 005 修响应式 bug)
        GeometryReader { proxy in
            let totalW = proxy.size.width
            let contentH = proxy.size.height  // NSWindow.contentRect (已扣 macOS chrome 52 PT, 由 .windowStyle(.titleBar) 提供)
            // v0.15 ticket 021 修: 老板 2026-08-19 拍 "除非要求硬编码的地方, 不要用 PT 写界面框架, 用比例写"
            //   死原则: 52 (macOS chrome 由 .windowStyle(.titleBar) 提供) + 932 (contentH) = 984
            //   932 = 上半 + 拖拽线 + 下半, 上半 = 下半 = (932 - 2) / 2 = 465 PT
            //   D_h 拖拽线 = 2 PT (Sketch master 真值, 老板 2026-08-19 用 mcp__sketch__run_code 读图确认)
            //   bandH 用比例算子 vm.upperBandH(totalHeight: contentH - 2) (ticket 014 D_h 响应 + 比例算子, -2 留给 D_h 拖拽线)
            let bandH = vm.upperBandH(totalHeight: contentH - 2)
            VStack(spacing: 0) {
                // 上 band: 4 区 + 3 拖拽线 (Apple HIG HStack 范式)
                UpperBandZone(vm: vm, totalW: totalW, bandH: bandH)
                // D_h 横拖拽线 (上/下 band 之间, v0.14.0 撤销 inert, 拍可拖)
                NativeSplitter(orientation: .horizontal, length: totalW, onDrag: { dy in
                    vm.adjustBandSplit(delta: dy, totalHeight: contentH - 2)
                })
                // 下 band: 2 区 + 1 拖拽线 (老板 8/18 拍 "上四下两")
                LowerBandZone(vm: vm, totalW: totalW, bandH: vm.lowerBandH(totalHeight: contentH - 2))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .wenshuResetLayout)) { _ in
            vm.reset()
        }
    }
}

/// 6 个 NativeSplitter NSView overlay (拖拽 hit area, Canvas 之外处理 mouse event)
/// v0.15 ticket 006 删 (老板 2026-08-19 改 Canvas 重画 → 删死代码 MARK 残留)

// MARK: - Splitter helper (ticket 006 P3-3 表驱动 adjust, 抽 1 组件避免 Shotgun Surgery)
// 5 个竖拖拽线 (D_v1/D_v2/D_v3/D_v5) 共享同一签名 (orientation, length, splitterIndex),
// 内部调 vm.adjust(_:delta:totalWidth:) 表驱动, 改 1 处 = 5 竖拖拽线全响应.
// D_h 横拖拽线在 LayoutShellView 直接用 NativeSplitter(.horizontal, ...) 调 vm.adjustBandSplit.

struct VSplitter: View {
    let length: CGFloat
    let totalWidth: CGFloat
    let splitterIndex: Int  // 0=D_v1 项目侧栏/预览, 1=D_v2 预览/编辑器, 2=D_v3 编辑器/工具, 4=D_v5 聊天/动态
    let vm: LayoutShellViewModel
    var body: some View {
        NativeSplitter(orientation: .vertical, length: length) { dx in
            vm.adjust(splitterIndex, delta: dx, totalWidth: totalWidth)
        }
    }
}

// MARK: - 上 band (小说管理区): 4 区域模块 + 3 拖拽线-竖 (Apple HIG HStack 范式)

struct UpperBandZone: View {
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        // v0.15 ticket 022.5: 撤回 ticket 022 .containerRelativeFrame (写死宽度, 不能拖拽)
        //   老板 2026-08-19 拍: "要能实现拖拽, 要能实现比例, 因为 windows 还要能调整大小, 等到 windows 实现调整大小后, 整个框架也要自适应, 你写成硬编码的宽度, 不法实现"
        //   修法: 改回 LayoutTokens.ratio * totalW (比例写死, 但响应 resize 因为用 totalW * ratio, VSplitter 改 offsets 影响宽度)
        let sidebar = totalW * CGFloat(vm.projectSidebarRatio)
        let preview = totalW * CGFloat(vm.projectPreviewRatio)
        let editor  = totalW * CGFloat(vm.editorWRatio)
        let tools   = totalW * CGFloat(vm.toolsWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .projectSidebar, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: sidebar)
            // D_v1: 项目侧栏 / 项目预览 (splitterIndex 0)
            VSplitter(length: bandH, totalWidth: totalW, splitterIndex: 0, vm: vm)
            ZoneModule(slot: .projectPreview, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: preview)
            // D_v2: 项目预览 / 编辑器 (splitterIndex 1)
            VSplitter(length: bandH, totalWidth: totalW, splitterIndex: 1, vm: vm)
            ZoneModule(slot: .editor, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: editor)
            // D_v3: 编辑器 / 专用工具 (splitterIndex 2)
            VSplitter(length: bandH, totalWidth: totalW, splitterIndex: 2, vm: vm)
            ZoneModule(slot: .specializedTools, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: tools)
        }
        .frame(height: bandH)  // 显式告诉 SwiftUI VStack layout 上 band 高度, 响应 vm.bandOffset mutate
    }
}

// MARK: - 下 band (聊天管理区): 2 区域模块 + 1 拖拽线-竖 (Apple HIG HStack 范式)

struct LowerBandZone: View {
    /// 老板 8/18 拍 "上四下两" = 下 band 2 区: AI聊天 (整宽 1518 PT) + AI 动态 (400 PT)
    /// 1 拖拽线 D_v5 (x=1518, AI聊天 / AI 动态)
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        // v0.15 ticket 022.5: 撤回 ticket 022 (改回 LayoutTokens.ratio * totalW)
        let aiChatW = totalW * CGFloat(vm.aiChatRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .aiChat, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: aiChatW)
            // D_v5: AI 聊天 / AI 动态 (splitterIndex 4)
            VSplitter(length: bandH, totalWidth: totalW, splitterIndex: 4, vm: vm)
            ZoneModule(slot: .aiDynamic, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: dynamicW)
        }
        .frame(height: bandH)  // 显式告诉 SwiftUI VStack layout 下 band 高度, 响应 vm.bandOffset mutate, 反方向守恒
    }
}

// MARK: - 6 master 1:1 落 SwiftUI 子组件

/// 区域顶/底栏共享 icon 占位渲染 (老板 8/18 拍 "用 SF 替换矩形" → 矩形 = 占位标记, 用 SF Symbol 替换)
/// 老板 2026-08-19 拍 "我的蓝色占位矩形,用 SF ICON 替代" → SF Symbol Image 直接替
/// v0.14.5: 重写 ZoneIcon helper, 顶栏 3 SF Symbol + 底栏占位 SF Symbol = 全部 SF Symbol
/// 老板 8/18 拍 "画矩形占位, 帮我用 SF 占位替换" → SF Symbol Image 不是 ShapePath 矩形
struct ZoneIcon: View {
    let systemName: String
    let size: CGFloat
    var body: some View {
        // 老板 8/18 拍 SF Symbol 替换矩形占位
        // v0.15 ticket 017.5 修: 老板 2026-08-19 拍 "SF Symbol 应该是字号, 不是尺寸"
        // 只用 .font(.system(size:)) 给字号, 不用 .frame 约束尺寸
        // SF Symbol 字号 18 PT 视觉占 SF Symbol 默认 padding (~16 PT 视觉), 不撑 18×18 框
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(DesignColor.accentBlue)
    }
}

/// 区域顶部工具栏: 30 PT 高, 3 SF Symbol 占位 + 占位文字 + 底 2 PT 分割线.
/// 宽度由父组件约束自动撑到区域模块宽度 (不画穿 splitter).
struct ZoneTopToolbar: View {
    let iconNames: [String]

    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight  // 30 PT
        // 顶栏背景: 撑满父级宽度 (区域模块宽), 高度 30 PT
        DesignColor.zoneSurface
            .frame(height: toolbarH)
            .overlay(alignment: .topLeading) {
                // 3 SF Symbol icon: 起点 y=6, 间距 9 PT
                HStack(spacing: 9) {
                    ForEach(0..<iconNames.count, id: \.self) { i in
                        ZoneIcon(systemName: iconNames[i], size: 18)
                    }
                }
                .padding(.leading, 18)
                .padding(.top, 6)
            }
            .overlay(alignment: .topTrailing) {
                // 占位文本: 右上角, 字号 13, 顶 8 PT, 右 padding 18 PT
                Text("占位文字")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 18)
                    .padding(.top, 8)
                    .frame(height: toolbarH, alignment: .topTrailing)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                // 底分割线 1 PT (跟拖拽线 / StaticDivider 一致)
                DesignColor.splitterLine.frame(height: 1)
            }
    }
}

/// 区域底部工具栏: 30 PT 高, 左/右各占位文字 + 顶 2 PT 分割线.
/// 宽度由父组件约束自动撑到区域模块宽度 (不画穿 splitter).
struct ZoneBottomToolbar: View {
    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight  // 30 PT
        // 底栏背景: 撑满父级宽度 (区域模块宽), 高度 30 PT
        DesignColor.zoneSurface
            .frame(height: toolbarH)
            .overlay(alignment: .top) {
                // 顶分割线 1 PT (跟拖拽线 / StaticDivider 一致)
                DesignColor.splitterLine.frame(height: 1)
            }
            .overlay(alignment: .bottomLeading) {
                // 左占位文字: 字号 13, 左 padding 18, 距底 6 PT
                Text("占位文字")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 18)
                    .padding(.bottom, 6)
                    .frame(height: toolbarH, alignment: .bottomLeading)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                // 右占位文字: 字号 13, 右 padding 18, 距底 6 PT
                Text("占位文字")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 18)
                    .padding(.bottom, 6)
                    .frame(height: toolbarH, alignment: .bottomTrailing)
                    .allowsHitTesting(false)
            }
    }
}

/// Master 4: 区域模块 (顶 30 + 内容 + 底 30 = 472 PT, 接受 6 slot)
struct ZoneModule: View {
    let slot: ZoneSlot
    let vm: LayoutShellViewModel
    let totalW: CGFloat  // 父 band 宽, 算比例
    let bandH: CGFloat
    @Environment(WenshuLibrary.self) private var library

    private var toolbarH: CGFloat { LayoutTokens.toolbarHeight }  // v0.15 ticket 008: 老板 Sketch 真值 30 PT 1:1 硬编码
    /// 老板 8/18 Q2 答: 4 PT inset = 单一垂直方向 (spec §3.2 "背景 y=60~884, 正文 y=64~882", 上下 4 PT 视觉下沉, 左右 flush)
    /// v0.15 ticket 005 改名: editorInsetRatio → editorVerticalInsetRatio (明确垂直方向)
    private var editorInset: CGFloat { bandH * LayoutTokens.editorVerticalInsetRatio }  // 4 PT 单一垂直
    // v0.10.8: 撤掉 chatInputW/H 私有属性, 老板 8/18 拍 "新图没画聊天输入框"
    private var innerBandH: CGFloat { bandH - 2 * toolbarH }  // 顶栏底栏间内容区

    var body: some View {
        // 区域模块 = 顶栏 (上) + 内容区 (中) + 底栏 (下).
        // 顶/底栏宽度不写死, 由 VStack 子 view 默认 stretch 撑到区域模块宽度 (不画穿 splitter).
        // 内容区撑满剩余空间.
        VStack(spacing: 0) {
            ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
                .frame(height: toolbarH, alignment: .top)  // 顶栏高度 30 PT
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ZoneBottomToolbar()
                .frame(height: toolbarH, alignment: .bottom)  // 底栏高度 30 PT
        }
        // 内容区背景色: 动态区用更深的底色
        .background(slot == .aiDynamic ? DesignColor.dynamicZoneSurface : .clear)
    }

    @ViewBuilder
    private var content: some View {
        // v0.15 ticket 005 范式: 每个 case 自己 Color + overlay (跟 ticket 005 一样, ticket 006 撤回 P3-4)
        switch slot {
        case .projectSidebar:
            // 项目侧栏嵌入 WenshuLibrary 真实内容 (LIBRARY overlay label v0.10.10d 删)
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                LibraryOutlineViewContent(library: library)
            }
        case .projectPreview:
            DesignColor.zoneSurface
        case .editor:
            // 老板 8/18 Q2 答: 4 PT inset 两层设计, 单一垂直方向 (spec §3.2 背景 y=60~884, 正文 y=64~882, 上下 4 PT 视觉下沉, 左右 flush)
            // v0.15 重写前 bug: .padding(editorInset) 是全 4 方向 inset, 破左右 flush 设计意图 → 改 [.top, .bottom] 单垂直
            DesignColor.zoneSurface
                .overlay {
                    Color.white.opacity(0.55)
                        .padding([.top, .bottom], editorInset)
                }
        case .specializedTools:
            DesignColor.zoneSurface
        case .aiChat:
            // v0.21 ticket 06: 接入 ChatView (左下 zone 真 chat UI + Agent 对话) + 集成 conductor + chat store
            ChatView(
                conductor: WenshuAppDelegate.sharedConductor,
                store: WenshuAppDelegate.sharedChatStoreRef
            )
        case .aiDynamic:
            DesignColor.zoneSurface
        }
    }
}

/// 6 instance 槽位 (boss Sketch 组件化 6 master 派生)
/// 6 个 instance 槽位 (老板 8/18 组件化 6 master 派生; v0.10.3 下 band 拆 chatSidebar + chatDialogue 2 子区)
enum ZoneSlot {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case aiChat        // 老板 8/18 拍 "上四下两", 下 band 整宽 AI聊天 (含原 v0.10.3 拆的 chatSidebar + chatDialogue)
    case aiDynamic
}

// MARK: - Library outline (项目侧栏嵌入)

/// 项目侧栏内容 (WenshuLibrary 真实内容)
/// v0.10.10d 删 LIBRARY overlay label (老板 8/18 拍 "对齐了, 不用文字标签")
/// v0.15 ticket 005: 删 LibraryOutlineViewContent.libraryHeader 死代码 + 改 comment
struct LibraryOutlineViewContent: View {
    let library: WenshuLibrary
    var body: some View {
        LibraryOutlineView(library: library)
            .padding(.vertical, 2)
            .padding(8)
            .allowsHitTesting(false)
    }
}

