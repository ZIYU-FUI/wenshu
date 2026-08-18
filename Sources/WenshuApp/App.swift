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

// MARK: - Layout tokens (比例算子 0~1, 老板 8/18 答 "1:1 PT 真值" + 8/18 再拍 "换算成比例")
//
// 数据源: Sketch AF7B1C87 / Artboard 首页 1920×984 PT 1:1 落
// 公式: layoutPT(token) = totalW * ratio (e.g. projectSidebar ratio = 200/1920 = 0.1042)
// Apple HIG responsive: GeometryReader 拿窗口实际尺寸 × 比例 = 任何窗口大小 1:1 自适应

enum LayoutTokens {
    // 设计基准 (Apple macOS 27 1x 下 1 PT = 1 PX)
    static let designW: CGFloat = 1920
    static let designH: CGFloat = 984

    // 比例算子 (0~1, 基准 1920×984)
    static let titleRatio: CGFloat = 39.0 / 984.0         // = 0.0396
    static let bandRatio: CGFloat = 472.0 / 984.0        // = 0.4797 (上下 band 各半)
    static let toolbarRatio: CGFloat = 30.0 / 472.0      // = 0.0636 (zone 顶/底 30)
    static let splitterHitRatio: CGFloat = 6.0 / 1920.0  // = 0.0031 (6 PT hit area 居中 1 PT 视觉线)

    // 上 band zone 列宽比例 (基准 1920)
    static let projectSidebarRatio: CGFloat = 200.5 / 1920.0  // 200 + 0.5 (D_v1 左半边 1PT 视觉线)
    static let projectPreviewRatio: CGFloat = 558.0 / 1920.0  // 557 + 0.5 (D_v1 右) + 0.5 (D_v2 左)
    static let editorWRatio: CGFloat = 758.0 / 1920.0         // 757 + 0.5 (D_v2 右) + 0.5 (D_v3 左)
    static let toolsWRatio: CGFloat = 403.5 / 1920.0         // 403 + 0.5 (D_v3 右)

    // 下 band zone 列宽比例 (基准 1920)
    static let chatManagementRatio: CGFloat = 1516.5 / 1920.0  // 1516 + 0.5 (D_v5 左), 内部 D_v4 在 chatManagement 内, 不算下 band 总宽
    static let chatSidebarRatio: CGFloat = 200.5 / 1920.0     // 200 + 0.5 (D_v4 左)
    static let chatDialogueRatio: CGFloat = 1516.5 / 1920.0  // 1516 (含 D_v4 6PT) + 0.5 (D_v5 左)  [v0.10.1 D_v4 内嵌 = chatManagement 不再分侧栏/对话]
    static let dynamicWRatio: CGFloat = 403.5 / 1920.0        // 403 + 0.5 (D_v5 右)

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInsetRatio: CGFloat = 4.0 / 984.0  // = 0.0041
    // 聊天输入框 (boss Sketch #4a60b2 蓝, 2590×94)
    static let chatInputWRatio: CGFloat = 1296.0 / 1920.0  // = 0.6750
    static let chatInputHRatio: CGFloat = 94.0 / 984.0     // = 0.0955

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
        let delay = Double(env["WS_SCREENSHOT_DELAY"] ?? "2.0") ?? 2.0
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
        .windowStyle(.hiddenTitleBar)  // 老板 8/18 拍 1:1 PT 落, 不要 macOS 系统 title bar chrome 跟 39 PT TitleBarZone 撞色
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建项目") {
                    // TODO: v0.10+ 接 WenshuLibrary.addShelf
                }
                .keyboardShortcut("n", modifiers: .command)
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
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let titleH = totalH * LayoutTokens.titleRatio
            let bandH = totalH * LayoutTokens.bandRatio
            VStack(spacing: 0) {
                TitleBarZone()
                    .frame(width: totalW, height: titleH)
                UpperBandZone(vm: vm, totalW: totalW, bandH: bandH)
                    .frame(width: totalW, height: bandH)
                HorizontalDragSplitter(width: totalW, onDrag: { _ in vm.adjustBandSplit() })
                LowerBandZone(vm: vm, totalW: totalW, bandH: bandH)
                    .frame(width: totalW, height: bandH)
            }
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
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        // v0.10.1: chatManagement 不再嵌套 D_v4, chatDialogueRatio = 完整 chatManagement zone ratio
        let chatMgmt = totalW * CGFloat(vm.chatDialogueRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .chatManagement, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: chatMgmt, height: bandH)
            // D_v5: 聊天对话 / 动态区 (注: D_v4 在 chatManagement 内部)
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

/// Master 2: 区域顶部工具栏 (iconSlots=3 时画 3 个 38×38 蓝 ICON 占位, 比例)
struct ZoneTopToolbar: View {
    let iconSlots: Int
    let totalW: CGFloat
    var body: some View {
        let iconSize = totalW * LayoutTokens.iconSizeRatio
        let iconSpacing = totalW * LayoutTokens.iconSpacingRatio
        let iconLeading = totalW * LayoutTokens.iconLeadingRatio
        DesignColor.zoneSurface
            .overlay(alignment: .leading) {
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

/// Master 3: 区域底部工具栏 (30 PT 高, 复用)
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
    private var editorInset: CGFloat { totalW * LayoutTokens.editorInsetRatio + bandH * LayoutTokens.editorInsetRatio }  // 4 PT 算水平+垂直近似
    // v0.10.1: chatManagement 不再嵌套 D_v4, 不需要 chatSidebar 单独 ratio
    private var chatSidebar: CGFloat { 0 }
    private var chatInputW: CGFloat { totalW * LayoutTokens.chatInputWRatio }
    private var chatInputH: CGFloat { bandH * LayoutTokens.chatInputHRatio }
    private var innerBandH: CGFloat { bandH - 2 * toolbarH }  // 顶栏底栏间内容区

    var body: some View {
        VStack(spacing: 0) {
            ZoneTopToolbar(iconSlots: slot == .projectPreview ? 3 : 0, totalW: totalW)
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
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                LibraryOutlineViewContent(library: library)
            }
        case .projectPreview:
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                zoneLabel("项目预览")
            }
        case .editor:
            // 老板 8/18 Q2 答: 4 PT inset 两层设计, 不要删
            DesignColor.zoneSurface
                .overlay {
                    Color.white.opacity(0.55)
                        .padding(editorInset)
                }
        case .specializedTools:
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                zoneLabel("专用工具")
            }
        case .chatManagement:
            // v0.10.1: 内嵌 D_v4 几何脱钩 5 PT (老板 Sketch 200+6+1310=1516 含 hit area, 我 ratio 算不出 5 PT hit), 暂移除内嵌 D_v4
            // v0.10.2 补: 内 D_v4 hit area 6 PT 拆 chatSidebar/chatDialogue 比例
            // 当前 chatManagement 整 zone (1 个大区, 不分侧栏/对话)
            DesignColor.zoneSurface
                .overlay(alignment: .topLeading) { zoneLabel("聊天管理") }
                .overlay(alignment: .bottom) {
                    DesignColor.accentBlue
                        .frame(width: chatInputW, height: chatInputH)
                        .padding(.bottom, bandH * 0.016)
                }
        case .dynamicZone:
            Color.clear.overlay(alignment: .topLeading) {
                zoneLabel("动态区")
            }
        }
    }

    private func zoneLabel(_ name: String) -> some View {
        Text(name)
            .font(.system(size: bandH * 0.0255, weight: .medium))  // 12/472 比例
            .foregroundStyle(.tertiary)
            .padding(bandH * 0.0255)
            .allowsHitTesting(false)
    }
}

/// 6 instance 槽位 (boss Sketch 组件化 6 master 派生)
enum ZoneSlot {
    case projectSidebar
    case projectPreview
    case editor
    case specializedTools
    case chatManagement
    case dynamicZone
}

// MARK: - Library outline (项目侧栏嵌入)

struct LibraryOutlineViewContent: View {
    let library: WenshuLibrary
    var body: some View {
        LibraryOutlineView(library: library)
            .overlay(alignment: .topLeading) {
                Text(libraryHeader)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .padding(8)
                    .allowsHitTesting(false)
            }
    }
    private var libraryHeader: String {
        let count = library.shelves.count
        return count == 0 ? "LIBRARY" : "LIBRARY · \(count) 个书架"
    }
}
