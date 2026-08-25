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
    // v0.24 boss验收fix: notify when ProviderKeychain changes (Settings save key).
    static let wenshuProviderKeychainChanged = Notification.Name("com.wenshu.providerKeychainChanged")
    // v0.24 boss验收fix (Boss 8/24): chat store ready notification.
    // Posted after applicationDidFinishLaunching creates ChatSessionStore.
    // ChatView listens and reloads history when received (= retry load).
    static let wenshuChatStoreReady = Notification.Name("com.wenshu.chatStoreReady")
    // v0.24 boss验收fix: defocus chat input when user clicks outside.
    static let wenshuDefocusChatInput = Notification.Name("com.wenshu.defocusChatInput")
    // (Removed: .wenshuUserAddressChanged — Spec axis GAP review confirmed no
    // consumers, dead code. WenshuConductorIdentity.userAddress reads UserDefaults
    // fresh at LLM call time = automatic dynamic propagation, no event needed.)
}

// MARK: - Layout tokens (比例算子 0~1, 老板 8/18 答 "1:1 PT 真值" + 8/18 再拍 "换算成比例")
//
// 数据源: Sketch AF7B1C87 / Artboard 首页 1920×984 PT 1:1 落
// 公式: layoutPT(token) = totalW * ratio (e.g. projectSidebar ratio = 200/1920 = 0.1042)
// Apple HIG responsive: GeometryReader 拿窗口实际尺寸 × 比例 = 任何窗口大小 1:1 自适应

/// Apple Semantic Color — 全 dark mode 适配, 0 RGB 硬编码 (DesignTokens.swift v0.10.6 移到 App.swift)
enum DesignColor {
    /// 标题栏 (老板 Sketch #393939) → NSColor.windowBackgroundColor
    static let titleBar: Color = Color(nsColor: .windowBackgroundColor)
    /// 内容区底色 (老板 Sketch #202020) → NSColor.controlBackgroundColor
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
    // v0.24 fix (Boss 8/25 45th + 46th OOB '默认宽度按1000, 上四栏比例20 20 40 20'):
    // changed base from 1920 to 1000 (= per Boss 46th OOB).
    // Upper band 4 zones (20/20/40/20 = 100% total):
    static let projectSidebarRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    static let projectPreviewRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    static let editorWRatio: CGFloat = 400.0 / 1000.0         // 40% (= Boss 45th OOB)
    static let toolsWRatio: CGFloat = 200.0 / 1000.0         // 20% (= Boss 45th OOB)

    // v0.24 fix (Boss 8/25 41st OOB 'originally 400, check official docs to fix visual width mismatch'):
    // Boss clarified: upper-right (specializedTools) and lower-right (aiDynamic)
    // original design both = 400 PT.
    // My previous commit b8d8c04a8 incorrectly changed dynamicWRatio to 1194
    // (= Boss 38th OOB misinterpretation, Boss 41st OOB clarified = originally 400).
    // Revert dynamicWRatio 1194 -> 400, aiChatRatio 726 -> 1518 (= back to
    // original 8/18 design values).
    // Real problem = same 400 PT visually different widths (= need to check
    // official docs for proper fix).
    // v0.24 fix (Boss 8/25 44th OOB '代码宽度不对'): drop aiChatRatio 1518 -> 1514
    // to absorb 1 splitter hit area (1 × 6 PT = 6 PT). New sum = 1514+400
    // = 1914 + 6 splitter = 1920 PT (= exact window width, no HStack shrinkage).
    // v0.24 fix (Boss 8/25 45th + 46th OOB '下两栏比例80 20, 默认宽度按1000'):
    // Lower band 2 zones (80/20 = 100% total):
    static let aiChatRatio: CGFloat = 800.0 / 1000.0         // 80% (= Boss 45th OOB)
    static let dynamicWRatio: CGFloat = 200.0 / 1000.0       // 20% (= Boss 45th OOB)

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041


    // 顶栏色块比例 (老板 8/18 Q3 答: 22/82/142 起点 + 38 PT 宽 + 60 PT 等距)
    static let iconLeadingRatio: CGFloat = 18.0 / 1920.0  // 起点 18 PT (老板 8/18 改 18 PT, 旧 22 PT)
    static let iconSizeRatio: CGFloat = 12.0 / 1920.0     // 12 PT 边长 (老板 8/24 拍 '改成 12×12')
    // v0.24 boss验收fix (Boss 8/24): tab icon 12×12 PT.
    // Boss 拍 '改成 12×12 吧' (after 18×18 too big).
    static let iconSize: CGFloat = 12
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
        // v0.24 fix (Boss 8/25 17th OOB 'hide Wenshu title'): WindowGroup
        // title set to empty string (= no NSWindow title shown). Combined
        // with .windowToolbarStyle(.unified, showsTitle: false) below for
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // v0.21 ticket 01 (重做 #10): 撤回 SettingsEnvironmentCapturer wrapper (commit a78d758bc Q15 翻车 #11 dead code)
            // SettingsEnvironmentCapturer 之前包 LayoutShellView 注入 OpenSettingsAction, 但 openSettings?() → nil (Q15 翻车 #11), 现在 NSMenu 自己装 + 自创建 NSWindow 装 SettingView 不需要 capture
            SettingsEnvironmentCapturer(library: library, appearanceMode: appearanceMode)
        }
        // Boss 8/24 feedback: 'use the 52 PT one'. Apple SwiftUI macOS 14+ windowToolbarStyle
        // options: .automatic, .unified (52 PT), .unifiedCompact (28 PT), .expanded.
        // v0.24 fix (Boss 8/25 28th OOB 'use default size' + Apple docs):
        // use .unified (52 PT) = macOS default toolbar style. Per Apple
        // developer.apple.com/documentation/SwiftUI/WindowToolbarStyle,
        // .unified is the default style (52 PT). .unifiedCompact is
        // COMPACT (= smaller, NOT default). Boss spec 'default size' = .unified.
        .windowToolbarStyle(.unified(showsTitle: false))  // 52 PT default toolbar, title hidden
        .defaultSize(width: LayoutTokens.designW, height: LayoutTokens.designH)  // Boss Sketch design baseline 1920x984 PT
        // v0.24 boss验收fix: .contentMinSize (window doesn't shrink below initial
        // size, can grow to fit larger content).
        .windowResizability(.contentMinSize)
        .commands {
            // v0.24 boss验收fix: Settings... menu item (Cmd+,).
            // This is required for SwiftUI Settings scene to be accessible.
            // Without this, the menu has no Settings item and showSettingsWindow:
            // selector doesn't work.
            CommandGroup(replacing: .appSettings) {
                // v0.24 boss验收fix: tap menu item = trigger @Environment(\.openSettings).
                // The Button is a no-op body, but SwiftUI's Commands system
                // auto-wires this to the @Environment(\.openSettings) closure
                // captured by SettingsEnvironmentCapturer.
                Button("设置…") {
                    WenshuAppDelegate.openSettings?()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("新建项目", action: {})
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销", action: {})
                    .keyboardShortcut("z", modifiers: .command)
                Button("重做", action: {})
                    .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Divider()
                Button("恢复默认布局") {
                    NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingView()
        }
    }
}

/// 设置页: Pages 范式真值 (v0.21 ticket 06)
/// 老板 8/21 拍 'Pages 范式实现设置面板的 UI, 用 macOS 27 的组件'
/// = 顶部 toolbar (3 个 segmented tab, Pages 真值, 老板画的图 2 红框位置)
/// 不是 macOS Settings { } Scene 自动装标题栏 segmented tab 按钮 (commit 0082bd1fe + 030a58355 真硬违反)
/// Pages 真值 (红框位置) = 窗口内容顶部 toolbar 切换, 不是窗口标题栏按钮
struct SettingView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    // v0.24 boss验收fix (2026-08-24): default to empty string when no provider
    // key configured (not "MiniMax-M3" which implies a MiniMax provider is
    // selected even when user has no key). UI shows "暂无模型可用，请先配置模型" placeholder
    // when this is empty.
    @AppStorage("wenshu.llm.model") private var llmModel: String = ""
    @AppStorage("wenshu.llm.reasoningEffort") private var reasoningEffort: String = "medium"
    // v0.24 boss验收fix: @AppStorage so chat '设置' link can jump to provider tab.
    @AppStorage("wenshu.settingsTab") private var selectedTabRaw: String = "general"
    // v0.24 fix: Settings UI exposes user-set value for agent-to-user address.
    // WenshuConductorIdentity.userAddress reads this key at LLM call time.
    // Boss 8/24 clarification: default = 'user' (not 'boss' = hermes-side convention).
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"

    private var selectedTab: SettingsTab {
        get { SettingsTab(rawValue: selectedTabRaw) ?? .general }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    @State private var liveModelIds: [String] = []
    @State private var isLoadingModels = false
    @State private var providersWithKeys: Set<String> = []
    @State private var apiExpandedProviders: Set<String> = []
    @State private var apiDraftKey: String = ""
    @State private var apiError: String?

    var currentProvider: Provider {
        Provider.by(slug: providerSlug) ?? .minimaxCn
    }

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "通用"
        case providerApi = "提供方 API"
        case model = "模型"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .providerApi: return "key.horizontal"
            case .model: return "cpu"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 toolbar (Pages 范式, 老板画的图 2 红框位置): 3 个 segmented tab
            Picker("", selection: Binding(
                    get: { selectedTab },
                    set: { selectedTab = $0 }
                )) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .onChange(of: selectedTab) { _, new in
                if new == .providerApi { refreshProviderStatus() }
                if new == .model {
                    Task { await reloadModels() }
                }
            }

            Divider()

            // tab 内容 (Pages 范式, .formStyle(.grouped) 真值 Apple)
            Group {
                switch selectedTab {
                case .general: generalTab
                case .providerApi: providerApiTab
                case .model: modelTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTab)
        }
        .frame(width: 600, height: 480)
        .task { refreshProviderStatus() }
    }

    private func refreshProviderStatus() {
        providersWithKeys = Set(ProviderKeychain.listProvidersWithKeys())
    }

    private func selectProvider(_ p: Provider) {
        providerSlug = p.slug
        llmModel = p.defaultModels.first ?? WenshuLLMModel.m3.rawValue
        liveModelIds = []
        refreshProviderStatus()
    }

    private var modelIdList: [String] {
        liveModelIds.isEmpty ? currentProvider.defaultModels : liveModelIds
    }

    private func reloadModels() async {
        guard !isLoadingModels else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }
        let key = ProviderKeychain.loadKeySync(for: currentProvider) ?? ""
        let ids = await ProviderFetcher.loadModelIds(provider: currentProvider, apiKey: key)
        await MainActor.run { self.liveModelIds = ids }
    }

    private var generalTab: some View {
        // Pages 范式参考 UI, 不用管功能 (老板 8/21 拍 "参考 UI 用 Apple 标准, 不是让你做一个一样的通用设置")
        Form {
            Section("外观") {
                Picker("外观", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section("Agent user address") {
                // v0.24 fix (Boss 8/24 OOB): user-set value for agent-to-user address.
                // Read by WenshuConductorIdentity.userAddress at LLM call time
                // (dynamic per-chat). User cannot modify via chat per AGENTS.md.
                // Reason for no .onChange handler: WenshuConductorIdentity.
                // userAddress reads UserDefaults fresh each LLM call = automatic
                // dynamic propagation, no event-driven mechanism needed.
                TextField("Agent user address", text: $userAddress, prompt: Text("user"))
                    .textFieldStyle(.roundedBorder)
                Text("Agent (文枢) addresses you with this term. Default: user")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("通用设置") {
                Text("Pages 范式, 不用管功能")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var providerTab: some View {
        // Hermes 真值: 顶部 SearchField + List providers with status icon + "粘贴 X 密钥" 提示
        Form {
            Section {
                ForEach(Provider.all) { p in
                    HStack {
                        Image(systemName: providersWithKeys.contains(p.slug) ? "key.fill" : "key")
                            .foregroundStyle(providersWithKeys.contains(p.slug) ? .green : .secondary)
                            .frame(width: 16)
                        Text(p.name)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if providersWithKeys.contains(p.slug) {
                            Text("已设 key")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if p.requiresOAuth {
                            Text("粘贴 密钥")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if p.slug == "custom" {
                            Text("粘贴 密钥")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("粘贴 \(p.name) 密钥")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if p.slug == providerSlug {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectProvider(p)
                        if !providersWithKeys.contains(p.slug) && !p.requiresOAuth && p.slug != "custom" {
                            selectedTab = .providerApi
                            apiExpandedProviders.insert(p.slug)
                            apiDraftKey = ""
                            apiError = nil
                        }
                    }
                }
            } header: {
                Text("本地 / 自定义端点")
            } footer: {
                Text("将文枢 指向任意 OpenAI 兼容端点 (Zyphra, vLLM, llama.cpp, Ollama 等).")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
    }

    private var providerApiTab: some View {
        Form {
            Section {
                ForEach(Provider.all) { p in
                    Button {
                        toggleExpand(p: p)
                    } label: {
                        providerApiRow(p)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    if apiExpandedProviders.contains(p.slug) {
                        providerApiEditor(for: p)
                            .padding(.leading, 18)
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: apiExpandedProviders)
            } header: {
                Text("提供方")
            } footer: {
                let total = Provider.all.count
                let set = providersWithKeys.count
                Text("已设 key \(set) / \(total)")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshProviderStatus() }
    }

    private func toggleExpand(p: Provider) {
        if apiExpandedProviders.contains(p.slug) {
            apiExpandedProviders.remove(p.slug)
        } else {
            apiExpandedProviders.insert(p.slug)
            apiDraftKey = currentDraftPreview(for: p)
            apiError = nil
        }
    }

    private func bindingForExpanded(_ p: Provider) -> Binding<Bool> {
        Binding(
            get: { apiExpandedProviders.contains(p.slug) },
            set: { newValue in
                if newValue {
                    apiExpandedProviders.insert(p.slug)
                    apiDraftKey = currentDraftPreview(for: p)
                    apiError = nil
                } else {
                    apiExpandedProviders.remove(p.slug)
                }
            }
        )
    }

    private func currentDraftPreview(for provider: Provider) -> String {
        let hasKey = providersWithKeys.contains(provider.slug)
        guard hasKey else { return "" }
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { return "" }
        let prefix = String(key.prefix(8))
        return prefix + "********"
    }

    @ViewBuilder
    private func providerApiEditor(for p: Provider) -> some View {
        HStack(spacing: 8) {
            SecureField("sk-...", text: $apiDraftKey)
                .textFieldStyle(.roundedBorder)
            Button("保存") {
                saveApiKey(for: p)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(apiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .transition(.opacity)
        if let apiError {
            Text(apiError)
                .font(.caption)
                .foregroundStyle(.red)
                .transition(.opacity)
        }
    }

    private func providerApiRow(_ p: Provider) -> some View {
        let hasKey = providersWithKeys.contains(p.slug)
        return HStack(spacing: 12) {
            Image(systemName: hasKey ? "key.fill" : "key")
                .foregroundStyle(hasKey ? Color.green : Color.secondary)
                .frame(width: 18)
            Text(p.name)
                .font(.body)
            Spacer()
            if hasKey {
                Text(keyPrefix12(for: p))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Text("待配置")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private func keyPrefix12(for provider: Provider) -> String {
        guard let key = ProviderKeychain.loadKeySync(for: provider), !key.isEmpty else { return "" }
        return String(key.prefix(12))
    }

    private func saveApiKey(for provider: Provider) {
        let trimmed = apiDraftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try ProviderKeychain.saveKeySync(trimmed, for: provider)
            apiDraftKey = ""
            apiError = nil
            apiExpandedProviders.remove(provider.slug)
            refreshProviderStatus()
            // v0.24 boss验收fix: notify ChatZoneView (and other listeners) that
            // the keychain changed so they can refresh their model pickers without
            // requiring an app restart.
            NotificationCenter.default.post(
                name: .wenshuProviderKeychainChanged,
                object: nil,
                userInfo: ["slug": provider.slug]
            )
        } catch {
            apiError = "保存失败: \(error.localizedDescription)"
        }
    }

    private var modelTab: some View {
        Form {
            Section {
                Picker("提供方", selection: $providerSlug) {
                    ForEach(Provider.all) { p in
                        Text(p.name).tag(p.slug)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: providerSlug) { _, _ in
                    liveModelIds = []
                    Task { await reloadModels() }
                }

                Picker("模型", selection: $llmModel) {
                    ForEach(modelIdList, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("主模型")
            } footer: {
                Text("设置全局默认模型.")
                    .font(.caption)
            }

            Section {
                // v0.21 ticket 35b: 推理强度 picker aligned with Apple Anthropic API effort parameter (5 valid values per docs)
                // Source: https://platform.claude.com/docs/en/build-with-claude/effort
                // NOT hermes custom 7-level (purely decorative overlay, not API)
                Picker("默认推理强度", selection: $reasoningEffort) {
                    Text("低").tag("low" as String)
                    Text("中").tag("medium" as String)
                    Text("高").tag("high" as String)
                    Text("极高").tag("xhigh" as String)
                    Text("最高").tag("max" as String)
                }
                .pickerStyle(.menu)
                Text("EFFORT = Anthropic output_config.effort (low/medium/high/xhigh/max). 模型可用级别看 minimax 文档.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("推理")
            }

            Section {
                ForEach(AuxTask.allCases, id: \.self) { task in
                    HStack {
                        Image(systemName: task.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(task.label)
                            .font(.body)
                        Spacer()
                        Text("使用主模型")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("更改") {}
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .disabled(true)
                    }
                }
            } header: {
                Text("辅助模型")
            } footer: {
                Text("辅助任务默认使用主模型. 你可以为任意任务指定专用模型. (wenshu 真值: 辅助任务调度暂未实现, 占位显示 Hermes AUX_TASKS 真值列表)")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear { Task { await reloadModels() } }
    }

} 

/// 辅助任务 (Hermes AUX_TASKS 真值: vision/web_extract/compression/skills_hub/approval/mcp/title_generation/curator)
enum AuxTask: String, CaseIterable, Identifiable {
    case vision = "vision"
    case webExtract = "web_extract"
    case compression = "compression"
    case skillsHub = "skills_hub"
    case approval = "approval"
    case mcp = "mcp"
    case titleGeneration = "title_generation"
    case curator = "curator"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vision: return "视觉"
        case .webExtract: return "网页提取"
        case .compression: return "压缩"
        case .skillsHub: return "技能中心"
        case .approval: return "审批"
        case .mcp: return "MCP"
        case .titleGeneration: return "标题生成"
        case .curator: return "馆长"
        }
    }

    var icon: String {
        switch self {
        case .vision: return "eye"
        case .webExtract: return "globe"
        case .compression: return "arrow.down.right.and.arrow.up.left"
        case .skillsHub: return "wand.and.stars"
        case .approval: return "checkmark.shield"
        case .mcp: return "puzzlepiece"
        case .titleGeneration: return "textformat"
        case .curator: return "tray.full"
        }
    }
}

/// 提供方 key 输入提示 (走 NSWindow standalone sheet 范式, 跟 commit e45fac768 promptForLLMKeyIfNeeded 一致)
enum ProviderKeyPrompt {
    @MainActor
    static func prompt(for provider: Provider) {
        var enteredKey = ""
        let keyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        keyWindow.title = "填 \(provider.name) Key"
        keyWindow.identifier = NSUserInterfaceItemIdentifier("wenshu.providerkey.\(provider.slug)")
        keyWindow.isReleasedWhenClosed = false
        keyWindow.center()

        let binding = Binding<String>(
            get: { enteredKey },
            set: { enteredKey = $0 }
        )
        let rootView = ProviderKeyInputSheet(
            providerName: provider.name,
            key: binding,
            onSave: {
                let key = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { return }
                do {
                    try ProviderKeychain.saveKeySync(key, for: provider)
                    keyWindow.close()
                } catch {
                    NSLog("[wenshu.provider] save failed: \(error)")
                }
            },
            onLater: { keyWindow.close() }
        )
        keyWindow.contentView = NSHostingView(rootView: rootView)
        keyWindow.makeKeyAndOrderFront(nil)
    }
}

private struct ProviderKeyInputSheet: View {
    let providerName: String
    @Binding var key: String
    let onSave: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("填 \(providerName) API Key")
                .font(.headline)
            Text("存 macOS Keychain (不入文件 / log / commit)")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("sk-...", text: $key)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)
            HStack {
                Spacer()
                Button("稍后", action: onLater).keyboardShortcut(.cancelAction)
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 220)
    }
}

/// v0.21 ticket 01 (重做 #7): 透明 helper view — 在 view tree 内捕获 @Environment(\.openSettings) OpenSettingsAction,
/// 注入到 WenshuAppDelegate.openSettings 静态字段, NSMenu "设置…" action 调 closure 弹 SwiftUI Settings { { } Scene
/// (Stack Overflow 65355696 + orchetect/SettingsAccess 真值)
// v0.24 boss验收fix (2026-08-24): accept library + appearanceMode so it can
    // wrap LayoutShellView with the same modifiers as the original WindowGroup.
private struct SettingsEnvironmentCapturer: View {
    @Environment(\.openSettings) private var openSettings
    let library: WenshuLibrary
    let appearanceMode: AppearanceMode
    var body: some View {
        // v0.24 boss验收fix (Boss 8/24 OOB 拍 '和 FCP 一样, 首次运行, 无论
        // 是否要建书架, 都要先指定一个 .ws 文件的库文件位置'): first-launch
        // .ws file picker. NSOpenPanel for selecting .ws file location
        // (FCP-style Event Library UX). Save to UserDefaults wenshu.libraryPath.
        // WenshuWorkspace is initialized with the picked path (WenshuWorkspace
        // path already supports custom URL via init).
        //
        // LibraryRootView is a wrapper that:
        // 1. Checks UserDefaults wenshu.libraryPath
        // 2. If not set, shows NSOpenPanel to pick .ws file
        // 3. If set, just renders LayoutShellView
        // 4. All file I/O (chat / kanban / books / etc.) goes through .ws
        //    subdirectories (shelves/, books/, chat/, kanban/, todo/, assets/)
        //    = WenshuWorkspace manages this layout.
        LibraryRootView()
            .frame(minWidth: 1280, minHeight: 720)
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            .onAppear { WenshuAppDelegate.openSettings = openSettings }
            // v0.24 boss验收fix: Apple macOS 52 PT toolbar chrome via
            // .toolbar { ToolbarItem(placement: .principal) }.
            // Boss 8/24 拍: '用 52 的那个'.
            // - .windowToolbarStyle(.unified) (= 52 PT chrome) is applied at WindowGroup level
            // - but .toolbar content is needed to actually render the toolbar area at 52 PT.
            // - ToolbarItem(placement: .principal) puts '文枢' title in the center.
            // v0.24 boss验收fix (Boss 8/25 tenth OOB ticket 015.023):
            // toolbar buttons moved to LayoutShellView body (= this
            // outer view doesn't have access to vm; inner view does).
    }
}

// v0.21 ticket 01 (重做 #10): 删 SettingsEnvironmentCapturer (Q15 翻车链 #11 dead code) + VibeMeter Mirror reflection NSApp.openSettings extension (Q15 翻车链 #12 dead code)
// Spec sub-agent 报告 (deleg_10289a6b): installMainMenu 装 6 项 + 自创建 NSWindow 装 SettingView = 真稳方案
// Settings { } Scene 留着 (ticket 04 commit 984ea556b 已装 模型 Picker, 老板 8/21 拍 "配完省略显示")

/// AppDelegate: WenshuCore runtime + macOS app init
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    // v0.24 boss验收fix (Boss 8/25 OOB Spec axis GAP): one-time migration
    // from legacy chat.sqlite to warehouse. Preserves chat history when
    // user first picks a .ws warehouse in onboarding (= avoids silent data loss).
    // Idempotent: if legacy file doesn't exist or new file already exists, skip.
    private static func migrateLegacyChatIfNeeded(warehousePath: String, chatDbPath: String?) {
        guard let chatDbPath = chatDbPath else { return }
        let fm = FileManager.default
        // Legacy path: ~/Library/Application Support/wenshu/chat.sqlite
        guard let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
                .appendingPathComponent("wenshu", isDirectory: true)
                .appendingPathComponent("chat.sqlite") else {
            return
        }
        // Skip if legacy file doesn't exist
        guard fm.fileExists(atPath: appSupport.path) else { return }
        let newURL = URL(fileURLWithPath: chatDbPath)
        // Skip if new file already exists (= no overwrite)
        guard !fm.fileExists(atPath: newURL.path) else { return }
        // Ensure warehouse directory exists
        let warehouseDir = (chatDbPath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: warehouseDir) {
            try? fm.createDirectory(atPath: warehouseDir, withIntermediateDirectories: true)
        }
        // Copy legacy → warehouse
        do {
            try fm.copyItem(at: appSupport, to: newURL)
            NSLog("[wenshu.chatStore] migrated legacy chat.sqlite to %@", chatDbPath)
        } catch {
            NSLog("[wenshu.chatStore] legacy chat migration FAILED: %@", String(describing: error))
        }
    }

    
    // v0.21 ticket 01 (重做 #7): 持 SwiftUI 14+ OpenSettingsAction (LayoutShellView .onAppear 注入, OpenSettingsAction.callAsFunction() 触发)
    nonisolated(unsafe) static var openSettings: OpenSettingsAction?

    static let sharedRuntime = AgentRuntime()
    static let sharedVerifier = WenshuVerifier()
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


    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // v0.21 ticket 06: 同步创建 ChatSessionStore + KanbanStore + WenshuConductor (不能在 static let 闭包里调 actor init)
        // 用 unsafeMutablePointer / 临时 instance var 临时持有 — 因为 static let 是 immutable, 不能后续赋值
// v0.24 boss验收fix (Boss 8/24 反馈 '聊天记录持久化, 我没看到'):
        // add NSLog for chat store init + bootstrap errors (silent catch 之前
        // makes debugging hard), and post .wenshuChatStoreReady notification
        // so ChatView can retry load when store becomes available.
        // v0.24 boss验收fix (Boss 8/25 OOB '你的会话记录是存在 .ws 文件里吗'):
        // ChatSessionStore location = wenshu warehouse (anbaiqiang.ws/) if set,
        // else fall back to legacy ~/Library/Application Support/wenshu/chat.sqlite.
        // Per boss spec: chat data must be part of the warehouse file so the
        // customer can copy the warehouse to another Mac and continue the
        // session history directly.
        let warehousePath = UserDefaults.standard.string(forKey: "wenshu.libraryPath")
        let chatDbPath: String? = warehousePath.map { path in
            // Warehouse is the directory selected via onboarding (.ws folder).
            // Place chat.sqlite inside it.
            (path as NSString).appendingPathComponent("chat.sqlite")
        }
        // v0.24 boss验收fix (Boss 8/25 OOB Spec axis GAP): one-time migration
        // from legacy chat.sqlite to warehouse (preserves chat history when
        // user first picks a .ws warehouse in onboarding).
        if let warehouse = warehousePath {
            Self.migrateLegacyChatIfNeeded(warehousePath: warehouse, chatDbPath: chatDbPath)
        }

        let chatStore: ChatSessionStore?
        do {
            let store = try ChatSessionStore(path: chatDbPath)
            try store.bootstrap()
            chatStore = store
            // v0.24 boss验收fix (Standards F3): log caller-side path (chatDbPath)
            // instead of store.dbPath — keeps dbPath encapsulated (= private).
            NSLog("[wenshu.chatStore] init OK: store created at %@", chatDbPath ?? "<legacy>")
        } catch {
            chatStore = nil
            // v0.24 boss验收fix: also log the attempted path on failure
            // (was missing path info, made debugging hard).
            NSLog("[wenshu.chatStore] init FAILED at %@: %@", chatDbPath ?? "<legacy>", String(describing: error))
        }
        Self.sharedChatStoreRef = chatStore  // code-review H1 修法
        if chatStore != nil {
            NotificationCenter.default.post(name: .wenshuChatStoreReady, object: nil)
        }
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
        // v0.21 ticket 06: NSApp.mainMenu 移 applicationWillFinishLaunching (= 上一段, 早于 SwiftUI 初始化)
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
        // macOS .unified(compact:) 52 PT toolbar 由 WindowGroup windowStyle 提供 (老板 2026-08-19 拍不写自定标题栏)
        // 不加 fixed frame + 不加 max(...) floor (v0.15 ticket 005 修响应式 bug)
        GeometryReader { proxy in
            let totalW = proxy.size.width
            let contentH = proxy.size.height  // NSWindow.contentRect (已扣 macOS titlebar chrome by NSWindow at runtime)
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
            // v0.24 boss验收fix (Boss 8/25 eighth OOB '不要纠结线的问题, 核心是比例'):
            // overlay REMOVED. Boss拍 core spec = the rightmost zone widths
            // (specializedTools upper + aiDynamic lower) must have the same
            // ratio of total width. LayoutTokens.toolsWRatio ==
            // LayoutTokens.dynamicWRatio = 400/1920 already satisfies this
            // at initial state (= both zones 400/1920 * totalWidth = same).
            // Splitter positions may still differ slightly (= D_v3 X =
            // 1514/1920 vs D_v5 X = 1518/1920, 4 PT off) — that's a
            // splitter placement issue, not a zone-width issue.
            // v0.24 boss验收fix: tap anywhere posts defocus notification so chat
            // input loses focus when user clicks outside TextField.
            // Boss 8/24 feedback: '点其它区域, 文本框还是不失焦'.
            .contentShape(Rectangle())
            .onTapGesture {
                NotificationCenter.default.post(name: .wenshuDefocusChatInput, object: nil)
            }
            // v0.24 fix (Boss 8/25 13th OOB ticket 015.027): macOS window
            // toolbar reorganized into 3 groups per Boss spec. Boss image shows
            // 3 red boxes (= left file actions group, center 4 zone toggles
            // group, right export group). Removed per Boss拍: title 'Wenshu',
            // center title, '+' button (= not in spec).
            // UI labels (新建/打开/导入/项目管理区/工具区/聊天区/动态区/导出) are
            // Chinese per Boss 8/25 'UI 全中文' rule (= UI strings exempt
            // from AGENTS.md §11 English-only rule).
            .toolbar {
                // v0.24 fix (Boss 8/25 25th OOB '看到 pages 的样式了没, 胶囊有多
                // 个. 我们就需要三个胶囊 1.(新建, 打开, 导入) 2.(四个显隐开关)
                // 3.(一个导出按钮)'): wrap left 3 file actions in 1 dark capsule
                // (= 1 of 3 separate 胶囊 groups, Pages style). Same control
                // BackgroundColor as right groups (= 1 layer, no outer glass).
                // v0.24 fix (Boss 8/25 32nd OOB 'ICON outside capsule, check official'):
                // per Apple HIG (= nilcoalescing.com macOS toolbar guide), use
                // default toolbar item sizes (= no custom .frame, .font,
                // .padding, .background). Let macOS toolbar manage everything.
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        NSLog("[wenshu.toolbar] tap: 新建 (placeholder)")
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .help("新建")
                    Button {
                        NSLog("[wenshu.toolbar] tap: 打开 (placeholder)")
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("打开")
                    Button {
                        NSLog("[wenshu.toolbar] tap: 导入 (placeholder)")
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("导入")
                }
                // v0.24 fix (Boss 8/25 37th OOB 'check official docs, how to right-align'):
                // per Apple developer.apple.com/documentation/SwiftUI/
                // ToolbarItemPlacement/primaryAction, '.primaryAction' on
                // macOS = LEADING edge (= left side). To put buttons on
                // TRAILING edge (= right side) on macOS, the official Apple
                // pattern = ToolbarItemGroup(.automatic) with Spacer() first
                // (= pushes all buttons to trailing edge, per Stack Overflow
                // accepted answer for macOS SwiftUI). 4 zone toggles +
                // export button all in 1 group, Spacer first pushes the whole
                // group to rightmost position (= the whole group tight
                // against right edge, no per-button separator).
                ToolbarItemGroup(placement: .automatic) {
                    Spacer()
                    Button {
                        vm.toggleZone(slot: .projectSidebar)
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .foregroundStyle(vm.isZoneVisible(slot: .projectSidebar) ? Color.accentColor : Color.secondary)
                    .help(vm.isZoneVisible(slot: .projectSidebar) ? "隐藏 项目管理区" : "显示 项目管理区")
                    Button {
                        vm.toggleZone(slot: .specializedTools)
                    } label: {
                        Image(systemName: "wrench.and.screwdriver")
                    }
                    .foregroundStyle(vm.isZoneVisible(slot: .specializedTools) ? Color.accentColor : Color.secondary)
                    .help(vm.isZoneVisible(slot: .specializedTools) ? "隐藏 工具区" : "显示 工具区")
                    Button {
                        vm.toggleZone(slot: .aiChat)
                    } label: {
                        Image(systemName: "bubble.left")
                    }
                    .foregroundStyle(vm.isZoneVisible(slot: .aiChat) ? Color.accentColor : Color.secondary)
                    .help(vm.isZoneVisible(slot: .aiChat) ? "隐藏 聊天区" : "显示 聊天区")
                    Button {
                        vm.toggleZone(slot: .aiDynamic)
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .foregroundStyle(vm.isZoneVisible(slot: .aiDynamic) ? Color.accentColor : Color.secondary)
                    .help(vm.isZoneVisible(slot: .aiDynamic) ? "隐藏 动态区" : "显示 动态区")
                    Button {
                        vm.exportEbook(format: "epub")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("导出电子书 (PDF / EPUB / MOBI / TXT)")
                }
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
            // v0.24 boss验收fix (Boss 8/25 15th OOB '工具区不能拖拽了. 修好'):
            // reverted conditional hide from ticket 015.024 (= 4 PT double-line
            // fix) because hiding D_v3 makes it impossible to drag 工具区 width.
            // Per Boss 8/25 8th OOB '不要纠结线的问题, 核心是比例': visual
            // double-line at initial state is acceptable (= priority is drag
            // functionality, not pixel-perfect alignment). Boss can still
            // independently adjust toolsWRatio via D_v3.
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
        // v0.15 ticket 017.5 修: 老板 2026-08-19 拍 "SF Symbol 是是字号, 不是尺寸"
        // 只用 .font(.system(size:)) 给字号, 不用 .frame 约束尺寸
        // SF Symbol 字号 18 PT 视觉占 SF Symbol 默认 padding (~16 PT 视觉), 不撑 18×18 框
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundStyle(DesignColor.accentBlue)
    }
}

/// 区域顶部工具栏: 30 PT 高, 3 SF Symbol 占位 + 占位文字 + 底 2 PT 分割线.
/// 宽度由父组件约束自动撑到区域模块宽度 (不画穿 splitter).
/// v0.22 ticket B-0: 支持 [ZoneToolbarAction] 参数 (默认空 = placeholder mode, 向后兼容).
struct ZoneTopToolbar: View {
    let iconNames: [String]
    var actions: [ZoneToolbarAction] = []

    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight  // 30 PT
        // 顶栏背景: 撑满父级宽度 (区域模块宽), 高度 30 PT
        DesignColor.zoneSurface
            .frame(height: toolbarH)
            .overlay(alignment: .topLeading) {
                // 真功能 mode (有 actions): button 触发
                // Placeholder mode (空 actions): 老 SF Symbol 占位 (向后兼容)
                HStack(spacing: 15) {
                    if actions.isEmpty {
                        ForEach(0..<iconNames.count, id: \.self) { i in
                            ZoneIcon(systemName: iconNames[i], size: 18)
                        }
                    } else {
                        ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                            Button {
                                item.action()
                            } label: {
                                ZoneIcon(systemName: item.icon, size: 18)
                            }
                            .buttonStyle(.plain)
                            .help(item.label)
                            .accessibilityLabel(item.label)
                        }
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

/// Zone toolbar action config (v0.22 ticket B-0): one toolbar icon button.
/// Boss 2026-08-22 拍: 每个 zone 顶部 icon 真的用起来 (不再 placeholder).
struct ZoneToolbarAction {
    let label: String      // accessibility + tooltip
    let icon: String       // SF Symbol name
    let action: () -> Void
}

/// 区域底部工具栏: 30 PT 高, 左/右各占位文字 + 顶 2 PT 分割线.
/// 宽度由父组件约束自动撑到区域模块宽度 (不画穿 splitter).
/// v0.22 ticket o09: 右侧占位文字替换为 WordCountInlineLabel (default 0 字).
/// v0.24 boss验收fix (Boss 8/25 third OOB '其它五区的底栏都丢了'):
/// Restore ZoneBottomToolbar with per-zone status info. Per Boss plan A:
/// - projectSidebar = 书架数
/// - editor = 字数
/// - preview = 章节数
/// - specializedTools = placeholder '工具就绪'
/// Per-zone status passed as parameter (boss 8/25 OOB '每 zone 自己的 status info').
struct ZoneBottomToolbar: View {
    @State private var wordCountViewModel: WordCountViewModel = WordCountViewModel()
    let status: String  // v0.24: per-zone status info (left side, = shelf count / word count / chapter count / etc.)
    // v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019): per-zone right
    // status. Default empty = no right text rendered (= keep WordCount
    // fallback). projectSidebar uses '书: N' (= total book count per Boss spec).
    let rightStatus: String

    init(status: String = "", rightStatus: String = "") {
        self.status = status
        self.rightStatus = rightStatus
    }

    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight
        DesignColor.zoneSurface
            .frame(height: toolbarH)
            .overlay(alignment: .top) {
                DesignColor.splitterLine.frame(height: 1)
            }
            .overlay(alignment: .bottomLeading) {
                // v0.24 fix: per-zone status info (left side).
                // Empty status = placeholder text (backward compatible).
                Text(status.isEmpty ? "占位文字" : status)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 18)
                    .padding(.bottom, 6)
                    .frame(height: toolbarH, alignment: .bottomLeading)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                // v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019):
                // right-side status text. Per Boss spec '右边的字数改成, 书 N
                // (取实际的数)', projectSidebar shows '书: N' (= total book
                // count). Empty rightStatus = render WordCountInlineLabel
                // (= chat zone word count fallback per o09 ticket).
                if rightStatus.isEmpty {
                    WordCountInlineLabel(viewModel: wordCountViewModel)
                        .padding(.trailing, 18)
                        .padding(.bottom, 6)
                        .frame(height: toolbarH, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                } else {
                    Text(rightStatus)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 18)
                        .padding(.bottom, 6)
                        .frame(height: toolbarH, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                }
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

    // v0.22: sheet showing flags for each toolbar action. Independent per slot.
    // v0.24 boss验收fix: re-added for projectPreview zone (Search toolbar icon).
    @State private var showingSearch: Bool = false
    // v0.23 ticket 005: sub-agent progress 明盒 (boss 8/23 拍: '让用户知道工作进度的明盒').
    // h14: last AI reply text (for read-aloud).
    @State private var lastAIReply: String = ""

    private var toolbarH: CGFloat { LayoutTokens.toolbarHeight }  // v0.15 ticket 008: 老板 Sketch 真值 30 PT 1:1 硬编码
    /// 老板 8/18 Q2 答: 4 PT inset = 单一垂直方向 (spec §3.2 "背景 y=60~884, 正文 y=64~882", 上下 4 PT 视觉下沉, 左右 flush)
    /// v0.15 ticket 005 改名: editorInsetRatio → editorVerticalInsetRatio (明确垂直方向)
    private var editorInset: CGFloat { bandH * LayoutTokens.editorVerticalInsetRatio }  // 4 PT 单一垂直

    /// v0.24 fix (Boss 8/25 third OOB ticket 015.012): per-zone status
    /// info text (= shelf count, chapter count, word count, etc.). Per Boss plan A.
    /// Empty string = placeholder mode (= fallback 'placeholder text' in toolbar view).
    /// Real data wiring follows in ticket 015.013 (= needs library + book + chapter models).
    private func zoneStatus(for slot: ZoneSlot) -> String {
        switch slot {
        case .projectSidebar:
            // Per Boss plan A: shelf count (= WenshuLibrary.shelves.count).
            // Wiring deferred to ticket 015.013.
            return "书架: \(library.shelves.count)"
        case .projectPreview:
            // Per Boss plan A: chapter count + current chapter number.
            // Wiring deferred to ticket 015.013.
            return "章节: 0"
        case .editor:
            // Per Boss plan A: word count + progress %.
            // Wiring deferred to ticket 015.013.
            return "字数: 0"
        case .specializedTools:
            // Per Boss plan A: placeholder 'tools ready'.
            return "工具就绪"
        case .aiChat:
            // Skip (= chat zone uses in-child ChatBottomToolbar).
            return ""
        case .aiDynamic:
            // v0.24 fix (Boss 8/25 third OOB plan A): dynamic zone shows
            // 'Kanban' status label (= inner tab has the kanban board with
            // progress). Outer toolbar rendered with explicit placeholder
            // instead of silent fallback to 'placeholder text' (Standards F2 fix).
            return "看板"
        }
    }

    /// v0.24 boss验收fix (Boss 8/25 sixth OOB ticket 015.019): per-zone
    /// right-side status. Empty string = no right text rendered (= chat
    /// zone keeps WordCountInlineLabel fallback per o09). Per Boss plan A:
    /// - projectSidebar: '书: N' (= total book count from library).
    /// - other zones: empty (= keep WordCountInlineLabel word count).
    private func rightStatus(for slot: ZoneSlot) -> String {
        switch slot {
        case .projectSidebar:
            // Per Boss 8/25 sixth OOB: '右边的字数改成, 书 N (取实际的数)'.
            // Total book count across all shelves (= library.bookCount).
            return "书: \(library.bookCount)"
        case .projectPreview, .editor, .specializedTools, .aiChat, .aiDynamic:
            // Empty = no right text (= WordCountInlineLabel fallback).
            return ""
        }
    }
    // v0.10.8: 撤掉 chatInputW/H 私有属性, 老板 8/18 拍 "新图没画聊天输入框"
    private var innerBandH: CGFloat { bandH - 2 * toolbarH }  // 顶栏底栏间内容区

    var body: some View {
        // 区域模块 = 顶栏 (上) + 内容区 (中) + 底栏 (下).
        // .aiChat 跳过底栏: ChatZoneView 自带底栏 (= v0.21 ticket 10 修因因 替换 chat zone 底栏 '占位文字' 位置)
        // v0.22 ticket B-0: ZoneTopToolbar supports ZoneToolbarAction (placeholder mode when actions empty).
        // ZoneModule passes per-slot actions here. Individual tickets wire their own actions.
        // v0.24 boss验收fix: 6-zone unified pattern — no outer ZoneTopToolbar / ZoneBottomToolbar.
// Each zone renders its own internal tab bar (varies per zone):
//   - chat zone: ChatZoneTabBar (chat / search / settings)
//   - dynamic zone: DynamicZoneTabBar (进度 / 待办 / 搜索)
//   - other 4 zones: ZoneContentTabBar (placeholder tabs, future wired)
// v0.24 boss验收fix (Boss 8/24 拍): 不加 per-zone title bar.
// 老板拍 '你在干嘛？为啥要加了标题栏'. 标题栏只有 macOS 自带那款 (28 PT),
// 不要 per-zone 自写 title bar (会跟 macOS 顶部 chrome 重复).
// v0.24 boss验收fix (2026-08-24): alignment: .top so tab bar flush at top of zone.
        // (was: default .center caused tab bar to appear mid-zone in upper band.)
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // v0.24 fix (Boss 8/25 third OOB 'other 5 zones lost bottom toolbar'):
            // Re-add ZoneBottomToolbar for all slots except .aiChat (= chat keeps
            // its own internal ChatBottomToolbar per ticket 10).
            // Per Boss plan A: per-zone status info (shelf count, chapter count,
            // word count, etc.).
            if slot != .aiChat {
                ZoneBottomToolbar(status: zoneStatus(for: slot), rightStatus: rightStatus(for: slot))
            }
        }
        .background(slot == .aiDynamic ? DesignColor.dynamicZoneSurface : .clear)
        // v0.22: sheet presentations for each toolbar action. Single modifier tree,
        // one per showing-* flag. Each ticket wires its view here.
        }

    /// h14: read aloud the last AI reply via WenshuConductor.invokeTool(av:).
    private func readAloudLastReply() async {
        guard !lastAIReply.isEmpty else { return }
        _ = await WenshuAppDelegate.sharedConductor?.invokeTool(name: "av", input: lastAIReply)
    }

    /// v0.22: per-slot toolbar actions. Currently empty — wired by individual UI mount tickets.
    /// Each ticket commits: (1) new view file, (2) action closure here.
    private func toolbarActions(for slot: ZoneSlot) -> [ZoneToolbarAction] {
        // Empty by default. Tickets add cases as they ship.
        switch slot {
        case .aiChat:
            // v0.24 boss验收fix (2026-08-24): Todo + Search 移到 dynamic zone.
            // Chat zone 顶栏只剩 chat-specific (Read Aloud = TTS last AI reply).
            // 内层 ChatZoneTabBar 仍显示 chat/search/settings 3 internal tabs.
            return [
                ZoneToolbarAction(
                    label: "Read Aloud",
                    icon: "speaker.wave.2",
                    action: { Task { await readAloudLastReply() } }
                ),
            ]
        case .aiDynamic:
            // v0.24 boss验收fix (2026-08-24): Toolbar 清空 (no icons needed).
            // Dynamic zone uses internal tabs (任务 / 进度 / 搜索) in DynamicZoneView.
            // 顶栏 ZoneTopToolbar is empty placeholder mode (backward compatible).
            return []
        case .projectSidebar:
            // o04 Templates (project sidebar — template picker for new docs).
            return [
                ZoneToolbarAction(
                    label: "Templates",
                    icon: "doc.badge.plus",
                    action: {}
                ),
            ]
        case .projectPreview:
            // o09 Word Count inline + o03 Graph + o06 Search (preview zone — main content).
            // Word count already in ZoneBottomToolbar; here we add graph + search.
            return [
                ZoneToolbarAction(
                    label: "Graph",
                    icon: "circle.grid.cross.fill",
                    action: {}
                ),
                ZoneToolbarAction(
                    label: "Search",
                    icon: "magnifyingglass",
                    action: { showingSearch.toggle() }
                ),
            ]
        case .editor, .specializedTools:
            // Placeholder zones — no toolbar actions.
            return []
        }
    }

    @ViewBuilder
    private var content: some View {
        // v0.15 ticket 005 范式: 每个 case 自己 Color + overlay (跟 ticket 005 一样, ticket 006 撤回 P3-4)
        switch slot {
        case .projectSidebar:
            // v0.24 boss验收fix (Boss 8/25 seventh OOB ticket 015.020):
            // hide 收藏 + 模板 tabs (Boss拍 '现有的收藏和模版没有用'), keep
            // only tab1 outline (= library books/shelves tree). Renamed label
            // '大纲' -> '书架' + icon 'list.bullet.rectangle' -> 'books.vertical.fill'
            // (= Apple SF Symbol = solid bookshelf, matches Boss spec
            // '选一个合适的 ICON 替换').
            ZoneContentView(zoneSlug: "projectSidebar", tabs: [
                ("书架", "books.vertical.fill", AnyView(DesignColor.zoneSurface.overlay(alignment: .topLeading) { LibraryOutlineViewContent(library: library) })),
            ])
        case .projectPreview:
            // ProjectPreview tabs: 预览 / 图 / 搜索.
            ZoneContentView(zoneSlug: "projectPreview", tabs: [
                ("预览", "eye", AnyView(DesignColor.zoneSurface)),
                // v0.24 boss验收fix (Boss 8/24): 统一 outline variant (其他 13 个 icons 都 outline,
                // 只有 'circle.grid.cross.fill' 是实心 fill). 删 .fill suffix.
                ("图", "circle.grid.cross", AnyView(GraphView())),
                ("搜索", "magnifyingglass", AnyView(SearchPanel())),
            ])
        case .editor:
            // Editor tabs: 编辑 / 大纲 / 反链.
            // v0.24 boss验收fix: 保留原 4 PT inset 设计意图 (背景 y=60~884, 正文 y=64~882, 上下 4 PT 视觉下沉, 左右 flush).
            // 编辑 tab: 占位 (WenshuEditor view deferred to v0.24+, 没接到 doc reader).
            ZoneContentView(zoneSlug: "editor", tabs: [
                ("编辑", "pencil", AnyView(DesignColor.zoneSurface.overlay { Color.white.opacity(0.55).padding([.top, .bottom], editorInset) })),
                ("大纲", "list.bullet", AnyView(OutlinePanel())),
                ("反链", "link", AnyView(BacklinksPanel())),
            ])
        case .specializedTools:
            // v0.24 boss验收fix (2026-08-24): 删 '作曲' tab.
            // Boss 8/24 feedback: '作曲是干什么的, 我不知道' → 拍 '可以删'.
            // ComposerPanel = v0.19 Obsidian replica 时期 dead code, 没接到核心
            // 写作流, 留 '画布' (auto-gen 图像, boss 拍保留) + '数据库' (改看板).
            // SpecializedTools tabs now: 画布 / 数据库 (2 tab).
            ZoneContentView(zoneSlug: "specializedTools", tabs: [
                ("画布", "scribble", AnyView(CanvasView())),
                ("数据库", "tablecells", AnyView(BaseView())),
            ])
        case .aiChat:
            // ChatZoneView 自带 ChatZoneTabBar (chat / search / settings), 已 1 层.
            ChatZoneView(
                conductor: WenshuAppDelegate.sharedConductor,
                store: WenshuAppDelegate.sharedChatStoreRef
            )
        case .aiDynamic:
            // DynamicZoneView 自带 DynamicZoneTabBar (进度 / 待办 / 搜索), 已 1 层.
            DynamicZoneView()
        }
    }
}

/// 6 instance 槽位 (老板 Sketch 组件化 6 master 派生)
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





/// compactNumber: 真实 token count 折 compact 格式 (Hermes format_token_count_compact 真值)
private func compactNumber(_ n: Int) -> String {
    let d = Double(n)
    if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000).replacingOccurrences(of: ".0M", with: "M") }
    if d >= 1_000 { return String(format: "%.1fk", d / 1_000).replacingOccurrences(of: ".0k", with: "k") }
    return "\(n)"
}


struct ChatZoneView: View {
    let conductor: WenshuConductor?
    let store: ChatSessionStore?
    // v0.21 ticket 43: chat zone 顶栏 3 个 tab 真切换 (老板 2026-08-22 06:22 拍 backlog 20)
    enum ChatZoneTab: String, CaseIterable, Identifiable {
        case chat = "对话"
        case search = "搜索"
        case settings = "设置"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .chat: return "person.crop.circle.badge.questionmark"  // 老板拍 "用机器人" = ticket 30+33 robot face
            case .search: return "magnifyingglass"  // 老板拍 "保留现在的这个"
            case .settings: return "slider.horizontal.3"  // 老板拍 "保留现在的这个"
            }
        }
    }
    // v0.23 ticket 011.002: change from flat [String] to sectioned [AvailableProviderModels].
    // Boss 8/23 拍: 我配了三个厂家的 key, 模型切换应分组展示可用模型合集.
    @State private var availableSections: [AvailableProviderModels] = []
    // v0.21 ticket 43 step 3: picker ↔ UserDefaults 同步修复 = @AppStorage (Apple SwiftUI 真值, 源单一 UserDefaults, 双向自动同步)
    // 修复前 ChatZoneView.currentModel 是 @State 不绑 UserDefaults, ChatViewModel.currentModel 是 init default 读 UserDefaults 一次 = 切 picker 后两条状态链断开
    // @AppStorage 是 Apple HIG 真值, 源单一 UserDefaults, 自动响应变化, 修复 picker 跟 ChatViewModel 同步
    // v0.24 boss验收fix (2026-08-24): default empty (no key) instead of "MiniMax-M3".
    @AppStorage("wenshu.llm.model") private var currentModel: String = ""
    // v0.24 boss验收fix (2026-08-24): persist tab selection across launches.
    // Boss 8/24: '每个区域的 tab 选中状态应该持久化'.
    @AppStorage("wenshu.tabIndex.aiChat") private var selectedTabRaw: String = "对话"
    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive flow state.
    // When user clicks archive icon in ChatZoneTabBar, this toggles true and
    // shows confirmation alert. Confirm = archive current session + start new.
    @State private var showingArchiveAlert: Bool = false

    private var selectedTab: ChatZoneTab {
        get { ChatZoneTab(rawValue: selectedTabRaw) ?? .chat }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }
    // v0.21 ticket 40: 持有 ChatViewModel 实例 + 共享给 ChatView, 让 bottom toolbar 读 vm.contextUsed 自动 propagate
    // v0.24 boss验收fix (Boss 8/25 OOB 'minimax m3 不是 1mb 的上下文吗', 双轴
    // Spec axis sub-agent report FAIL): dead contextMax field removed. Was
    // 131072 (M2 series value) and unused (= UI reads vm.contextMax from
    // ChatViewModel). Stale after commit dc741ceac fix.
    @State private var vm: ChatViewModel

    init(conductor: WenshuConductor?, store: ChatSessionStore?) {
        self.conductor = conductor
        self.store = store
        _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store))
        // v0.21 ticket 43 step 1 NSLog trace
        NSLog("[wenshu.tab] onAppear: selectedTab=%@ currentModel=%@", ChatZoneTab.chat.rawValue, currentModel)
    }

    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive current session
    // + context, then start new session. Boss spec: '点击确认, 回档现有会话和
    // 上下文. 起一个全新的会话. 上下文重新加载'.
    //
    // Flow:
    // 1. Snapshot current session (= sessionId + message count + summary).
    // 2. Reset vm.messages = [] (visual).
    // 3. Reset vm.contextUsed = 0 (context counter).
    // 4. Generate new sessionId (= UUID-based).
    // 5. Persist new sessionId to vm (= future writes go to new session).
    // 6. NSLog audit trail.
    //
    // Per ticket 015.014: archive is in-memory (= no chat_archives table
    // persistence yet, that's ticket 015.015 follow-up). User can re-trigger
    // archive from same session (idempotent snapshot).
    private func archiveAndStartNewSession() {
        // Snapshot atomic (= SUGGEST 4 fix from Standards report).
        let oldSessionId = vm.valueForSessionId()
        let messageCount = vm.messages.count
        let contextUsedBefore = vm.contextUsed
        // v0.24 boss验收fix (Boss 8/25 fourth OOB Spec axis FAIL for ticket
        // 015.014): durable archive persistence (= Boss spec '回档现有会话
        // 和上下文'). Writes to chat_archives table via ChatSessionStore.
        if let store = store {
            do {
                try store.archiveSession(sessionId: oldSessionId,
                                          messageCount: messageCount,
                                          contextUsed: contextUsedBefore)
            } catch {
                NSLog("[wenshu.chat] archive FAILED: %@", String(describing: error))
            }
        } else {
            NSLog("[wenshu.chat] archive session (no store): id=%@ messages=%d contextUsed=%d",
                  oldSessionId, messageCount, contextUsedBefore)
        }
        // Start new session
        vm.startNewSession()
        NSLog("[wenshu.chat] new session started: id=%@ messages=%d contextUsed=%d",
              vm.valueForSessionId(), vm.messages.count, vm.contextUsed)
    }

    var body: some View {
            VStack(spacing: 0) {
                // v0.21 ticket 43 step 2: 聊天区顶栏 3 个 tab 真切换 (老板拍 backlog 20, 修复 step 1 NSLog 锁 picker sync)
                // Apple HIG 真值: Button(.plain) + contentShape(Rectangle()) 整条热区响应 (ticket 17 + 21 已修复范式)
                // + .foregroundStyle(.accentColor) 选中态高亮
                // + Apple 默认动画 .animation(.default, value: selectedTab) (Q58.4)
                // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): wire
                // archive alert state into ChatZoneTabBar.
                ChatZoneTabBar(selectedTab: Binding(
                    get: { selectedTab },
                    set: { selectedTab = $0 }
                ), showingArchiveAlert: $showingArchiveAlert)
                Group {
                    switch selectedTab {
                    case .chat:
                        // v0.24 boss验收fix: ZStack fills full chat zone, help text centered.
                        ZStack {
                            ChatView(conductor: conductor, store: store, vm: vm)
                            if currentModel.isEmpty {
                                ChatHelpTextOverlay {
                                    UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
                                    // v0.24 boss验收fix: 4-tier approach to open Settings.
                                    // v0.24 boss验收fix: open in-app Settings scene (文枢 settings, not
                                    // System Settings.app). Uses captured WenshuAppDelegate.openSettings
                                    // (set by SettingsEnvironmentCapturer on .onAppear).
                                    // UserDefaults pre-set selects providerApi tab.
                                    UserDefaults.standard.set("providerApi", forKey: "wenshu.settingsTab")
                                    WenshuAppDelegate.openSettings?()
                                }
                                .allowsHitTesting(true)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .search:
                        ChatZoneStubView(title: "搜索", icon: "magnifyingglass")
                    case .settings:
                        ChatZoneStubView(title: "设置", icon: "slider.horizontal.3")
                    }
                }
                .animation(.default, value: selectedTab)
                // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive
                // confirmation alert. Boss spec: '点击确认, 回档现有会话和上下文.
                // 起一个全新的会话. 上下文重新加载'.
                .alert("归档当前会话?", isPresented: $showingArchiveAlert) {
                    Button("取消", role: .cancel) { }
                    Button("归档并新建", role: .destructive) {
                        archiveAndStartNewSession()
                    }
                } message: {
                    Text("当前会话和上下文将归档保存, 然后开启全新会话。")
                }
                HStack(spacing: 0) {
                Menu {
                    // v0.23 ticket 011.002: sectioned picker (boss 8/23 拍).
                    // Each section = provider with a configured Keychain key.
                    // Models = provider.defaultModels (curated list).
                    if availableSections.isEmpty {
                        Text("No provider keys configured")
                            .font(.caption)
                    } else {
                        ForEach(availableSections, id: \.provider.slug) { section in
                            Section(section.provider.name) {
                                ForEach(section.models, id: \.self) { model in
                                    Button {
                                        currentModel = model
                                    } label: {
                                        HStack {
                                            Text(model)
                                            if model == currentModel {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    // v0.21 ticket 36: explicit .foregroundStyle(.tertiary) per element
                    // v0.21 ticket 37: drop .menuStyle(.borderlessButton) — that wrapper overrides
                    //   foregroundStyle. Default Menu style lets our per-element .tertiary apply.
                    // v0.21 ticket 42 老板 17:35: .menuStyle(.button) + .buttonStyle(.plain) (Apple deprecated .borderedButton 提示真值组合)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .foregroundStyle(.secondary)
                        Text(currentModel.isEmpty ? "无模型可用" : ModelDisplay.lookup(currentModel).display)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)
                    .frame(height: LayoutTokens.toolbarHeight, alignment: .bottomLeading)
                }
                // v0.21 ticket 42: Apple 真值组合 .menuStyle(.button) + .buttonStyle(.plain) = 去外壳 (Apple SwiftUI 14+ deprecated .borderedButton 提示路径)
                .menuStyle(.button)
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .task {
                    // v0.23 ticket 011.002: load sectioned available models from Keychain.
                    // (was: live-fetch from minimax API; now: discover all configured providers.)
                    availableSections = AvailableModelsDiscovery.loadFromKeychain()
                    // v0.24 boss验收fix: when currentModel is empty AND at least one
                    // provider is now configured, auto-select the first available
                    // model so the user doesn't see "无模型可用" right after saving
                    // their first key.
                    if currentModel.isEmpty, let firstSection = availableSections.first, let firstModel = firstSection.models.first {
                        currentModel = firstModel
                    }
                    // If currentModel is set but not in any section, add fallback
                    // so user can see/select it.
                    if !currentModel.isEmpty,
                       !availableSections.contains(where: { $0.models.contains(currentModel) }) {
                        let fallback = Provider.by(slug: "minimax-cn") ?? Provider.all[0]
                        availableSections.append(AvailableProviderModels(
                            provider: fallback,
                            models: [currentModel]
                        ))
                    }
                }
                // v0.24 boss验收fix: re-load on ProviderKeychain change
                // (Settings save key → notification → re-populate availableSections).
                .onReceive(NotificationCenter.default.publisher(for: .wenshuProviderKeychainChanged)) { _ in
                    availableSections = AvailableModelsDiscovery.loadFromKeychain()
                    // v0.24 boss验收fix: when currentModel is empty AND at least one
                    // provider is now configured, auto-select the first available
                    // model so the user doesn't see "无模型可用" right after saving
                    // their first key.
                    if currentModel.isEmpty, let firstSection = availableSections.first, let firstModel = firstSection.models.first {
                        currentModel = firstModel
                    }
                    // If currentModel is set but not in any section, add fallback
                    // so user can see/select it.
                    if !currentModel.isEmpty,
                       !availableSections.contains(where: { $0.models.contains(currentModel) }) {
                        let fallback = Provider.by(slug: "minimax-cn") ?? Provider.all[0]
                        availableSections.append(AvailableProviderModels(
                            provider: fallback,
                            models: [currentModel]
                        ))
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    // v0.21 ticket 40: 读 vm.contextUsed (Apple @Observable 自动 propagate, 不再写死 @State contextUsed = 0)
                    // v0.24 boss验收fix: Apple standard dark text (.secondary).
                    Text("\(compactNumber(vm.contextUsed)) / \(compactNumber(vm.contextMax))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(vm.contextUsed, vm.contextMax)), total: Double(max(1, vm.contextMax)))
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(vm.contextUsed >= vm.contextMax ? .red : (vm.contextUsed > vm.contextMax * 3 / 4 ? .orange : .green))
                }
                .padding(.trailing, 18)
                .padding(.bottom, 6)
                .frame(height: LayoutTokens.toolbarHeight, alignment: .bottomTrailing)
            }
            .background(DesignColor.zoneSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
    }
}

/// v0.21 ticket 43: ChatZoneTabBar = 聊天区顶栏 3 个 tab 真切换 (老板拍 backlog 20)
/// Apple HIG 真值: Button(.plain) + contentShape(Rectangle()) 整条热区响应 (ticket 17 + 21 已修复范式)
/// + .foregroundStyle(.accentColor) 选中态高亮 + Apple 默认动画
/// v0.24 boss验收fix (Boss 8/25 fourth OOB '聊天区顶栏居右 18PT 加归档 ICON'):
/// Added archive icon at top-right (18 PT right padding). Click triggers
/// alert '是否归档本次会话和上下文' (yes / cancel). Confirm archives current
/// session + context, starts new session, resets context counter.
struct ChatZoneTabBar: View {
    @Binding var selectedTab: ChatZoneView.ChatZoneTab
    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive flow state.
    @Binding var showingArchiveAlert: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                ForEach(ChatZoneView.ChatZoneTab.allCases.filter { $0 == .chat }) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        // v0.24 boss验收fix: icon only, no title label.
                        Image(systemName: tab.icon)
                            .font(.system(size: LayoutTokens.iconSize))
                            .imageScale(.large)
                            .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                            .foregroundStyle(tab == selectedTab ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(.leading, 18)

            Spacer()

            // v0.24 boss验收fix (Boss 8/25 fourth OOB ticket 015.014): archive
            // icon at top-right (= Boss image 红框 position). 18 PT right
            // padding per Boss spec. Click triggers showingArchiveAlert.
            Button {
                showingArchiveAlert = true
            } label: {
                Image(systemName: "archivebox")
                    .font(.system(size: LayoutTokens.iconSize))
                    .imageScale(.large)
                    .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("归档当前会话")
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: LayoutTokens.toolbarHeight)
        .background(DesignColor.zoneSurface)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
        .animation(.default, value: selectedTab)
    }
}

/// v0.21 ticket 43: ChatZoneStubView = 第 2/3 个 tab 占位视图 (老板拍 '先放着, 后面实现')
/// Apple HIG 真值: VStack 居中 + 大 icon + '开发中' placeholder 文字 + 灰色调
struct ChatZoneStubView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("\(title) (开发中)")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignColor.zoneSurface)
    }
}
