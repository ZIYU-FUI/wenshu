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
import Lucide

// MARK: - v0.25.1 (= ticket 019 icon button Apple HIG hit area) — Apple官方推荐方法
/// Per Apple SwiftUI docs (developer.apple.com/documentation/swiftui/buttonstyle
/// + developer.apple.com/documentation/swiftui/primitivebuttonstyle/plain),
/// the canonical way to extend a plain-style button's hit area (= Apple
/// "How do I make icon buttons easier to click on macOS?") is to implement
/// `IconButtonStyle` REMOVED in v0.34 Apple-API-first #3.
/// Was a pass-through `makeBody { configuration.label }` (= no-op),
/// single call site (App.swift:1820) inside the Button label closure
/// while App.swift:1839 applied `.buttonStyle(.plain)` on the outer Button.
/// SwiftUI button-style precedence = outer-wins, so the inner style was
/// always superseded. Use Apple `.buttonStyle(.plain)` directly with
/// `Color.clear.frame(28,28).contentShape(Rectangle())` inside the label
/// closure (= Apple HIG canonical hot-area pattern).

// 老板 8/18 拍 "重置界面布局" 通知桥 (LayoutShellView 用 @State 私有 vm,
// 顶层 .commands 拿不到 vm 实例, 走 NotificationCenter 转发)

// v0.24 fix (Boss 8/25 60th OOB '对应功能要在菜单栏实现'): notification
// name for menu bar zone toggle buttons (= CommandGroup can't directly
// access vm instance, so menu items post notification, vm listens).
// v0.34 boss 2026-09-02 OOB (B-04 backlog entry): all Notification.Name
// definitions moved to Sources/WenshuApp/Core/Notifications/AppNotifications.swift
// (= single source of truth, grouped into AppCommands / AppStateEvents /
// LayoutEvents enums, unified to "com.wenshu.X" naming per Apple
// Notification Programming Topics reverse-DNS convention). Backward-compat
// accessors (= .wenshuXxx on Notification.Name) live in that file for
// the migration window so the 17 existing call sites compile unchanged.
extension Notification.Name {}  // placeholder; all members moved to AppNotifications.swift

// MARK: - Layout tokens (比例算子 0~1, 老板 8/18 答 "1:1 PT 真值" + 8/18 再拍 "换算成比例")
//
// 数据源: Sketch AF7B1C87 / Artboard 首页 1920×984 PT 1:1 落
// 公式: layoutPT(token) = totalW * ratio (e.g. projectSidebar ratio = 200/1920 = 0.1042)
// Apple HIG responsive: GeometryReader 拿窗口实际尺寸 × 比例 = 任何窗口大小 1:1 自适应

/// Apple Semantic Color — 全 dark mode 适配, 0 RGB 硬编码
// v0.32 boss 2026-09-02 OOB ('全走 apple api 默认; 不要自写颜色
// wrapper'): removed the `DesignColor` enum entirely. The 5 static
// lets (= titleBar / zoneSurface / dynamicZoneSurface / accentBlue /
// splitterLine) were each just a thin wrapper over a bare
// `Color(nsColor: .NSColorStaticProperty)` Apple API call. The
// wrapper added an extra type with no semantic value (= it renamed
// Apple NSColor static properties with no-op translation). All 4
// callers migrated to bare `Color(nsColor: .NSColor)` form in this
// commit. The 1 unused member (dynamicZoneSurface) had zero callers
// and is gone entirely. Apple canonical = direct NSColor calls; no
// project-local color wrapper enum.

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
    // v0.15 ticket 005: 删 LayoutTokens.horizontalSplitterRatio dead code
    // (the drag-to-resize logic is now provided by NSSplitView).

    // 上 band 4 zone 数对公式: (200, 中间 1, 中间 2, 400) = 1920
    // 老板 8/18 拍 "数对" = 拖拽线 1 PT 视觉线摊给左右 zone (各 0.5 PT)
    // 中间 1 + 中间 2 = 1920 - 200 - 400 = 1320
    // 维持原值 558 + 762 (中间 1 + 中间 2 = 1320) = 上 band 4 zone 1920 ✓
    // v0.24 fix (Boss 8/25 50th OOB '还是差了一两个像素' + 51st OOB '尝试修一下'):
    // hit area 6 -> 4 PT (= the drag-to-resize logic). 3 splitters
    // upper = 12 PT (not 18).
    // Splitter hit area counted into the largest column (= editor),
    // other columns preserve design ratios.
    // Total column = 200+200+388+200 = 988 + 12 splitters = 1000
    // (= exact fit, no HStack shrinkage).
    // Upper band 4 zones (20/20/40/20 = 100% total):
    // NOTE: these constants are dead code. The active rendering
    // path (v0.28+ WorkspaceView) reads column weights from
    // WorkspaceStore.builtinDefaultPreset (= [1, 2, 6, 1] after
    // commit b8fb940d2). Kept here for the legacy LayoutShellView
    // path (= unreachable in practice but preserved for
    // backward-compat with the AppStorage flag 'wenshu.useWorkspace'
    // = false case). Do NOT use these constants directly in new code.
    static let projectSidebarRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    static let projectPreviewRatio: CGFloat = 200.0 / 1000.0  // 20% (= Boss 45th OOB)
    // v0.24 fix (Boss 8/25 51st OOB): editor itself contains 3 splitters (= 12 PT hit area @ 4 PT each).
    // 400 (= 40% design) - 12 (= 3 × 4 splitters) = 388 (= design includes splitter)
    static let editorWRatio: CGFloat = 388.0 / 1000.0         // 40% design - 3 splitters @ 4 PT
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
    // v0.24 fix (Boss 8/25 50th OOB '还是差了一两个像素' + 51st OOB '尝试修一下'):
    // hit area 6 -> 4 PT. 1 splitter lower = 4 PT (not 6).
    // aiChat itself contains 1 splitter (= 4 PT hit area @ 4 PT).
    // 800 (= 80% design) - 4 (= 1 × 4 splitter) = 796 (= design includes splitter)
    // Total column = 796+200 = 996 + 4 splitter = 1000 (= exact fit, no HStack shrinkage).
    // Lower band 2 zones (80/20 = 100% total):
    static let aiChatRatio: CGFloat = 796.0 / 1000.0         // 80% design - 1 splitter @ 4 PT
    static let dynamicWRatio: CGFloat = 200.0 / 1000.0       // 20% (= Boss 45th OOB)

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041


    // 顶栏色块比例 (老板 8/18 Q3 答: 22/82/142 起点 + 38 PT 宽 + 60 PT 等距)
    static let iconLeadingRatio: CGFloat = 18.0 / 1920.0  // 起点 18 PT (老板 8/18 改 18 PT, 旧 22 PT)
    static let iconSizeRatio: CGFloat = 18.0 / 1920.0     // 18 PT 边长 (老板 2026-08-26 '改成 18') — was 12 in v0.24 ticket 015.027 (= boss 8/24 '改成 12×12' = mid-step before '改成 18'). Now 18 PT for top-toolbar tab / archive icons.
    // v0.24 boss验收fix (Boss 8/24): tab icon 12×12 PT (= interim; 老板 8/24 '改成 12×12' after 18×18 too big).
    // v0.25.1 (= ticket 006 chat-zone icon size): 老板 2026-08-26 OOB '顶栏的 ICON 尺寸 现在有点过于小了 改成 18' = 12 → 18 PT.
    // Scope = 顶栏 icon class only (= applies to DesignTokens.tabIconSize, used
    // by ChatZoneTabBar tab + archive + DynamicZoneView tab + ZoneContentView
    // item, ALL top-toolbar tab icons). Bottom toolbar status bar (= text not
    // icons) unchanged. Toolbar height hard-capped at 30 PT (= per Boss 8/18
    // Sketch master): 18 PT icons render with 6 PT vertical padding each side (=
    // flush fit, no overflow). If owner pushes back on the toolbar-height fit,
    // ticket 006 followup will address it (= scope of THIS patch is just icon
    // size).
    static let iconSize: CGFloat = 18
    // v0.25.1 (= ticket 007 chat-zone tab hot area): owner 2026-08-26 OOB
    // '热区有点问题 现在好像是 ICON 本身是热区 需要你让 ICON 18×18 的区域
    // 是热区 不然很难点的到' = inflate click target from icon visual size
    // (= 18 PT) to a fixed hot area that maps to the boss 8/11 fix3
    // 'four chat tab height set to 28 PT' (= 28 PT). Hot area applied to
    // BOTH chat tabs (.chat + the right archive-flow icon) for consistency.
    // Hot zone = 28 PT (= boss 8/11 fix3) leaves 2 PT vertical padding in
    // the 30 PT toolbar (= flush fit). Inner icon stays at DesignTokens.tabIconSize
    // (= 18 PT, ticket 006) so visual size unchanged from previous commit.
    static let chatTabHotArea: CGFloat = 28
    // v0.25.1 (= ticket 008 chat-zone tab hit reliability): owner 2026-08-26
    // OOB '还是有点问题 响应不是每次都能响应' = prior ticket 007 fix
    // (= .frame(28,28) + contentShape) was flaky on plain-style Button. Per
    // Apple HIG + SwiftUI Forums canon: reliable hit extension on plain
    // buttons = inline `.padding(.all, hitPad)` inside the label (= the
    // padding extends the inner view's rendered bounds, which the outer
    // button uses as its hit area). 5 PT padding + 18 PT icon = 28 PT
    // total hit area (= same as chatTabHotArea constant, kept separate
    // for clarity: hitPad is the lever, hitArea is the resulting size).
    static let chatTabHitPad: CGFloat = 5
    // v0.25.1 (= ticket 015 unified icon button hot area): owner 2026-08-26
    // OOB '所有的 ICON 的热区都要像归档 ICON 一样处理' = the '归档'
    // ICON (= chat zone top-right .inbox button, ticket 007 + 008 pattern)
    // is the canonical hit-area reference for ALL icon buttons in the
    // project. Apply same hot-area treatment (= 28×28 PT inflated hot
    // area via inline .padding(.all, LayoutTokens.iconButtonHotPad); .frame
    // stays 18 PT visual size; .contentShape(Rectangle()); .background
    // (.clear) for SwiftUI hit-tester reliability) to:
    //  - upper main toolbar (8 global buttons: 新建/打开/导入 + 4 zone
    //    toggle + 导出)
    //  - chat zone send button (.paperplane.fill)
    //  - the 11 tab buttons across 3 tab bar classes (= already applied
    //    in ticket 011, kept unchanged).
    static let iconButtonHotPad: CGFloat = 5
    // v0.25.1 (= ticket 010 tab selected-state underline): owner 2026-
    // 08-26 OOB '现在的 tab 的选定状态 ICON 下没有那个选定的小横线' =
    // Apple HIG canonical selected-tab underline (= ~2 PT height accent
    // bar at bottom of selected tab, full button width). All 3 tab bar
    // classes (DynamicZoneView / ZoneContentView / ChatZoneTabBar) use
    // this constant for the underline height; the underline color is
    // Color.accentColor (= Apple system accent, matches selected-tab
    // icon color so the visual cue is consistent).
    // v0.25.1 (= ticket 025 underline height = 1 PT per owner spec):
    // owner 2026-08-26 OOB 'ICON 下划线全部改成 1PT' = bump down
    // from 3 PT (= ticket 024) to 1 PT (= owner final spec, = a
    // minimal visual hint rather than a heavy accent bar). Apple
    // HIG acceptable range for tab-bar selected indicator =
    // 1-4 PT (= 1 PT is the thinnest canonical option, = Apple
    // HIG Finder sidebar selected indicator style per developer
    // .apple.com/design/human-interface-guidelines/components/
    // navigation/sidebars).
    static let tabUnderlineHeight: CGFloat = 1
    static let iconSpacingRatio: CGFloat = 18.0 / 1920.0  // 18 PT 等距 (老板 8/18 改 18 PT = icon 间距, 起点 18/54/90 相邻 36 - 18 = 18)

    // 底栏占位元素 (老板 8/18 拍 "icon 18×18, 占位文字苹果字符样式正文尺寸") — 绝对 PT 不走比例
    static let bottomLeading: CGFloat = 18                 // 18 PT 距左 (左占位文字)
    static let bottomTrailing: CGFloat = 18                // 18 PT 距右 (右占位 icon)
    static let placeholderIconSize: CGFloat = 18          // 18 PT 占位 icon 边长 (绝对值)
    static let placeholderTextLeadingRatio: CGFloat = 0.09  // 占位文字起点 18/200 = 9%

    // v0.28 followup Boss UX round 33 (Boss 2026-08-29 OOB '各区域的
    // 完整代码, 关于样式的, 不统一, 你要不盘一下'): single source
    // of truth for chrome padding (= replaces magic numbers 4, 6, 8
    // scattered across 15 files). Centralized here so future padding
    // changes apply uniformly across the app (= one place to edit,
    // every pane updates at once).
    //
    // Apple HIG canonical padding values for per-pane chrome items:
    // - chromePaddingSmall = 4 PT (= tight spacing for chip / pill)
    // - chromePaddingMedium = 6 PT (= standard for icon + text padding
    //   in tab bars / statusbars — matches Apple HIG statusbar item
    //   padding)
    // - chromePaddingLarge = 8 PT (= roomier spacing for top/bottom
    //   alignment of text inside chrome bars — matches Apple HIG
    //   toolbar button padding)
    // - chromePaddingLeading = 18 PT (= horizontal left padding from
    //   tab bar edge to first item — matches Apple HIG toolbar left
    //   padding for macOS 27 Tahoe tab bars)
    // - chromePaddingTrailing = 18 PT (= horizontal right padding)
    static let chromePaddingSmall: CGFloat = 4
    static let chromePaddingMedium: CGFloat = 6
    static let chromePaddingLarge: CGFloat = 8
    static let chromePaddingLeading: CGFloat = 18
    static let chromePaddingTrailing: CGFloat = 18

    // v0.28 followup Boss UX round 33: single source of truth for
    // per-region control heights (= chat input row buttons, tab
    // buttons, hover hot areas). All instances of ".frame(height: 30)"
    // for chrome controls should reference chromeControlHeight instead.
    static let chromeControlHeight: CGFloat = 30

    // v0.28 followup Boss UX round 33: single source of truth for
    // visual divider / separator thickness. All instances of
    // ".frame(height: 1)" for chrome separators should reference
    // chromeDividerThickness (= 1 PT Apple HIG hairline).
    static let chromeDividerThickness: CGFloat = 1

    // v0.28 followup Boss UX round 33: selected-tab underline height.
    // (= 1 PT per v0.25.1 ticket 025 owner spec)
    static let tabUnderlineHeightNew: CGFloat = 1  // legacy alias for tabUnderlineHeight
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

    /// v0.30 boss 8/31 OOB "option A for cross-zone communication"
    /// (= global @Observable store). Per-window @State (= each
    /// WindowGroup instance gets its own AppState = boss 8/27 OOB
    /// multi-window future-proofing). Currently hosts the
    /// `sidebarSelection` signal (= the 4-layer @Binding chain
    /// from commit d845fe9c9 has been collapsed to a single
    /// `@Environment(AppState.self) var appState` lookup).
    /// The 3 other signals declared in the original spec
    /// (selectedEntity / selectedEntityCategory / previewSortOrder)
    /// are tracked in v0.31 backlog (= see CONTEXT.md AppState row).
    /// Descendants read it via `@Environment(AppState.self) var appState`.
    @State private var appState = AppState()

    var body: some Scene {
        // v0.24 fix (Boss 8/25 17th OOB 'hide Wenshu title'): WindowGroup
        // title set to empty string (= no NSWindow title shown). Combined
        // with .windowToolbarStyle(.unified, showsTitle: false) below for
        // canonical Apple HIG API to hide title slot in unified chrome.
        WindowGroup("") {
            // v0.21 ticket 01 (重做 #10): 撤回 SettingsEnvironmentCapturer wrapper (commit a78d758bc Q15 翻车 #11 dead code)
            // SettingsEnvironmentCapturer 之前包 LayoutShellView 注入 OpenSettingsAction, 但 openSettings?() → nil (Q15 翻车 #11), 现在 NSMenu 自己装 + 自创建 NSWindow 装 SettingView 不需要 capture
            SettingsEnvironmentCapturer(library: library, appearanceMode: appearanceMode)
                // v0.30 boss 8/31 OOB: inject AppState at root so all
                // descendants can read cross-zone UI state via
                // `@Environment(AppState.self)`. Per-window state
                // (= owned by @State on WenshuApp struct = each
                // WindowGroup instance has its own AppState).
                .environment(appState)
            // v0.28 followup Boss UX round 28 (Boss 2026-08-29 OOB '那是不是
            // 拖拽线也有默认的液态玻璃的样式, 这样的, 你把我们所有用到
            // 的组件, 用默认的液态玻璃样式实现, 我们最多调一下尺寸,
            // 动画效果, 过渡效果等等, 都用默认的, 我说的所有的, 不是
            // 目前可见的, 是有一些弹窗等等, 都用 27 的液态玻璃搞定'):
        }
        // Boss 8/24 feedback: 'use the 52 PT one'. Apple SwiftUI macOS 14+ windowToolbarStyle
        // options: .automatic, .unified (52 PT), .unifiedCompact (28 PT), .expanded.
        // v0.24 fix (Boss 8/25 28th OOB 'use default size' + Apple docs):
        // use .unified (52 PT) = macOS default toolbar style. Per Apple
        // developer.apple.com/documentation/SwiftUI/WindowToolbarStyle,
        // .unified is the default style (52 PT). .unifiedCompact is
        // COMPACT (= smaller, NOT default). Boss spec 'default size' = .unified.
        // v0.28 followup Boss UX round 12 (Boss 2026-08-29 OOB '算了,
        // 本来我们也要伪 apple 官方嘛, 用 52 高的那个原生标题栏,
        // 把按钮放上面, 去掉自己写的那一栏, 全面适配液态玻璃'):
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
        // chrome above or below (= fully Apple-native = '伪 apple
        // 官方' per Boss spec).
        .windowToolbarStyle(.unified)  // 52 PT default macOS chrome with Liquid Glass unified toolbar background
        // .windowToolbarStyle(.unifiedCompact(showsTitle: false))  // 28 PT compact chrome, no unified toolbar background
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
                // v0.27 macOS-standard cross-component sync (boss 8/27
                // OOB): File → 新建项目 is the macOS-standard menu item
                // (= Cmd+N shortcut) for the file-creation kind. Per boss
                // 8/27 standing rule 'a new feature should appear
                // everywhere = synced', this Menu mirrors the toolbar '+'
                // Menu (= 新建书 / 新建书架). Both sub-items post a
                // NotificationCenter event that NewLibraryOutlineView
                // listens for and triggers the matching sheet.
                Menu("新建项目") {
                    Button("新建书") {
                        NotificationCenter.default.post(name: .wenshuNewBookRequested, object: nil)
                    }
                    Button("新建书架") {
                        NotificationCenter.default.post(name: .wenshuNewShelfRequested, object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
                // v0.27 boss 8/27 OOB: 菜单栏同步 toolbar '导入' button.
                // Per boss 8/27 standing rule 'a new feature should
                // appear everywhere = synced', the menu bar gets a
                // matching 导入 entry (= macOS-standard File → Import
                // Convention; Cmd+Shift+I is the macOS default shortcut
                // for File → Import per developer.apple.com/design/
                // human-interface-guidelines/app-architecture/importing-
                // and-exporting-data). Functionality deferred (= '功能
                // 一会拷问后规划'); placeholder posts a
                // NotificationCenter event so v0.27 followups can
                // listen + implement.
                Button("导入…") {
                    NotificationCenter.default.post(name: .wenshuImportRequested, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销", action: {})
                    .keyboardShortcut("z", modifiers: .command)
                Button("重做", action: {})
                    .keyboardShortcut("Z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Divider()
                // v0.24 fix (Boss 8/25 60th OOB menu bar primary): 4 zone
                // toggle menu items. Per Apple HIG Rule 1.3 (toggle
                // checkmarks for on/off states). Toggle forwards via
                // NotificationCenter to vm (= .commands block can't access
                // vm directly per L20). Static labels (= dynamic checkmark
                // would require vm access which commands lack).
                Button("显示/隐藏 项目管理区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectSidebar)
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("显示/隐藏 素材预览区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.projectPreview)
                }
                Button("显示/隐藏 工具区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.specializedTools)
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("显示/隐藏 聊天区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiChat)
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
                Button("显示/隐藏 动态区") {
                    NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.aiDynamic)
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                Divider()
                Button("恢复默认布局") {
                    NSLog("[wenshu.reset] menu posted wenshuResetLayout")
                    NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                Divider()
                // v0.28 ticket 028-006: Layout edit mode menu entry
                // (= ⌘⇧\ toggles edit mode on/off; per the hermes
                // sibling pattern of `view.flipPanes = mod+\` +
                // `layout.editMode = mod+shift+\`). Posts a
                // NotificationCenter event that the active
                // WorkspaceView's LayoutEditMode singleton listens
                // for and flips the bool (= the menu and the
                // in-window hotkey share the same notification
                // path so the user sees a consistent state).
                Button("Layout edit mode") {
                    NotificationCenter.default.post(name: .wenshuToggleEditMode, object: nil)
                }
                .keyboardShortcut(KeyEquivalent("\\"), modifiers: [.command, .shift])
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

/// 设置页: Pages 范式真值 (v0.21 ticket 06)
/// 老板 8/21 拍 'Pages 范式实现设置面板的 UI, 用 macOS 27 的组件'
/// = 顶部 toolbar (3 个 segmented tab, Pages 真值, 老板画的图 2 红框位置)
/// 不是 macOS Settings { } Scene 自动装标题栏 segmented tab 按钮 (commit 0082bd1fe + 030a58355 真硬违反)
/// Pages 真值 (红框位置) = 窗口内容顶部 toolbar 切换, 不是窗口标题栏按钮
struct SettingView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("wenshu.llm.provider") private var providerSlug: String = Provider.minimaxCn.slug
    // B-05: wenshu.llm.model centralization. The `wenshu.llm.model`
    // UserDefaults key now has a single owner = `AppState.llmModel`.
    // SettingView reads + writes via the appState (an @Observable
    // property) and uses a custom Binding for the Picker so the
    // existing `$llmModel` selection API still works without
    // touching the surrounding body.
    // v0.24 boss验收fix (2026-08-24): default to empty string when no provider
    // key configured (not "MiniMax-M3" which implies a MiniMax provider is
    // selected even when user has no key). UI shows "暂无模型可用，请先配置模型" placeholder
    // when this is empty.
    private var llmModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }
    private var llmModelBinding: Binding<String> {
        Binding(
            get: { appState.llmModel },
            set: { appState.llmModel = $0 }
        )
    }
    @AppStorage("wenshu.llm.reasoningEffort") private var reasoningEffort: String = "medium"
    // v0.24 boss验收fix: @AppStorage so chat '设置' link can jump to provider tab.
    @AppStorage("wenshu.settingsTab") private var selectedTabRaw: String = "general"
    // v0.24 fix: Settings UI exposes user-set value for agent-to-user address.
    // WenshuConductorIdentity.userAddress reads this key at LLM call time.
    // Boss 8/24 clarification: default = 'user' (not 'boss' = hermes-side convention).
    @AppStorage("wenshu.userAddress") private var userAddress: String = "user"
    // v0.32 boss 2026-09-02 OOB ('用 macOS 自带液态玻璃, 跟随系统设置'):
    // the user-tunable Liquid Glass opacity slider + manual @State mirror
    // + UserDefaults key + NotificationCenter wiring was removed
    // (= 134 LOC of self-rolled ladder across App.swift + LiquidGlassOpacity.swift
    // + 4 caller files). Apple canonical .glassEffect(.regular) auto-adapts
    // to system settings (= dark mode / Reduce Transparency / Increase Contrast),
    // so a per-app slider is unnecessary and conflicts with the system.

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
        case general
        case providerApi
        case model
        case agent
        case memory
        case skills
        var id: String { rawValue }
        /// Localized display label (v0.38 P2). Uses the same catalog keys
        /// as the tab Picker rendering, so the segmented control labels
        /// follow the user's OS language.
        var displayName: String {
            switch self {
            case .general: return WenshuI18n.t("settings.tab.general")
            case .providerApi: return WenshuI18n.t("settings.tab.providerApi")
            case .model: return WenshuI18n.t("settings.tab.model")
            case .agent: return WenshuI18n.t("settings.tab.agent")
            case .memory: return WenshuI18n.t("settings.tab.memory")
            case .skills: return WenshuI18n.t("settings.tab.skills")
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .providerApi: return "key.horizontal"
            case .model: return "cpu"
            case .agent: return "person.crop.circle"
            case .memory: return "brain"
            case .skills: return "command"
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
                    Label(tab.displayName, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.chromePaddingXLarge)
            .padding(.top, DesignTokens.chromePaddingLarge)
            .padding(.bottom, DesignTokens.chromePaddingVertical)
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
                case .agent: agentTab
                case .memory: memoryTab
                case .skills: skillsTab
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
            Section(WenshuI18n.t("settings.general.appearance")) {
                Picker(WenshuI18n.t("settings.general.appearance"), selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section(WenshuI18n.t("settings.general.liquidGlass")) {
                // Apple canonical .glassEffect(.regular) auto-applies
                // project-wide (per-pane content background +
                // per-region tab bar + per-region status bar + app
                // root containerBackground) and Apple auto-adapts to:
                //   - dark mode / light mode
                //   - Accessibility > Display > Reduce transparency
                //   - Accessibility > Display > Increase contrast
                Text(WenshuI18n.t("settings.general.liquidGlass.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WenshuI18n.t("settings.general.liquidGlass.hint"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Section(WenshuI18n.t("settings.general.agentAddress")) {
                // v0.24 fix (Boss 8/24 OOB): user-set value for agent-to-user address.
                // Read by WenshuConductorIdentity.userAddress at LLM call time
                // (dynamic per-chat). User cannot modify via chat per AGENTS.md.
                // Reason for no .onChange handler: WenshuConductorIdentity.
                // userAddress reads UserDefaults fresh each LLM call = automatic
                // dynamic propagation, no event-driven mechanism needed.
                TextField(WenshuI18n.t("settings.general.agentAddress"), text: $userAddress, prompt: Text(WenshuI18n.t("settings.general.agentAddress.prompt")))
                    .textFieldStyle(.roundedBorder)
                Text(WenshuI18n.t("settings.general.agentAddress.help"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(WenshuI18n.t("settings.general.misc")) {
                Text(WenshuI18n.t("settings.general.misc.placeholderNote"))
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
                        // v0.27 boss 8/27 OOB: SF 'key' / 'key.fill' → Lucide 'key'.
                        LucideIconSystemFallback(providersWithKeys.contains(p.slug) ? "key.fill" : "key", size: 16)
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
                            // v0.27 boss 8/27 OOB: SF 'checkmark' → Lucide 'check'.
                            LucideIconSystemFallback("checkmark")
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
                            .padding(.leading, DesignTokens.chromePaddingLeading)
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
            // v0.27 boss 8/27 OOB: SF 'key' / 'key.fill' → Lucide 'key'.
            LucideIconSystemFallback(hasKey ? "key.fill" : "key", size: 18)
                .foregroundStyle(hasKey ? Color.green : Color.secondary)
                .frame(width: 18)
            Text(p.name)
                .font(.body)
            Spacer()
            if hasKey {
                Text(keyPrefix12(for: p))
                    .font(.caption.monospaced())
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

                Picker("模型", selection: llmModelBinding) {
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
                Text(WenshuI18n.t("settings.model.reasoning.effortHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("推理")
            }

            Section {
                ForEach(AuxTask.allCases, id: \.self) { task in
                    HStack {
                        // v0.27 boss 8/27 OOB: AuxTask.icon (dynamic SF
                        // name string) → Lucide canonical via helper.
                        LucideIconSystemFallback(task.icon, size: 18)
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

    private var agentTab: some View {
        // v0.38 ticket A (= Settings → Agent 3-pane wire-up):
        // wire LLMConnectorSettingsView (= v0.36 ticket 006 ship, isolated file
        // pre-wire) into Settings scene. 7 connector profile rows rendered.
        LLMConnectorSettingsView(
            activeConnectorID: providerSlug,
            profiles: ConnectorProfileState.allDefaults
        )
        .padding(DesignTokens.chromePaddingMedium)
    }

    private var memoryTab: some View {
        // v0.38 ticket A: wire MemorySettingsView (= v0.35 ticket 009 ship,
        // isolated file pre-wire) into Settings scene. Scope + retention +
        // recent memory entries rendered.
        MemorySettingsView()
            .padding(DesignTokens.chromePaddingMedium)
    }

    private var skillsTab: some View {
        // v0.38 ticket A2: wrap SkillsSettingsView in a small loader view that
        // owns @State skills + triggers .task async load via SkillAdapter.
        // SkillAdapter is an actor (= v0.35 ticket 010 spec); listSkills() is
        // async; SkillsSettingsView is a passive view (= @State skills binding
        // = parent must populate). Loader view bridges the two per SwiftUI
        // canonical state ownership pattern.
        SkillsSettingsLoader()
            .padding(DesignTokens.chromePaddingMedium)
    }

}

/// v0.38 ticket A2: thin loader view that owns the @State array of
/// SkillAdapter.Skill + triggers an async load on appear. Bridges the
/// gap between async actor-isolated SkillAdapter.listSkills() (= v0.35
/// ticket 010 spec) and the passive SkillsSettingsView (= expects an
/// already-populated @State binding). Per Apple SwiftUI canonical state
/// ownership pattern (= child view owns its own data, parent provides
/// the read site).
private struct SkillsSettingsLoader: View {
    @State private var skills: [SkillAdapter.Skill] = []
    @State private var hasLoaded: Bool = false

    var body: some View {
        // v0.38 ticket A2: SkillsSettingsView is a public View with @State
        // binding; passing our @State array as init() seeds its state. The
        // empty-array placeholder ("No skills installed yet") shows briefly
        // while .task fires; once listSkills() returns, the @State
        // reassignment triggers a re-render with the populated list.
        SkillsSettingsView(skills: skills)
            .task {
                let loaded = await SkillAdapter().listSkills()
                await MainActor.run {
                    self.skills = loaded
                    self.hasLoaded = true
                }
            }
            // v0.38 ticket A2: hidden accessibility hint that conveys
            // load state to assistive tech; visible UI is unchanged
            // (= Settings tab is a known site; the user can see skills
            // populate in real time).
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Skills settings" + (hasLoaded ? " (\(skills.count) loaded)" : " (loading)"))
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

/// v0.21 ticket 01 (重做 #7): 透明 helper view — 在 view tree 内捕获 @Environment(\.openSettings) OpenSettingsAction,
/// 注入到 WenshuAppDelegate.openSettings 静态字段, NSMenu "设置…" action 调 closure 弹 SwiftUI Settings { { } Scene
/// (Stack Overflow 65355696 + orchetect/SettingsAccess 真值)
// v0.24 boss验收fix (2026-08-24): accept library + appearanceMode so it can
    // wrap LayoutShellView with the same modifiers as the original WindowGroup.
    private struct SettingsEnvironmentCapturer: View {
        @Environment(\.openSettings) private var openSettings
        let library: WenshuLibrary
        let appearanceMode: AppearanceMode
        /// v0.28 ticket 028-006 followup: layout edit mode state at
        /// the top-level wrapper (= so the ⌘⇧\ hotkey + Window menu
        /// entry work regardless of whether the user is on the
        /// WorkspaceView path or the legacy LayoutShellView path).
        /// The PaneRenderer / LayoutEditBar surface in 028-006 + 028-007
        /// only consumes the boolean when useWorkspace == true; on the
        /// legacy path, toggling the bool still has user-visible effect
        /// (= the EditModeBadge in WorkspaceView, when the user flips
        /// useWorkspace on, would already be ON — saves them a second
        /// keystroke).
        @State private var editMode = LayoutEditMode()
        // B-05: `wenshu.llm.model` now has a single owner =
        // AppState.llmModel. The previous dead `modelName` @AppStorage
        // declaration (= no body reads, removed by the v0.34 toolbar
        // flatten) is dropped here. Captured environment is enough to
        // expose the value to any future nested consumer via
        // `@Environment(AppState.self)`.
        @AppStorage("wenshu.llm.status") private var llmStatus: String = "Idle"
        @AppStorage("wenshu.context.usagePercent") private var contextUsagePercent: Int = 0
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
            //
            // All chrome now lives in LibraryRootView's SwiftUI native
            // `.toolbar { ToolbarItemGroup }` (= Apple's canonical macOS 26
            // toolbar pattern, single source of truth).
LibraryRootView()
            .frame(minWidth: 1280, minHeight: 720)
            .environment(library)
            .preferredColorScheme(appearanceMode.colorScheme)
            // v0.32 boss 2026-09-02 OOB ('窗口级背景用
            // windowBackgroundColor'): restore the window-level
            // opaque background = Apple canonical
            // windowBackgroundColor. Per boss 2026-09-02 OOB
            // correction, the Monterey 12.0.1 Dark Mode
            // reference values for the 4-tier dynamic system
            // color hierarchy are:
            // - windowBackgroundColor    = #323232 (浅, 容器)
            // - underPageBackgroundColor = #282828 (中, 内容)
            // - controlBackgroundColor   = #1E1E1E (深, chrome)
            // - textBackgroundColor      = #1E1E1E (深, chrome)
            //
            // The window background is the lightest tier (= the
            // outermost container). The content panes tint darker
            // (underPageBackgroundColor #282828 = content floats).
            // The chrome panes tint even darker
            // (controlBackgroundColor #1E1E1E = sidebar / tools
            // / tab bar / status bar = recessed chrome). This is
            // the standard Apple HIG 6-pane pattern (= the 6 panes
            // show 3 distinct Apple-canonical tones in dark mode).
            //
            // Note: current local macOS environment is compressing
            // windowBackgroundColor to #1E1E1E (= identical to
            // controlBackgroundColor = no visible delta between
            // tiers). This is likely caused by an accessibility
            // setting (= Increase Contrast or Tinted mode). Per
            // boss 2026-09-02 OOB 'hard rule: Apple API only, do
            // not customize' = do not hardcode; trust the
            // Apple-supplied canonical hierarchy even when local
            // accessibility overrides compress it. Tahoe will
            // re-expand the tiers when the user disables the
            // accessibility override.
            .containerBackground(for: .window) {
                Color(nsColor: .windowBackgroundColor)
            }
            .onAppear {
                WenshuAppDelegate.openSettings = openSettings
                // v0.28 followup (Boss 2026-08-29 OOB '调试视图框架'):
                // removed the titlebar hide loop (= was causing
                // re-render loop). Re-add with proper delay in a
                // follow-up commit.
            }
            // v0.28 ticket 028-006 followup: ⌘⇧\ hotkey + Escape
            // exit at the top-level wrapper (= not just inside
            // WorkspaceView) so the keyboard shortcut works
            // regardless of which layout path the user is on
            // (= LayoutShellView legacy path or WorkspaceView
            // FCP Browser path). The LayoutEditMode singleton
            // persists its state to UserDefaults so the boolean
            // survives path switches (= flipping useWorkspace
            // preserves the edit-mode state).
            .layoutEditHotkey(editMode)
            // Listen for the View menu's "Layout edit mode" entry
            // (= same notification path as the WorkspaceView body;
            // 028-006 followup so it works on both paths).
            .onReceive(NotificationCenter.default.publisher(for: .wenshuToggleEditMode)) { _ in
                editMode.toggle()
            }
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

    /// v0.28 followup: debug Keychain override for cua / dev env without
    /// user-attached login keychain (= the InMemoryKeychainStore stub
    /// prevents SecItemCopyMatching from blocking wenshu main thread
    /// on the Keychain permission modal during dev/verify). Gated by
    /// WENSHU_DEBUG_INMEMORY_KEYCHAIN env var (= 1 = use in-memory stub,
    /// 0 = use real Apple keychain). Production builds never set this.
    static let sharedKeychainBackend: Void = {
        if ProcessInfo.processInfo.environment["WENSHU_DEBUG_INMEMORY_KEYCHAIN"] == "1" {
            ProviderKeychain.setBackendForTesting(InMemoryKeychainStore())
            NSLog("[wenshu.debug] keychain backend = InMemoryKeychainStore (debug override)")
        }
    }()

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
        NSLog("[wenshu.reset] NSMenu resetLayout(_:) called, posting")
        NotificationCenter.default.post(name: .wenshuResetLayout, object: nil)
    }


    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // v0.28 followup: force-evaluate sharedKeychainBackend so the
        // debug override takes effect before any Keychain access.
        _ = Self.sharedKeychainBackend
        // v0.30 boss 8/31 followup (= Spec C2 fix): install a receiver
        // for .wenshuImportRequested (= fired by the zone-header 入驻
        // button). Previously the button was producer-only; this
        // commit adds the matching listener that opens an NSOpenPanel
        // for the user to select an external .ws file or research
        // material to import into the library.
        NotificationCenter.default.addObserver(
            forName: .wenshuImportRequested,
            object: nil,
            queue: .main
        ) { _ in
            let panel = NSOpenPanel()
            panel.title = "入驻素材"
            panel.message = "选择一个 .ws 文件或其他研究资料进行入驻"
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            if panel.runModal() == .OK {
                NSLog("[wenshu.import] user selected \(panel.urls.count) file(s)")
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // v0.28 followup Boss UX round 9 (Boss 2026-08-29 OOB '等下,
        // 那样会没有红黄绿按钮, 也不可以双击放大, 试过了' =
        // titlebarAppearsTransparent + titleVisibility = .hidden
        // removes traffic lights AND double-click-to-zoom
        // (= breaks macOS standard window controls). Don't do that.
        // Keep the macOS native titlebar (= 28 PT compact with
        // traffic lights + double-click-to-zoom) and put the titlebar
        // icons INSIDE it via .toolbar { ToolbarItem(.principal) }
        // (= exactly macOS standard = native toolbar buttons next to
        // traffic lights = matches Apple Pages / Xcode / Mail etc.).
        //
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

/// Zone slot enum (= 6 named cases, one per functional module in
/// the new framework). Used by WorkspaceView's renderTabByKind to
/// dispatch to the right view (= projectSidebar → NewLibraryOutlineView,
/// projectPreview → EntityPreviewPane, editor → editor, etc.).
/// v0.10.3 拆分 chatSidebar + chatDialogue 2 子区后续用, 当前单 aiChat.
enum ZoneSlot {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case aiChat        // 老板 8/18 拍 "上四下两", 下 band 整宽 AI聊天 (含原 v0.10.3 拆的 chatSidebar + chatDialogue)
    case aiDynamic
}

// MARK: - Library outline (项目侧栏嵌入)

/// 项目侧栏内容 (= v0.27 wiring: NewLibraryOutlineView reads from
/// BookStore via @Environment). Replaces v0.25.x WenshuLibrary-backed
/// LibraryOutlineView (= no longer used in production zone).
    struct LibraryOutlineViewContent: View {
        @Environment(BookStore.self) private var bookStore
        var body: some View {
            // v0.30: NewLibraryOutlineView has default dummy binding init.
            NewLibraryOutlineView()
            // v0.28 followup Boss UX round 44 (Boss 2026-08-29 OOB
            // '项目管理区和素材管理区的接缝, 顶栏底栏都对不齐' = the
            // `.padding(.vertical, 2)` was pushing the sidebar content
            // (= NewLibraryOutlineView's tree outline) up by 2 PT,
            // which made the sidebar's bottom status bar (= "书:0")
            // appear higher than the other 3 general panes'
            // (= "章节:0" / "字数:0" / "工具就绪") = 视觉不对齐.
            // Fix = removed `.padding(.vertical, 2)`. The horizontal
            // `.padding(8)` (= 8 PT left/right margin) is preserved
            // for the tree outline indentation.
            .padding(8)
            .environment(bookStore)
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
            case .chat: return "bot"  // v0.25.1 (= ticket 005): 老板 2026-08-26 拍 .bot 直接替换 SF person.crop... (= Lucide-first helper 在 ChatZoneTabBar 里用了, "bot" 命中 Lucide, SF Symbol 作为 fallback). Old (= ticket 015.014 robot face) was SF `person.crop.circle.badge.questionmark` (= Lucifer 没有同名, 只能 Image(systemName:) fallback, 不再使用).
            case .search: return "magnifyingglass"  // 老板 8/25 拍 "保留现在的这个"
            case .settings: return "slider.horizontal.3"  // 老板 8/25 拍 "保留现在的这个"
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
    // B-05: `wenshu.llm.model` is now owned by AppState.llmModel (single
    // source of truth). ChatZoneView reads + writes via the env-injected
    // appState (= same proxy pattern as SettingView above) so the
    // picker / VM sync story (= ticket 43) still holds = both the
    // ChatZoneView picker and ChatViewModel.currentModel read the same
    // canonical value through AppState.
    @Environment(AppState.self) private var appState
    private var currentModel: String {
        get { appState.llmModel }
        nonmutating set { appState.llmModel = newValue }
    }
    // Boss 8/24: '每个区域的 tab 选中状态应该持久化'.
    @AppStorage("wenshu.tabIndex.aiChat") private var selectedTabRaw: String = "对话"
    // v0.24 boss验收fix (Boss 8/25 OOB ticket 015.014): archive flow state.
    // When user clicks archive icon in ChatZoneTabBar, this toggles true and
    // shows confirmation alert. Confirm = archive current session + start new.
    @State private var showingArchiveAlert: Bool = false
    @State private var showingArchiveAlertHover: Bool = false

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
        // B-05 build fix: `appState` is a `@Environment` value (= only
        // available after the view is mounted in the hierarchy), so it
        // cannot be referenced from inside `init`. Construct the
        // ChatViewModel with `appState: nil` and rely on the
        // post-mount wire below (= onAppear sets `vm.appState` via the
        // now-public-within-module setter; for the rare case where
        // ChatZoneView is instantiated, currentModel will resolve to
        // UserDefaults value through the canonical owner after the
        // post-mount wire). ChatZoneView is currently dead code at
        // runtime (= WorkspaceView uses ChatView() directly since
        // v0.34 chrome flatten), so this only matters for the
        // compile path.
        _vm = State(initialValue: ChatViewModel(conductor: conductor, store: store, appState: nil))
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
                ), showingArchiveAlert: $showingArchiveAlert,
                showingArchiveAlertHover: $showingArchiveAlertHover)
                Group {
                    switch selectedTab {
                    case .chat:
                        // v0.24 boss验收fix: ZStack fills full chat zone, help text centered.
                        ZStack {
                            ChatView(conductor: conductor, store: store, vm: vm)
                            if currentModel.isEmpty {
                                ChatHelpTextOverlay {
                                    // v0.34 Apple-API-first #5: the UserDefaults
                                    // .set below writes the same key the
                                    // SettingView's @AppStorage reads (= the
                                    // canonical 'jump to providerApi tab on
                                    // open Settings' pattern, see App.swift:559
                                    // = SettingView's @AppStorage). The previous
                                    // code wrote the key TWICE in a row (= dead
                                    // 2nd write = typo from earlier ticket).
                                    // Kept as UserDefaults because ChatView is a
                                    // Model (= not a View), so @AppStorage is
                                    // not applicable (= @AppStorage requires View
                                    // context). UserDefaults IS the source of
                                    // truth that @AppStorage reads from.
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
                                                // v0.27 boss 8/27 OOB: SF 'checkmark' → Lucide 'check'.
                                                LucideIconSystemFallback("checkmark")
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
                        // v0.27 boss 8/27 OOB: SF 'cpu' → Lucide 'cpu' (same name).
                        LucideIconSystemFallback("cpu")
                            .foregroundStyle(.secondary)
                        Text(currentModel.isEmpty ? "无模型可用" : ModelDisplay.lookup(currentModel).display)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        // v0.27 boss 8/27 OOB: SF 'chevron.up.chevron.down' → Lucide 'chevrons-up-down'.
                        LucideIconSystemFallback("chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, DesignTokens.chromePaddingSmall)
                    .frame(height: DesignTokens.chromeHeight, alignment: .bottomLeading)
                }
                // v0.21 ticket 42: Apple 真值组合 .menuStyle(.button) + .buttonStyle(.plain) = 去外壳 (Apple SwiftUI 14+ deprecated .borderedButton 提示路径)
                .menuStyle(.button)
                .buttonStyle(.plain)
                .padding(.leading, DesignTokens.chromePaddingPickerLeading)
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
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(vm.contextUsed, vm.contextMax)), total: Double(max(1, vm.contextMax)))
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(vm.contextUsed >= vm.contextMax ? .red : (vm.contextUsed > vm.contextMax * 3 / 4 ? .orange : .green))
                }
                .padding(.trailing, DesignTokens.chromePaddingTrailing)
                .padding(.bottom, DesignTokens.chromePaddingSmall)
                .frame(height: DesignTokens.chromeHeight, alignment: .bottomTrailing)
            }
            // v0.32 boss 2026-09-02 OOB ('全走 apple api 默认; 不
            // 要自写颜色 wrapper'): replace DesignColor.zoneSurface
            // (= wrapper enum wrapping Color(nsColor: .control
            // BackgroundColor)) with the bare Apple API call. The
            // wrapper added an extra type with no semantic value
            // (= it just renamed an Apple NSColor static property).
            .background(Color(nsColor: .controlBackgroundColor))
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
    // v0.30 boss 8/31 OOB: hover state for the archive button (= passed
    // down from owner struct since SwiftUI @State can't be observed
    // across nested struct boundaries without @Binding).
    @Binding var showingArchiveAlertHover: Bool
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // OOB '能不能让那个小横线的动画变成左右移动 不是渐隐渐显' =
    // matchedGeometryEffect pattern (= owner wants L/R slide, NOT
    // crossfade). Even though ChatZoneTabBar currently only shows 1
    // visible tab (= .chat, filtered via ForEach with .chat only),
    // the namespace + matchedGeometryEffect pattern is applied for
    // consistency with DynamicZoneTabBar + ZoneContentTabBar. If owner
    // later unhides .search / .settings tabs (= Boss 8/22 sixth OOB
    // '老板拍 backlog 20 chat tab 1/2/3 真切换'), the slide animation
    // already works (= no extra retrofit).
    @Namespace private var tabBarNamespace

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                ForEach(ChatZoneView.ChatZoneTab.allCases.filter { $0 == .chat }) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        // v0.24 boss验收fix: icon only, no title label.
                        // v0.25.1 (= ticket 021 followup Apple HIG canonical):
                        // Color.clear as BASE (= label intrinsic = 28×28 =
                        // Button hit area), chatZoneTabBarIcon Lucide .bot /
                        // .inbox as .overlay centered. Previous ticket 020
                        // had it inverted (= clipped to 18×18).
                        Color.clear
                            .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                            .overlay(alignment: .center) {
                                chatZoneTabBarIcon(tab.icon)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                                    .foregroundStyle(tab == selectedTab ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                            // v0.25.1 (= ticket 018 explicit 28×28 hot zone):
                            // owner 2026-08-26 OOB '现在的 ICON 还是不是很好点
                            // 能不能写一个 28×28 的透明矩形的热区' = ticket
                            // 008's .padding(.all, chatTabHitPad) was still
                            // flaky (= owner reported icons hard to click).
                            // Replace with explicit Color.clear.frame(28, 28)
                            // .contentShape(.rect) = Apple HIG canonical
                            // pattern for plain-style button hot area.
                            // (v0.34 Apple-API-first #3: removed inner
                            // `.buttonStyle(IconButtonStyle())` here = it was
                            // a no-op pass-through superseded by the outer
                            // `.buttonStyle(.plain)` below.)
                            // v0.25.1 (= ticket 010 tab selected-state underline):
                            // owner 2026-08-26 OOB '现在的 tab 的选定状态 ICON 下
                            // 没有那个选定的小横线' = add Apple HIG canonical
                            // selected-tab underline (= 2 PT accent bar at
                            // bottom of selected tab, full button width).
                            .overlay(alignment: .bottom) {
                                if tab == selectedTab {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(height: DesignTokens.tabUnderlineHeight)
                                        // v0.28 followup Boss UX (Boss 2026-08-30
                                        // OOB '加满圆角, 两头圆'): .clipShape(Capsule())
                                        // for fully rounded ends on the underline.
                                        .clipShape(Capsule())
                                        // v0.25.1 (= ticket 013): matchedGeometryEffect
                                        // namespace ID on the bar Rectangle so
                                        // SwiftUI can slide it between tab
                                        // positions (= replaces ticket 010's
                                        // per-button crossfade with single shared
                                        // bar translating L/R). When owner
                                        // unhides .search / .settings tabs (=
                                        // Boss 8/22 sixth OOB backlog 20), the
                                        // slide animation already works.
                                        .matchedGeometryEffect(id: "tabBarUnderline", in: tabBarNamespace, isSource: true)
                                    .offset(y: 0)  // v0.25.1 ticket 024: offset adjusted for tabUnderlineHeight 1 PT (= underline at y=27-28 PT, flush with toolbar bottom; 1 PT below icon bottom = 2 PT gap)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .background(Color.clear)
                }
            }
            .padding(.leading, DesignTokens.chromePaddingLeading)

            Spacer()

            // v0.24 boss验收fix (Boss 8/25 fourth OOB ticket 015.014): archive
            // icon at top-right (= Boss image 红框 position). 18 PT right
            // padding per Boss spec. Click triggers showingArchiveAlert.
            // v0.25.1 (= ticket 005): right-side chat-zone icon = Lucide
            // .inbox (= owner 2026-08-26 OOB, replacing the prior "archivebox"
            // SF Symbol archive-flow icon). Minimal-impact same helper.
            // v0.25.1 (= ticket 007 chat-zone tab hot area):
            // owner 2026-08-26 OOB '热区有点问题 现在好像是 ICON 本身是热区
            // 需要你让 ICON 18×18 的区域是热区 不然很难点的到' = inflate
            // the clickable area from 18×18 to 28×28 PT (= boss 8/11 fix3
            // 'four chat tab height set to 28 PT'). Hot zone paired with
            // .contentShape(.rect()) so the entire 28×28 PT box is the
            // click target (= not the visual glyph only).
            //
            // v0.30 boss 8/31 OOB '红框里的 ICON 按钮也实现悬浮效果, 和
            // TEB 同样即可': added hover state + .onHover + .background
            // tint (= matches PaneIconTab's hover pattern = Color
            // .accentColor.opacity(0.12) on hover, clipped to rounded
            // rect).
            Button {
                showingArchiveAlert = true
            } label: {
                // v0.25.1 (= ticket 022 chat zone archive button — old
                // ICON removal): owner 2026-08-26 OOB '聊天右上角 那个
                // 老的 ICON 又出现了 删掉' = previous ticket 021 patch
                // wrapped the archive button label in BOTH chatZoneTabBarIcon
                // ('inbox') AND a redundant Image(systemName: 'archivebox')
                // inside the Color.clear overlay (= 2 icons rendered at
                // the same position, the SF archivebox was the 'old
                // ICON' that boss wanted removed). Fix = use chatZoneTabBarIcon
                // ('inbox') directly as the label (= Lucide .inbox is the
                // canonical archive flow icon per ticket 005), drop the
                // duplicate SF archivebox.
                chatZoneTabBarIcon("inbox")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            // v0.30 boss 8/31 OOB: hover tint for the archive button.
            // Matches PaneIconTab + sidebar zone header button pattern.
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(showingArchiveAlertHover
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(Color.clear))
            )
            .onHover { hovering in
                showingArchiveAlertHover = hovering
            }
            .help("归档当前会话")
            .padding(.trailing, DesignTokens.chromePaddingTrailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.chromeHeight)
        // v0.32 boss 2026-09-02 OOB: replace DesignColor.zoneSurface
        // wrapper with bare Color(nsColor: .controlBackgroundColor).
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            // v0.32 boss 2026-09-02 OOB: replace DesignColor.splitterLine
            // wrapper with bare Color(nsColor: .separatorColor) (= Apple
            // canonical separator = dark/light adaptive).
            Color(nsColor: .separatorColor).frame(height: 1)
        }
        .animation(.default, value: selectedTab)
    }

    /// v0.25.1 (= ticket 005): Lucide-first view helper for chat-zone toolbar
    /// icons. Same fallback semantics as ZoneIcon: try `Lucide(name:)` first,
    /// fall back to `Image(systemName:)` on nil. Used by both the left tab
    /// button (ForEach filtered to .chat) and the right archive-flow button.
    @ViewBuilder
    private func chatZoneTabBarIcon(_ systemName: String) -> some View {
        // v0.27 boss 8/27 OOB: use the project-wide LucideIcon helper.
        LucideIconSystemFallback(systemName)
    }
}

/// v0.21 ticket 43: ChatZoneStubView = 第 2/3 个 tab 占位视图 (老板拍 '先放着, 后面实现')
/// Apple HIG 真值: VStack 居中 + 大 icon + '开发中' placeholder 文字 + 灰色调
struct ChatZoneStubView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            // v0.27 boss 8/27 OOB: dynamic icon string → Lucide via helper.
            LucideIconSystemFallback(icon, size: 48)
                .foregroundStyle(.tertiary)
            Text("\(title) (开发中)")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // v0.32 boss 2026-09-02 OOB: replace DesignColor.zoneSurface
        // wrapper with bare Color(nsColor: .controlBackgroundColor).
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
