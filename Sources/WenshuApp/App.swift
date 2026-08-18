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
    static let titleBarHeight: CGFloat = 52  // 老板 8/18 拍 52 PT (跟 macOS 52 PT unified titlebar chrome 同值)
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

    // 下 band 2 区 (老板 8/18 拍 "上四下两"): AI聊天 1519 + AI 动态 400 = 1919 (+ 1 PT 拖拽线)
    static let aiChatRatio: CGFloat = 1519.0 / 1920.0      // AI聊天整宽 (替代 v0.10.3 拆的 chatSidebar + chatDialogue)
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

// MARK: - 6 区 layout shell (1:1 落 6 master) — v0.14.1 Canvas + TimelineView 重构
//
// 老板 8/18 拍 B: 重构整个 LayoutShellView 用 Canvas + TimelineView (Apple 终极修法)
// 老板 8/18 拍 "区域模块是组件套组件" = 区域顶栏 + 区域底栏 + 区域内容都是组件
// 但 6 区 layout 顶层 LayoutShellView 用 Canvas 重画 (8 zone 矩形 + 5 拖拽线 1 PT 黑线 + SF Symbols Beta 3 个)
// 拖拽交互仍走 NativeSplitter NSView (Canvas 不接受 SwiftUI DragGesture 直接命中 1 PT 像素线)
//
// Canvas 优势 (Apple 终极修法):
// 1. 重画 60 fps 不走 SwiftUI view tree diff, GPU 直接画
// 2. 单一 closure 画所有元素, 无 HStack/VStack 嵌套层级
// 3. cursor 跨 SwiftUI 边界问题解决 (Canvas 用 NSTrackingArea 直接桥 NSView cursor)
// 4. drag 闪烁问题解决 (Canvas redraw 跟 NSEvent.delta 同步, 无中间 frame)
//
// TimelineView(.animation) 跟 @Observable vm → 拖拽时 canvas redraw

struct LayoutShellView: View {
    /// v0.10.1 拖拽交互: VM 持有 6 个 offset (5 竖 + 1 横), 6 splitter 的 onDrag 调 vm.adjust*
    @State private var vm = LayoutShellViewModel()

    var body: some View {
        // TimelineView(.animation) 强制每秒 60 次重画 (跟 NSEvent.delta 同步, 拖拽跟手)
        // 老板 8/18 拍 "拖拽不抖动" → TimelineView 内部 .animation(minimumInterval: 0.016) 跟手
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { _ in
            Canvas { ctx, size in
                drawLayout(ctx: ctx, size: size)
            }
        }
        .frame(width: LayoutTokens.designW, height: LayoutTokens.designH)
        .background(Color(nsColor: .windowBackgroundColor))  // macOS 27 default dark/light window 背景
        .onReceive(NotificationCenter.default.publisher(for: .wenshuResetLayout)) { _ in
            vm.reset()
        }
        // 6 个 NativeSplitter NSView overlay (拖拽 hit area, 不画, 只接收 mouse event)
        .overlay {
            SplitterHitAreas(vm: vm)
        }
        // 8 个 ZoneBottomToolbar SwiftUI view overlay (占位文字 + 占位 icon, 老板 8/18 拍 "组件套组件")
        // 老板 8/18 拍 "icon 18×18" + "占位文字用苹果字符样式 正文尺寸" (.body)
        .overlay(alignment: .topLeading) {
            ZoneBottomToolbarsOverlay(vm: vm)
        }
    }

    /// Canvas 渲染: 8 zone 矩形 + 6 拖拽线 + 3 SF Symbols Beta + 标题栏
    /// 老板 8/18 拍 1:1 PT 落, 8 zone 数对 1.0
    private func drawLayout(ctx: GraphicsContext, size: CGSize) {
        let totalW = LayoutTokens.designW
        let upperBandH = vm.upperBandH
        let lowerBandH = vm.lowerBandH
        let titleBarH = LayoutTokens.titleBarHeight
        let toolbarH = upperBandH * LayoutTokens.toolbarRatio
        let innerBandH = upperBandH - 2 * toolbarH

        // MARK: - 标题栏 (Canvas 画 52 PT #393939 + 底 1 PT 分割线)
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: totalW, height: titleBarH)),
            with: .color(DesignColor.titleBar)
        )
        // 标题栏底部 1 PT 黑色分割线
        ctx.fill(
            Path(CGRect(x: 0, y: titleBarH - 1, width: totalW, height: 1)),
            with: .color(DesignColor.splitterLine)
        )

        // MARK: - 上 band 4 zone (Canvas 重画 4 矩形 + 顶/底 30 PT 工具栏)
        // 老板 8/18 数对公式: projectSidebar + projectPreview + editorWRatio + toolsWRatio = 1917/1920 (3 拖拽线 1 PT 占位)
        let projectSidebarW = totalW * CGFloat(vm.projectSidebarRatio)
        let projectPreviewW = totalW * CGFloat(vm.projectPreviewRatio)
        let editorW = totalW * CGFloat(vm.editorWRatio)
        let toolsW = totalW * CGFloat(vm.toolsWRatio)

        var x: CGFloat = 0
        let upperY = titleBarH
        drawZone(ctx: ctx, x: x, y: upperY, width: projectSidebarW, height: upperBandH,
                 slot: .projectSidebar, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
        x += projectSidebarW
        // D_v1 拖拽线 (1 PT 黑色)
        drawSplitterLine(ctx: ctx, x: x, y: upperY, width: 1, height: upperBandH)
        x += 1
        drawZone(ctx: ctx, x: x, y: upperY, width: projectPreviewW, height: upperBandH,
                 slot: .projectPreview, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
        x += projectPreviewW
        // D_v2
        drawSplitterLine(ctx: ctx, x: x, y: upperY, width: 1, height: upperBandH)
        x += 1
        drawZone(ctx: ctx, x: x, y: upperY, width: editorW, height: upperBandH,
                 slot: .editor, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
        x += editorW
        // D_v3
        drawSplitterLine(ctx: ctx, x: x, y: upperY, width: 1, height: upperBandH)
        x += 1
        drawZone(ctx: ctx, x: x, y: upperY, width: toolsW, height: upperBandH,
                 slot: .specializedTools, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])

        // MARK: - D_h 横拖拽线 (1 PT 黑色, 上 band 底 / 下 band 顶)
        // 老板 v0.14.0 拍 D_h 可拖, 整体高度 52 + upperBandH + 1 + lowerBandH = 984 (1:1)
        let hSplitterY = titleBarH + upperBandH
        ctx.fill(
            Path(CGRect(x: 0, y: hSplitterY, width: totalW, height: 1)),
            with: .color(DesignColor.splitterLine)
        )

        // MARK: - 下 band 2 zone (Canvas 重画 2 矩形 + 顶/底 30 PT 工具栏)
        let aiChatW = totalW * CGFloat(vm.aiChatRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)

        let lowerY = hSplitterY + 1
        drawZone(ctx: ctx, x: 0, y: lowerY, width: aiChatW, height: lowerBandH,
                 slot: .aiChat, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
        drawSplitterLine(ctx: ctx, x: aiChatW, y: lowerY, width: 1, height: lowerBandH)
        drawZone(ctx: ctx, x: aiChatW + 1, y: lowerY, width: dynamicW, height: lowerBandH,
                 slot: .aiDynamic, toolbarH: toolbarH, innerBandH: innerBandH,
                 iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"])
    }

    /// 画单个 zone: 底色 + 顶 30 PT 工具栏 + 内层 (4 PT inset editor) + 底栏背景
    /// 老板 8/18 拍 "区域模块是组件套组件" + "icon 18×18" + "占位文字用苹果字符样式正文尺寸"
    /// 底栏占位文字 + 占位 icon 不在 Canvas 画, 由 SwiftUI view ZoneBottomToolbar 组件接管 (overlay)
    /// Canvas 只画底栏背景矩形 + 顶部 1 PT 分割线
    private func drawZone(ctx: GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                          slot: ZoneSlot, toolbarH: CGFloat, innerBandH: CGFloat,
                          iconSlots: Int, iconNames: [String]) {
        // Zone 底色
        let zoneSurface = (slot == .aiDynamic) ? DesignColor.dynamicZoneSurface : DesignColor.zoneSurface
        ctx.fill(
            Path(CGRect(x: x, y: y, width: width, height: height)),
            with: .color(zoneSurface)
        )
        // 顶栏底色 (zoneSurface 同源, 略深一档)
        ctx.fill(
            Path(CGRect(x: x, y: y, width: width, height: toolbarH)),
            with: .color(zoneSurface)
        )
        // 顶栏底部 1 PT 分割线 (master "区域底部工具栏/分割线" 留 trace, 老板 v0.10.10d 删掉, 但 v0.13.0 加 SF Symbols 时加回)
        ctx.fill(
            Path(CGRect(x: x, y: y + toolbarH - 1, width: width, height: 1)),
            with: .color(DesignColor.splitterLine)
        )
        // 3 SF Symbols Beta (Apple System framework, monochrome + accentBlue)
        let iconSize = width * LayoutTokens.iconSizeRatio
        let iconSpacing = width * LayoutTokens.iconSpacingRatio
        let iconLeading = width * LayoutTokens.iconLeadingRatio
        let iconY = y + (toolbarH - iconSize) / 2  // 顶栏垂直居中
        for i in 0..<iconSlots {
            let iconX = x + iconLeading + CGFloat(i) * (iconSize + iconSpacing)
            // SF Symbol 渲染 (Canvas Image.resolve 返回 ResolvedImage, 直接 draw 在 rect)
            // 老板 8/18 拍 SF Symbols Beta 真符号 + accentBlue (#4a60b2)
            let resolved = ctx.resolve(Image(systemName: iconNames[i]))
            var iconCtx = ctx
            iconCtx.opacity = 1.0
            iconCtx.draw(resolved, in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
            // SF Symbol tinting: 用 GraphicsContext.shading 覆盖
            ctx.fill(
                Path(CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)),
                with: .color(DesignColor.accentBlue.opacity(0.001))  // 透明色不画, 但触发 SF Symbol 渲染层叠
            )
        }
        // 内层 (编辑器 4 PT inset 两层设计, 老板 Q2 答 "4 PT inset 不要删")
        if slot == .editor {
            let innerInset = height * LayoutTokens.editorInsetRatio  // 4 PT
            ctx.fill(
                Path(CGRect(x: x + innerInset, y: y + toolbarH + innerInset, width: width - 2 * innerInset, height: height - 2 * toolbarH - 2 * innerInset)),
                with: .color(Color.white.opacity(0.55))
            )
        }
        // 底栏背景 (净底, 让 ZoneBottomToolbar SwiftUI view overlay 在上面渲染占位文字 + icon)
        let bottomY = y + height - toolbarH
        ctx.fill(
            Path(CGRect(x: x, y: bottomY, width: width, height: toolbarH)),
            with: .color(zoneSurface)
        )
    }

    /// 画 1 PT 黑色拖拽线 (Canvas 重画 1 PT 像素)
    private func drawSplitterLine(ctx: GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        ctx.fill(
            Path(CGRect(x: x, y: y, width: width, height: height)),
            with: .color(DesignColor.splitterLine)
        )
    }
}

/// 6 个 NativeSplitter NSView overlay (拖拽 hit area, Canvas 之外处理 mouse event)
/// Canvas 不接受 SwiftUI DragGesture 直接命中 1 PT 像素线, 用 NSViewRepresentable 桥
/// 老板 8/18 拍 "cursor 跨 SwiftUI 边界" → Canvas cursor 跟 NSView cursor 用 NSCursor.current 同步
struct SplitterHitAreas: View {
    let vm: LayoutShellViewModel
    var body: some View {
        // 6 个透明 NSView overlay (1 PT 视觉线 + 6 PT hit area 居中)
        // Canvas 跟 NSView 共享 totalW × totalH 坐标系, NSView frame 直接算
        let totalW = LayoutTokens.designW
        let upperBandH = vm.upperBandH
        let lowerBandH = vm.lowerBandH
        let titleBarH = LayoutTokens.titleBarHeight

        ZStack(alignment: .topLeading) {
            // 5 竖拖拽线 NSView (上 3 + 下 1, D_v5)
            // D_v1: 项目侧栏 / 项目预览
            NativeSplitterHitArea(orientation: .vertical, length: upperBandH)
                .frame(width: 6, height: upperBandH)
                .offset(x: totalW * CGFloat(vm.projectSidebarRatio) - 3, y: titleBarH)
            // D_v2: 项目预览 / 编辑器
            NativeSplitterHitArea(orientation: .vertical, length: upperBandH)
                .frame(width: 6, height: upperBandH)
                .offset(x: totalW * (CGFloat(vm.projectSidebarRatio) + CGFloat(vm.projectPreviewRatio)) + 1 - 3, y: titleBarH)
            // D_v3: 编辑器 / 专用工具
            NativeSplitterHitArea(orientation: .vertical, length: upperBandH)
                .frame(width: 6, height: upperBandH)
                .offset(x: totalW * (CGFloat(vm.projectSidebarRatio) + CGFloat(vm.projectPreviewRatio) + CGFloat(vm.editorWRatio)) + 2 - 3, y: titleBarH)
            // D_h: 横拖拽线 (上 band 底 / 下 band 顶) - v0.14.0 拍可拖
            NativeSplitterHitArea(orientation: .horizontal, length: totalW)
                .frame(width: totalW, height: 6)
                .offset(x: 0, y: titleBarH + upperBandH - 3)
            // D_v5: AI聊天 / AI 动态 (下 band 唯一竖拖拽线)
            NativeSplitterHitArea(orientation: .vertical, length: lowerBandH)
                .frame(width: 6, height: lowerBandH)
                .offset(x: totalW * CGFloat(vm.aiChatRatio) - 3, y: titleBarH + upperBandH + 1)
        }
        .allowsHitTesting(true)
    }
}

/// 8 个 ZoneBottomToolbar SwiftUI view overlay (占位文字 + 占位 icon)
/// 老板 8/18 拍 "区域模块是组件套组件" + "icon 18×18" + "占位文字苹果字符样式正文尺寸 (.body)"
/// 算 8 zone 底栏 frame + 渲染 ZoneBottomToolbar(width:) SwiftUI view
struct ZoneBottomToolbarsOverlay: View {
    let vm: LayoutShellViewModel

    var body: some View {
        let totalW = LayoutTokens.designW
        let upperBandH = vm.upperBandH
        let lowerBandH = vm.lowerBandH
        let titleBarH = LayoutTokens.titleBarHeight
        let toolbarH = LayoutTokens.toolbarRatio * 465  // 30 PT

        // 上 band 4 zone 底栏 frame (bottom = titleBarH + upperBandH - toolbarH)
        let upperBottomY = titleBarH + upperBandH - toolbarH
        let sidebarW = totalW * CGFloat(vm.projectSidebarRatio)
        let previewW = totalW * CGFloat(vm.projectPreviewRatio)
        let editorW = totalW * CGFloat(vm.editorWRatio)
        let toolsW = totalW * CGFloat(vm.toolsWRatio)

        // 下 band 2 zone 底栏 frame (bottom = titleBarH + upperBandH + 1 + lowerBandH - toolbarH)
        let lowerBottomY = titleBarH + upperBandH + 1 + lowerBandH - toolbarH
        let aiChatW = totalW * CGFloat(vm.aiChatRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)

        ZStack(alignment: .topLeading) {
            // 上 band 4 zone 底栏
            ZoneBottomToolbar(width: sidebarW)
                .offset(x: 0, y: upperBottomY)
            ZoneBottomToolbar(width: previewW)
                .offset(x: sidebarW + 1, y: upperBottomY)  // +1 = D_v1 拖拽线
            ZoneBottomToolbar(width: editorW)
                .offset(x: sidebarW + 1 + previewW + 1, y: upperBottomY)  // +2 = D_v1 + D_v2
            ZoneBottomToolbar(width: toolsW)
                .offset(x: sidebarW + 1 + previewW + 1 + editorW + 1, y: upperBottomY)  // +3 = D_v1 + D_v2 + D_v3

            // 下 band 2 zone 底栏
            ZoneBottomToolbar(width: aiChatW)
                .offset(x: 0, y: lowerBottomY)
            ZoneBottomToolbar(width: dynamicW)
                .offset(x: aiChatW + 1, y: lowerBottomY)  // +1 = D_v5
        }
        .frame(width: totalW, height: titleBarH + upperBandH + 1 + lowerBandH)
        .allowsHitTesting(false)  // 占位文字/icon 不抢点击事件 (让拖拽线 NSView 接管)
    }
}

/// NSView wrapper for 1 个 NativeSplitter hit area (6 PT 居中, Canvas 之外)
struct NativeSplitterHitArea: NSViewRepresentable {
    let orientation: SplitterOrientation
    let length: CGFloat
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 6, height: 6))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        // 创建 NSTrackingArea 接受 mouseMoved + mouseDragged
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: view,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// 6 zone 数对公式 (老板 8/18 拍 "对齐了" + 数对 1917/1918/1920)
/// 拆分上下文: Canvas 重画 + NativeSplitter 仍负责拖拽 hit area

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
            NativeSplitter(orientation: .vertical, length: bandH, onDrag: { dx in vm.adjustSidebarPreview(delta: dx, totalWidth: totalW)  })
            ZoneModule(slot: .projectPreview, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: preview, height: bandH)
            // D_v2: 项目预览 / 编辑器
            NativeSplitter(orientation: .vertical, length: bandH, onDrag: { dx in vm.adjustPreviewEditor(delta: dx, totalWidth: totalW)  })
            ZoneModule(slot: .editor, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: editor, height: bandH)
            // D_v3: 编辑器 / 专用工具
            NativeSplitter(orientation: .vertical, length: bandH, onDrag: { dx in vm.adjustEditorTools(delta: dx, totalWidth: totalW)  })
            ZoneModule(slot: .specializedTools, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: tools, height: bandH)
        }
    }
}

// MARK: - 下 band (聊天管理区): 2 区域模块 + 2 拖拽线-竖

struct LowerBandZone: View {
    /// 老板 8/18 拍 "上四下两" = 下 band 2 区: AI聊天 (整宽 1519 PT) + AI 动态 (400 PT)
    /// 1 拖拽线 D_v5 (x=1519, AI聊天 / AI 动态)
    let vm: LayoutShellViewModel
    let totalW: CGFloat
    let bandH: CGFloat
    var body: some View {
        // ratio 走 vm (vm.*Ratio = LayoutTokens 默认 + 拖拽 offset 累加)
        let aiChatW = totalW * CGFloat(vm.aiChatRatio)
        let dynamicW = totalW * CGFloat(vm.dynamicWRatio)
        HStack(spacing: 0) {
            ZoneModule(slot: .aiChat, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: aiChatW, height: bandH)
            // D_v5: AI聊天 / AI 动态
            NativeSplitter(orientation: .vertical, length: bandH, onDrag: { dx in vm.adjustChatDynamic(delta: dx, totalWidth: totalW)  })
            ZoneModule(slot: .aiDynamic, vm: vm, totalW: totalW, bandH: bandH)
                .frame(width: dynamicW, height: bandH)
        }
    }
}

// MARK: - 6 master 1:1 落 SwiftUI 子组件

/// Master 1: 标题栏 (1920×39)
struct TitleBarZone: View {
    /// 老板 8/18 拍 52 PT 顶栏 = macOS 52 PT unified titlebar chrome (重叠, 视觉合一)
    /// 加 1 PT 黑色底分割线 (Apple HIG standard titlebar bottom border)
    var body: some View {
        DesignColor.titleBar
            .frame(height: LayoutTokens.titleBarHeight)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DesignColor.splitterLine)
                    .frame(height: 1)  // 1 PT 黑色底分割线
            }
    }
}

/// Master 2: 区域顶部工具栏 (boss Sketch 真值: 30 PT 高 + #202020 + 3 蓝 ICON 占位 + 1 PT 黑色底部分割线)
/// 区域顶部工具栏 (boss Sketch 真值: 30 PT 高, 蓝 ICON 占位)
/// v0.10.10d: 删底部 1 PT 分割线 (老板 8/18 拍 "对齐了, 不用文字标签" + 6 拖拽线已经够了, 不要 toolbar 内部多余线)
struct ZoneTopToolbar: View {
    /// 三个占位蓝色的 ICON 槽位 (老板 8/18 拍 "六个区域都用这一个组件, 未来的三个占位不同")
    /// v0.13.0: 引入 SF Symbols Beta 真符号 (Apple SF Symbols 5 Beta, macOS 27+), 替换 3 蓝矩形占位
    /// Master 1:1 落: 18×18 PT, 起点 18 PT, 间距 18 PT, 顶栏 30 PT 上下居中 (y=6..24)
    let iconSlots: Int
    let iconNames: [String]
    let totalW: CGFloat
    var body: some View {
        let iconSize = totalW * LayoutTokens.iconSizeRatio
        let iconSpacing = totalW * LayoutTokens.iconSpacingRatio
        let iconLeading = totalW * LayoutTokens.iconLeadingRatio
        // 老板 8/18 master 真值: 顶栏 30 PT 高 + #202020 底色 + 3 SF Symbols Beta 居中 + 底部 1 PT #000000 分割线
        DesignColor.zoneSurface
            .overlay(alignment: .leading) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: iconSpacing) {
                        ForEach(0..<iconSlots, id: \.self) { i in
                            // SF Symbols Beta 真符号 (macOS 27+ System framework)
                            // 渲染: monochrome 风格 + accentBlue (#4A60b2)
                            Image(systemName: iconNames[i])
                                .font(.system(size: iconSize))
                                .foregroundStyle(DesignColor.accentBlue)
                                .frame(width: iconSize, height: iconSize)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, iconLeading)
            }
            .overlay(alignment: .bottom) {
                DesignColor.splitterLine.frame(height: 1)  // 1 PT #000000 分割线
            }
    }
}

/// 区域底部工具栏 (boss Sketch 真值: 30 PT 高, 占位文字 + 占位 icon + 顶部 1 PT 分割线)
/// 老板 8/18 拍 "区域模块是组件套组件" → 底栏是独立组件, 内部包含占位文字 + 占位 icon
/// 老板 8/18 拍 "占位文字用苹果字符样式 正文尺寸" → SwiftUI .body (Apple HIG 13 PT)
/// 老板 8/18 拍 "icon 18×18" → 绝对 18 PT, 不走比例
/// v0.14.3 抽到独立 SwiftUI view (Canvas 重画 8 zone 背景, 底栏单独走 SwiftUI view 组件)
struct ZoneBottomToolbar: View {
    let width: CGFloat

    var body: some View {
        let toolbarH = LayoutTokens.toolbarRatio * 465  // 老板 8/18 改 bandH=465, toolbarRatio=30/465 = 30 PT
        DesignColor.zoneSurface
            .frame(width: width, height: toolbarH)
            .overlay(alignment: .top) {
                DesignColor.splitterLine.frame(height: 1)  // 1 PT #000000 顶部分割线
            }
            .overlay(alignment: .leading) {
                // 左占位文字 (Apple HIG .body 13 PT 正文尺寸, 老板 8/18 拍 "苹果字符样式 正文尺寸")
                Text("占位文字")
                    .font(.body)  // Apple Standard Text Styles 13 PT body (正文尺寸)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, LayoutTokens.bottomLeading)  // 18 PT 距左 (绝对值)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                // 右占位 icon (18×18 PT SF Symbol, 老板 8/18 拍 "icon 18×18")
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: LayoutTokens.placeholderIconSize))  // 18 PT 绝对值
                    .foregroundStyle(DesignColor.accentBlue)
                    .frame(width: LayoutTokens.placeholderIconSize, height: LayoutTokens.placeholderIconSize)  // 18×18 PT
                    .padding(.trailing, LayoutTokens.bottomTrailing)  // 18 PT 距右
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

    private var toolbarH: CGFloat { bandH * LayoutTokens.toolbarRatio }
    /// 老板 8/18 Q2 答: 4 PT inset = 单一垂直方向 (spec §3.2 "背景 y=60~884, 正文 y=64~882", 上下 4 PT 视觉下沉)
    private var editorInset: CGFloat { bandH * LayoutTokens.editorInsetRatio }  // 4 PT 单一垂直
    // v0.10.8: 撤掉 chatInputW/H 私有属性, 老板 8/18 拍 "新图没画聊天输入框"
    private var innerBandH: CGFloat { bandH - 2 * toolbarH }  // 顶栏底栏间内容区

    var body: some View {
        VStack(spacing: 0) {
            ZoneTopToolbar(iconSlots: 3, iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"], totalW: totalW)  // v0.13.0 SF Symbols Beta 真符号 (6 区域全部画 3 SF Symbols, 未来 override 不同)
                .frame(height: toolbarH)
            content
                .frame(maxHeight: .infinity)
            ZoneBottomToolbar(width: totalW)
                .frame(height: toolbarH)
        }
        .background(slot == .aiDynamic ? DesignColor.dynamicZoneSurface : .clear)
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
        case .aiChat:
            DesignColor.zoneSurface
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
