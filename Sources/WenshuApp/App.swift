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

// MARK: - Layout tokens (PT 真值集中处, 全项目 0 硬编码)

enum LayoutTokens {
    static let totalW: CGFloat = 1920
    static let totalH: CGFloat = 984
    static let titleH: CGFloat = 39
    static let bandH: CGFloat = 472
    static let toolbarH: CGFloat = 30
    static let splitterHit: CGFloat = 6  // 6 PT hit area 居中 1 PT 视觉线

    // 上 band zone 真值
    static let projectSidebar: CGFloat = 200
    static let projectPreview: CGFloat = 557
    static let editorW: CGFloat = 757
    static let toolsW: CGFloat = 403

    // 下 band zone 真值
    static let chatManagement: CGFloat = 1516  // 内部嵌套侧栏 200 + 拖拽线 6 + 对话 1310
    static let chatSidebar: CGFloat = 200
    static let chatDialogue: CGFloat = 1310  // 1316 - 6 = 1310
    static let dynamicW: CGFloat = 403

    // 编辑器两层设计 (老板 8/18 Q2 答: 有意两层, 不要删)
    static let editorInset: CGFloat = 4
    // 聊天输入框 (boss Sketch #4a60b2 蓝, 2590×94)
    static let chatInputW: CGFloat = 1296  // 1310 - 14 PT 边距
    static let chatInputH: CGFloat = 94
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
        window.setContentSize(NSSize(
            width: LayoutTokens.totalW,
            height: LayoutTokens.totalH
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
        VStack(spacing: 0) {
            TitleBarZone()
                .frame(width: LayoutTokens.totalW, height: LayoutTokens.titleH)
            UpperBandZone()
                .frame(width: LayoutTokens.totalW, height: LayoutTokens.bandH)
            HorizontalDragSplitter(width: LayoutTokens.totalW)
            LowerBandZone()
                .frame(width: LayoutTokens.totalW, height: LayoutTokens.bandH)
        }
        .frame(width: LayoutTokens.totalW, height: LayoutTokens.totalH)
    }
}

// MARK: - 上 band (小说管理区): 3 区域模块 + 3 拖拽线-竖

struct UpperBandZone: View {
    var body: some View {
        HStack(spacing: 0) {
            ZoneModule(slot: .projectSidebar)
                .frame(width: LayoutTokens.projectSidebar, height: LayoutTokens.bandH)
            VerticalDragSplitter(height: LayoutTokens.bandH)
            ZoneModule(slot: .projectPreview)
                .frame(width: LayoutTokens.projectPreview, height: LayoutTokens.bandH)
            VerticalDragSplitter(height: LayoutTokens.bandH)
            ZoneModule(slot: .editor)
                .frame(width: LayoutTokens.editorW, height: LayoutTokens.bandH)
            VerticalDragSplitter(height: LayoutTokens.bandH)
            ZoneModule(slot: .specializedTools)
                .frame(width: LayoutTokens.toolsW, height: LayoutTokens.bandH)
        }
    }
}

// MARK: - 下 band (聊天管理区): 2 区域模块 + 2 拖拽线-竖

struct LowerBandZone: View {
    var body: some View {
        HStack(spacing: 0) {
            ZoneModule(slot: .chatManagement)
                .frame(width: LayoutTokens.chatManagement, height: LayoutTokens.bandH)
            VerticalDragSplitter(height: LayoutTokens.bandH)
            ZoneModule(slot: .dynamicZone)
                .frame(width: LayoutTokens.dynamicW, height: LayoutTokens.bandH)
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

/// Master 2: 区域顶部工具栏 (30 PT 高, 复用; iconSlots=3 时画 3 个 38×38 蓝 ICON 占位)
struct ZoneTopToolbar: View {
    let iconSlots: Int
    var body: some View {
        DesignColor.zoneSurface
            .overlay(alignment: .leading) {
                if iconSlots > 0 {
                    HStack(spacing: 60) {  // 老板 8/18: 60 PT 等距, 起点 22 PT
                        ForEach(0..<iconSlots, id: \.self) { i in
                            DesignColor.accentBlue
                                .frame(width: 38, height: 38)
                        }
                    }
                    .padding(.leading, 22)  // boss Sketch 矩形起 x=22
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
    @Environment(WenshuLibrary.self) private var library

    var body: some View {
        VStack(spacing: 0) {
            ZoneTopToolbar(iconSlots: slot == .projectPreview ? 3 : 0)
                .frame(height: LayoutTokens.toolbarH)
            content
                .frame(maxHeight: .infinity)
            ZoneBottomToolbar()
                .frame(height: LayoutTokens.toolbarH)
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
            // 外层 #202020 + 内层 #ffffff 55% alpha 4 PT inset
            DesignColor.zoneSurface
                .overlay {
                    Color.white.opacity(0.55)
                        .padding(LayoutTokens.editorInset)
                }
        case .specializedTools:
            DesignColor.zoneSurface.overlay(alignment: .topLeading) {
                zoneLabel("专用工具")
            }
        case .chatManagement:
            // 内部嵌套: 侧栏 200 + 拖拽线 6 + 对话 1310 (= 1516)
            HStack(spacing: 0) {
                DesignColor.zoneSurface
                    .frame(width: LayoutTokens.chatSidebar)
                    .overlay(alignment: .topLeading) { zoneLabel("聊天侧栏") }
                VerticalDragSplitter(height: LayoutTokens.bandH - 2 * LayoutTokens.toolbarH)
                DesignColor.zoneSurface
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        // 聊天输入框 #4a60b2 蓝
                        DesignColor.accentBlue
                            .frame(width: LayoutTokens.chatInputW, height: LayoutTokens.chatInputH)
                            .padding(.bottom, 16)
                    }
            }
        case .dynamicZone:
            // 动态区底色已在 .background 处
            Color.clear.overlay(alignment: .topLeading) {
                zoneLabel("动态区")
            }
        }
    }

    private func zoneLabel(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(12)
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
