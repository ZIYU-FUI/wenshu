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
    /// 动态区功能区 (#1e1e1e, 老板 8/18 拍比 #202020 略深)
    /// v0.10 之前用硬编码 (#1e1e1e, #202020), 老板 8/18 答 Q4 "保留设计图色值"
    static let dynamicZoneSurface: Color = Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x1e / 255)
    /// 强调蓝 (boss Sketch #4a60b2) → Color.accentColor
    static let accentBlue: Color = .accentColor
    /// 拖拽线 (boss Sketch #000000) → NSColor.black (dark/light 都可见)
    static let splitterLine: Color = Color(nsColor: .black)
}

enum LayoutTokens {
    // 设计基准 (Apple macOS 27 1x 下 1 PT = 1 PX)
    static let designW: CGFloat = 1920
    static let designH: CGFloat = 984

    // 比例算子 (0~1, 基准 1920×984)
    static let titleRatio: CGFloat = 0                    // 老板 8/18 拍 52 PT 顶栏 = macOS 52 PT unified titlebar chrome, 老板自定义 TitleBarZone 跳过 (省一栏)
    static let bandRatio: CGFloat = 465.0 / 984.0        // = 0.4726 (老板 8/18 改 465 PT, 总 52+465+2+465 = 984)
    static let toolbarRatio: CGFloat = 30.0 / 465.0      // = 0.0645 (zone 顶/底 30, 跟 bandH 465 对齐, 老板 8/18 改 465 PT)
    static let labelFontRatio: CGFloat = 12.0 / 472.0       // = 0.0254 (zone label 字号 12 PT 比例, 老板 8/18 拍)
    // 老板 8/18 拍 horizontalSplitterRatio 数对公式: 1 PT 横拖拽线 H 比率 (v0.10.6 立)
    // v0.10.6 删 splitterHitRatio (v0.10.6 之前是死代码, NativeSplitter wrapper frame 改 1 PT 视觉线后没人用)
    static let horizontalSplitterRatio: CGFloat = 2.0 / 984.0  // = 0.0020 (2 PT 横拖拽线 H 比率, 老板 8/18 拍 2 PT 粗)

    // 上 band 4 zone 数对公式: (200, 中间 1, 中间 2, 400) = 1920
    // 老板 8/18 拍 "数对" = 拖拽线 1 PT 视觉线摊给左右 zone (各 0.5 PT)
    // 中间 1 + 中间 2 = 1920 - 200 - 400 = 1320
    // 维持原值 558 + 762 (中间 1 + 中间 2 = 1320) = 上 band 4 zone 1920 ✓
    static let projectSidebarRatio: CGFloat = 200.0 / 1920.0
    static let projectPreviewRatio: CGFloat = 520.0 / 1920.0  // 老板 8/18 改 520 PT (201,52,520,465)
    static let editorWRatio: CGFloat = 797.0 / 1920.0         // 老板 8/18 改 797 PT (722,52,797,465)
    static let toolsWRatio: CGFloat = 400.0 / 1920.0

    // 下 band 3 zone 数对公式: (200, 聊天对话吸剩余, 400) = 1920
    // 老板 8/18 拍 "多出来的都可以放在聊天区中" = 聊天对话 = 1920 - 200 - 400 = 1320
    static let chatSidebarRatio: CGFloat = 200.0 / 1920.0
    static let chatDialogueRatio: CGFloat = 1318.0 / 1920.0  // 老板 8/18 改: 1319 - 1 - 1 = 1318 PT
    static let dynamicWRatio: CGFloat = 400.0 / 1920.0

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041


    // 顶栏色块比例 (老板 8/18 Q3 答: 22/82/142 起点 + 38 PT 宽 + 60 PT 等距)
    static let iconLeadingRatio: CGFloat = 22.0 / 1920.0  // 起点 22 PT
    static let iconSizeRatio: CGFloat = 38.0 / 1920.0     // 38 PT 边长
    static let iconSpacingRatio: CGFloat = 60.0 / 1920.0  // 60 PT 等距
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

@main
struct WenshuApp: App {
    @NSApplicationDelegateAdaptor(WenshuAppDelegate.self) var appDelegate

    @State private var library = WenshuLibrary(
        store: FileSystemLibraryStore(rootURL: LibraryRoot.ensureDefault())
    )

    var body: some Scene {
        WindowGroup("文枢") {
            LayoutShellView()
                .environment(library)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)  // 老板 8/18 拍 macOS 52 PT unified titlebar chrome = 老板自定义 52 PT 顶栏, 视觉合一
        .windowResizability(.contentSize)
        .commands {
            // File 菜单: 新建项目 (cmd+n)
            CommandGroup(replacing: .newItem) {
                Button("新建项目") {
                    // TODO: v0.10+ 接 WenshuLibrary.addShelf
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            // 视图菜单: 老板 8/18 拍 "菜单栏, 显示菜单实现, 重置界面布局功能, 用于一键恢复布局到默认"
            // Apple HIG: CommandMenu 加 top-level 菜单, 在 Window 菜单左侧
            CommandMenu("视图") {
                Button("恢复默认布局") {
                    // 调用 LayoutShellViewModel.reset() 把 4 个 offset 还原 0
                    // 当前 LayoutShellView 用 @State 私有 vm, 暂时通过通知桥接
                    NotificationCenter.default.post(
                        name: .wenshuResetLayout,
                        object: nil
                    )
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])  // cmd+shift+r 跟 Xcode 一致
            }
        }
    }
}

/// AppDelegate: 初始窗口尺寸 1920×984 PT, 用 NSWindow.center() 居中 (Apple HIG).
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApplication.shared.windows.first else { return }
        // 初始窗口尺寸 = 老板 Sketch 设计基准 1920×984 PT (1:1 PX, macOS 27 1x)
        // 之后窗口 resize 会通过 GeometryReader × 比例算子自适应任意尺寸
        window.setContentSize(NSSize(
            width: LayoutTokens.designW,
            height: LayoutTokens.designH
        ))
        window.center()  // Apple HIG: NSWindow 自带 center, 不用手算
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - 6 区 layout shell (1:1 落 6 master)

struct LayoutShellView: View {
    /// v0.10.1 拖拽交互: VM 持有 5 个竖拖拽线 ratio 偏移, 6 个 splitter 的 onDrag 调 vm.adjust*
    @State private var vm = LayoutShellViewModel()

    var body: some View {
        // 老板 8/18 拍 "菜单栏, 重置界面布局" → 视图菜单的 "恢复默认布局" 通过通知桥接 vm.reset()
        // NotificationCenter.default 拿通知 (跟 SwiftUI @Observable 配合 OK, Swift 6 兼容)
        Group { contentView }
            .onReceive(NotificationCenter.default.publisher(for: .wenshuResetLayout)) { _ in
                vm.reset()
            }
    }

    private var contentView: some View {
        // 老板 8/18 数对公式: 52 (老板顶栏=macOS chrome) + 465 + 2 + 465 = 984
        // 52 PT 顶栏由 macOS unified titlebar chrome 接管 (省 老板自定义 顶栏 渲染, 避免重复)
        let totalW = LayoutTokens.designW
        let bandH = LayoutTokens.designH * LayoutTokens.bandRatio  // 465
        return VStack(spacing: 0) {
            UpperBandZone(vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: totalW, height: bandH)
            HorizontalDragSplitter(width: totalW, onDrag: { _ in vm.adjustBandSplit() })
            LowerBandZone(vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: totalW, height: bandH)
        }
    }
}

// MARK: - 上 band (小说管理区): 3 区域模块 + 3 拖拽线-竖

struct UpperBandZone: View {
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        // ratio 走 vm (vm.*Ratio = LayoutTokens 默认 + 拖拽 offset 累加)
        let sidebar = totalW * CGFloat(vm.projectSidebarRatio)
        let preview = totalW * CGFloat(vm.projectPreviewRatio)
        let editor  = totalW * CGFloat(vm.editorWRatio)
        let tools   = totalW * CGFloat(vm.toolsWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .projectSidebar, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: sidebar, height: bandH)
            // D_v1: 项目侧栏 / 项目预览
            VerticalDragSplitter(height: bandH, onDrag: { dx in vm.adjustSidebarPreview(delta: dx, totalWidth: totalW) })
            ZoneModule(slot: .projectPreview, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: preview, height: bandH)
            // D_v2: 项目预览 / 编辑器
            VerticalDragSplitter(height: bandH, onDrag: { dx in vm.adjustPreviewEditor(delta: dx, totalWidth: totalW) })
            ZoneModule(slot: .editor, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: editor, height: bandH)
            // D_v3: 编辑器 / 专用工具
            VerticalDragSplitter(height: bandH, onDrag: { dx in vm.adjustEditorTools(delta: dx, totalWidth: totalW) })
            ZoneModule(slot: .specializedTools, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: tools, height: bandH)
        }
    }
}

// MARK: - 下 band (聊天管理区): 2 区域模块 + 2 拖拽线-竖

struct LowerBandZone: View {
    /// v0.10.3 老板 8/18 拍下 band 3 区 = 聊天侧栏 200 + 聊天对话 1316 + 动态区 403
    /// 2 拖拽线 D_v4 (x=200 侧栏/对话) + D_v5 (x=1516 对话/动态区)
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        let sidebarW = totalW * CGFloat(vm.chatSidebarRatio)
        let dialogueW = totalW * CGFloat(vm.chatDialogueRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .chatSidebar, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: sidebarW, height: bandH)
            // D_v4: 聊天侧栏 / 聊天对话
            VerticalDragSplitter(height: bandH, onDrag: { dx in vm.adjustChatSidebar(delta: dx, totalWidth: totalW) })
            ZoneModule(slot: .chatDialogue, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: dialogueW, height: bandH)
            // D_v5: 聊天对话 / 动态区
            VerticalDragSplitter(height: bandH, onDrag: { dx in vm.adjustChatDynamic(delta: dx, totalWidth: totalW) })
            ZoneModule(slot: .dynamicZone, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: dynamicW, height: bandH)
        }
    }
}

// MARK: - 6 master 1:1 落 SwiftUI 子组件

/// Master 1: 标题栏 (1920×39)
struct TitleBarZone: View {
    var body: some View {
        DesignColor.titleBar
    }
}

/// Master 2: 区域顶部工具栏 (boss Sketch 真值: 30 PT 高 + #202020 + 3 蓝 ICON 占位 + 1 PT 黑色底部分割线)
/// 区域顶部工具栏 (boss Sketch 真值: 30 PT 高, 蓝 ICON 占位)
/// v0.10.10d: 删底部 1 PT 分割线 (老板 8/18 拍 "对齐了, 不用文字标签" + 6 拖拽线已经够了, 不要 toolbar 内部多余线)
struct ZoneTopToolbar: View {
    let iconSlots: Int
    let totalW: CGFloat
    var body: some View {
        let iconSize = totalW * LayoutTokens.iconSizeRatio
        let iconSpacing = totalW * LayoutTokens.iconSpacingRatio
        let iconLeading = totalW * LayoutTokens.iconLeadingRatio

        // Apple Semantic 顶栏底色 (跟 zoneSurface 同源)
        DesignColor.zoneSurface
            .overlay(alignment: .topLeading) {
                if iconSlots > 0 {
                    HStack(spacing: iconSpacing) {
                        ForEach(0..<iconSlots, id: \.self) { _ in
                            DesignColor.accentBlue
                                .frame(width: iconSize, height: iconSize)
                        }
                    }
                    .padding(.leading, iconLeading)
                }
            }
    }
}

/// 区域底部工具栏 (boss Sketch 真值: 30 PT 高, 净底)
/// v0.10.10d: 删顶部 1 PT 分割线 (老板拍 "对齐了", 6 拖拽线够用)
struct ZoneBottomToolbar: View {
    var body: some View {
        DesignColor.zoneSurface
    }
}

/// Master 4: 区域模块 (顶 30 + 内容 + 底 30 = 472 PT, 接受 6 slot)
struct ZoneModule: View {
    let slot: ZoneSlot
    let vm: LayoutShellViewModel
    let totalW: CGFloat  // 父 band 宽, 算比例
    let bandH: CGFloat
    @Environment(WenshuLibrary.self) private var library

    private var toolbarH: CGFloat { bandH * LayoutTokens.toolbarRatio }
    /// 老板 8/18 Q2 答: 4 PT inset = 单一垂直方向 (spec §3.2 "背景 y=60~884, 正文 y=64~882", 上下 4 PT 视觉下沉)
    private var editorInset: CGFloat { bandH * LayoutTokens.editorInsetRatio }  // 4 PT 单一垂直
    // v0.10.3: chatSidebar / chatDialogue 走 vm ratio
    private var chatSidebar: CGFloat { totalW * CGFloat(vm.chatSidebarRatio) }
    // v0.10.8: 撤掉 chatInputW/H 私有属性, 老板 8/18 拍 "新图没画聊天输入框"
    private var innerBandH: CGFloat { bandH - 2 * toolbarH }  // 顶栏底栏间内容区

    var body: some View {
        VStack(spacing: 0) {
            ZoneTopToolbar(iconSlots: slot == .projectPreview ? 3 : 0, totalW: totalW)  // 老板 8/18 拍 "六个区域都用这一个组件", 但只有项目预览画 3 蓝 ICON (其他 zone 后续 override 不同色, 当前 0)
                .frame(height: toolbarH)
            content
                .frame(maxHeight: .infinity)
            ZoneBottomToolbar()
                .frame(height: toolbarH)
        }
        .background(slot == .dynamicZone ? DesignColor.dynamicZoneSurface : .clear)
    }

    @ViewBuilder
    private var content: some View {
        switch slot {
        case .projectSidebar:
            // 项目侧栏嵌入 WenshuLibrary 真实内容 (LIBRARY overlay label v0.10.10d 删)
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                LibraryOutlineViewContent(library: library)
            }
        case .projectPreview:
            DesignColor.zoneSurface
        case .editor:
            // 老板 8/18 Q2 答: 4 PT inset 两层设计, 不要删
            DesignColor.zoneSurface
                .overlay {
                    Color.white.opacity(0.55)
                        .padding(editorInset)
                }
        case .specializedTools:
            DesignColor.zoneSurface
        case .chatSidebar:
            DesignColor.zoneSurface
        case .chatDialogue:
            // 老板 8/18 拍 "新图好像没有画这个聊天框" = 净底, 无输入框
            DesignColor.zoneSurface
        case .dynamicZone:
            DesignColor.dynamicZoneSurface
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
    case chatSidebar    // v0.10.3 新增: 下 band 聊天侧栏 (200 PT)
    case chatDialogue   // v0.10.3 新增: 下 band 聊天对话 (1316 PT 含 D_v4 hit area)
    case dynamicZone
}

// MARK: - Library outline (项目侧栏嵌入)

/// 项目侧栏内容 (WenshuLibrary 真实内容)
/// v0.10.10d: 删 LIBRARY overlay label (老板 8/18 拍 "对齐了, 不用文字标签")
struct LibraryOutlineViewContent: View {
    let library: WenshuLibrary
    var body: some View {
        LibraryOutlineView(library: library)
            .padding(.vertical, 2)
            .padding(8)
            .allowsHitTesting(false)
    }
    private var libraryHeader: String {
        let count = library.shelves.count
        return count == 0 ? "LIBRARY" : "LIBRARY · \(count) 个书架"
    }
}
