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
    static let projectSidebarRatio: CGFloat = 200.0 / 1920.0  // = 0.1042
    static let projectPreviewRatio: CGFloat = 557.0 / 1920.0  // = 0.2901
    static let editorWRatio: CGFloat = 757.0 / 1920.0         // = 0.3943
    static let toolsWRatio: CGFloat = 403.0 / 1920.0         // = 0.2099

    // 下 band zone 列宽比例 (基准 1920)
    static let chatManagementRatio: CGFloat = 1516.0 / 1920.0  // = 0.7896 (内部嵌套 200+6+1310)
    static let chatSidebarRatio: CGFloat = 200.0 / 1920.0     // = 0.1042
    static let chatDialogueRatio: CGFloat = 1310.0 / 1920.0  // = 0.6823
    static let dynamicWRatio: CGFloat = 403.0 / 1920.0        // = 0.2099

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
    var body: some View {
        // GeometryReader 拿窗口实际尺寸 × 比例 = 任意窗口大小 1:1 自适应
        // 基准设计 1920×984, 实际窗口 = 比例 × 实尺寸
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let titleH = totalH * LayoutTokens.titleRatio
            let bandH = totalH * LayoutTokens.bandRatio
            VStack(spacing: 0) {
                TitleBarZone()
                    .frame(width: totalW, height: titleH)
                UpperBandZone(totalW: totalW, bandH: bandH)
                    .frame(width: totalW, height: bandH)
                HorizontalDragSplitter(width: totalW)
                LowerBandZone(totalW: totalW, bandH: bandH)
                    .frame(width: totalW, height: bandH)
            }
        }
    }
}

// MARK: - 上 band (小说管理区): 3 区域模块 + 3 拖拽线-竖

struct UpperBandZone: View {
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        let sidebar = totalW * LayoutTokens.projectSidebarRatio
        let preview = totalW * LayoutTokens.projectPreviewRatio
        let editor  = totalW * LayoutTokens.editorWRatio
        let tools   = totalW * LayoutTokens.toolsWRatio
        HStack(spacing: 0) {
            ZoneModule(slot: .projectSidebar, totalW: totalW, bandH: bandH)
                .frame(width: sidebar, height: bandH)
            VerticalDragSplitter(height: bandH)
            ZoneModule(slot: .projectPreview, totalW: totalW, bandH: bandH)
                .frame(width: preview, height: bandH)
            VerticalDragSplitter(height: bandH)
            ZoneModule(slot: .editor, totalW: totalW, bandH: bandH)
                .frame(width: editor, height: bandH)
            VerticalDragSplitter(height: bandH)
            ZoneModule(slot: .specializedTools, totalW: totalW, bandH: bandH)
                .frame(width: tools, height: bandH)
        }
    }
}

// MARK: - 下 band (聊天管理区): 2 区域模块 + 2 拖拽线-竖

struct LowerBandZone: View {
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        let chatMgmt = totalW * LayoutTokens.chatManagementRatio
        let dynamicW = totalW * LayoutTokens.dynamicWRatio
        HStack(spacing: 0) {
            ZoneModule(slot: .chatManagement, totalW: totalW, bandH: bandH)
                .frame(width: chatMgmt, height: bandH)
            VerticalDragSplitter(height: bandH)
            ZoneModule(slot: .dynamicZone, totalW: totalW, bandH: bandH)
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
    let totalW: CGFloat  // 父 band 宽, 算比例
    let bandH: CGFloat
    @Environment(WenshuLibrary.self) private var library

    private var toolbarH: CGFloat { bandH * LayoutTokens.toolbarRatio }
    private var editorInset: CGFloat { totalW * LayoutTokens.editorInsetRatio + bandH * LayoutTokens.editorInsetRatio }  // 4 PT 算水平+垂直近似
    private var chatSidebar: CGFloat { totalW * LayoutTokens.chatSidebarRatio }
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
            HStack(spacing: 0) {
                DesignColor.zoneSurface
                    .frame(width: chatSidebar)
                    .overlay(alignment: .topLeading) { zoneLabel("聊天侧栏") }
                VerticalDragSplitter(height: innerBandH)
                DesignColor.zoneSurface
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        DesignColor.accentBlue
                            .frame(width: chatInputW, height: chatInputH)
                            .padding(.bottom, bandH * 0.016)  // 16/984 比例
                    }
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
