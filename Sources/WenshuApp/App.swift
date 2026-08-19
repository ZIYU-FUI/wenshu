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
        .defaultSize(width: LayoutTokens.designW, height: LayoutTokens.designH)  // 老板 Sketch 设计基准 1920×984 PT (v0.15 ticket 005 响应式: LayoutShellView 删 fixed frame, window 用 defaultSize 给 SwiftUI 初始 size hint)
        .windowResizability(.contentSize)  // 内容驱动窗口大小 (GeometryReader × 比例算子自适应 resize)
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
            let contentH = proxy.size.height  // NSWindow.contentRect = 984 (实测, 不含 macOS chrome)
            // v0.15 ticket 021 修: 老板 2026-08-19 拍 "除非要求硬编码的地方, 不要用 PT 写界面框架, 用比例写"
            //   死原则: 52 (macOS chrome 不动) + 932 (contentH - 52) = 984
            //   932 = 上半 + 拖拽线 + 下半, 上半 = 下半 = (932 - 2) / 2 = 465 PT
            //   D_h 拖拽线 = 2 PT (Sketch master 真值, 老板 2026-08-19 用 mcp__sketch__run_code 读图确认)
            //   bandH 用比例算子 vm.upperBandH(totalHeight: contentH - 52) (ticket 014 D_h 响应 + 比例算子)
            let bandH = vm.upperBandH(totalHeight: contentH - 52)
            VStack(spacing: 0) {
                // 上 band: 4 区 + 3 拖拽线 (Apple HIG HStack 范式)
                UpperBandZone(vm: vm, totalW: totalW, bandH: bandH)
                // D_h 横拖拽线 (上/下 band 之间, v0.14.0 撤销 inert, 拍可拖)
                NativeSplitter(orientation: .horizontal, length: totalW, onDrag: { dy in
                    vm.adjustBandSplit(delta: dy, totalHeight: contentH - 52)
                })
                // 下 band: 2 区 + 1 拖拽线 (老板 8/18 拍 "上四下两")
                LowerBandZone(vm: vm, totalW: totalW, bandH: vm.lowerBandH(totalHeight: contentH - 52))
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

/// 区域顶部工具栏 (boss Sketch 真值: 30 PT 高, 3 SF Symbol 占位 + 占位文字 + 底 2 PT #000000 分割线)
/// v0.15 ticket 013 修: 老板 2026-08-19 Sketch master "区域顶部工具栏" 真值 (mcp__sketch__run_code):
///   - 顶栏背景 (0, 0, w, 30)
///   - 矩形 18×18 at (18, 6) — 起点 x=18 y=6 (顶对齐)
///   - 矩形 18×18 at (45, 6) — 间距 27 PT (45 - 18 = 27)
///   - 矩形 18×18 at (72, 6) — 等距 27 PT
///   - 占位文本 (x_right_align, 8, 52, 16) — 右对齐, 顶 8
///   - 分割线 (0, 28, w, 2) — 底部 2 PT (v0.15 ticket 020 老板 2026-08-19 用 mcp__sketch__run_code 读图确认 2 PT)
struct ZoneTopToolbar: View {
    let iconNames: [String]
    let totalW: CGFloat

    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight  // 30 PT 硬编码 (v0.15 ticket 008)
        // 老板 2026-08-19 Sketch master "区域顶部工具栏" = 290 PT 宽 (master default, SymbolInstance .resizeToFitContents 撑)
        // 顶栏图标起点 y=6 (顶对齐), 间距 9 PT (v0.15 ticket 015 修: 老板 2026-08-19 拍 "调整成 9", 撤回 ticket 013 改的 27)
        DesignColor.zoneSurface
            .frame(height: toolbarH)
            .overlay(alignment: .topLeading) {
                // 3 SF Symbol icon 起点 y=6 (顶对齐), 间距 9 PT (Sketch 真值)
                HStack(spacing: 9) {
                    ForEach(0..<iconNames.count, id: \.self) { i in
                        ZoneIcon(systemName: iconNames[i], size: 18)
                    }
                }
                .padding(.leading, 18)  // 起点 x=18 (master 真值)
                .padding(.top, 6)       // 起点 y=6 (master 真值)
            }
            .overlay(alignment: .topTrailing) {
                // 占位文本 (Sketch master: x=220, y=8, w=52, h=16, fontSize 13)
                Text("占位文字")
                    .font(.system(size: 13))  // Apple HIG 13 PT body
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 18)  // 右 padding 18 PT (master: 占位文本右边距 toolbar 右 18)
                    .padding(.top, 8)       // 顶 8 PT (master 真值)
                    .frame(height: toolbarH, alignment: .topTrailing)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                DesignColor.splitterLine.frame(height: 2)  // 2 PT #000000 底分割线 (v0.15 ticket 020 老板 2026-08-19 用 mcp__sketch__run_code 读图确认 2 PT)
            }
    }
}

/// 区域底部工具栏 (boss Sketch master 真值: 30 PT 高, 2 占位文字 + 顶 2 PT 分割线)
/// v0.15 ticket 013 修: 老板 2026-08-19 Sketch master "区域底部工具栏" 真值 (mcp__sketch__run_code):
///   - 背景 (0, 0, w, 30)
///   - 分割线 (0, 0, w, 2) — 顶 2 PT (v0.15 ticket 020 老板 2026-08-19 用 mcp__sketch__run_code 读图确认 2 PT)
///   - 占位文本 (18, 8, 52, 16) — 左 padding 18, 顶 8
///   - 占位文本备份 (130, 8, 52, 16) — 右 padding 18 (= w - 130 - 52 = 18), 顶 8
///   (撤回 v0.10.6 右 SF Symbol icon, 改 2 占位文本)
/// v0.15 ticket 016 撤回 ticket 013 占位文字位置改动: 老板 2026-08-19 ticket 011 拍板 "左顶边 18, 右顶边 18, 距底边 6"
///   (ticket 013 重写时自作主张改 .topLeading + 距顶 8 违反 Q20 hard rule "已实现不要直接动")
///   撤回: .topLeading → .bottomLeading + 距底 6 PT (跟 ticket 011 一致)
struct ZoneBottomToolbar: View {
    let width: CGFloat

    var body: some View {
        let toolbarH = LayoutTokens.toolbarHeight  // 30 PT 硬编码 (v0.15 ticket 008)
        DesignColor.zoneSurface
            .frame(width: width, height: toolbarH)
            .overlay(alignment: .top) {
                DesignColor.splitterLine.frame(height: 2)  // 2 PT #000000 顶分割线 (v0.15 ticket 020 老板 2026-08-19 用 mcp__sketch__run_code 读图确认 2 PT)
            }
            .overlay(alignment: .bottomLeading) {
                // 左占位文字 (Sketch master: x=18, y=8, w=52, h=16, fontSize 13)
                // v0.15 ticket 016: 距底边 6 PT (ticket 011 拍板, 撤回 ticket 013 改的距顶 8)
                Text("占位文字")
                    .font(.system(size: 13))  // Apple HIG 13 PT body
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 18)
                    .padding(.bottom, 6)
                    .frame(height: toolbarH, alignment: .bottomLeading)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                // 右占位文本 (Sketch master "占位文本备份": x=130, y=8, w=52, h=16)
                // v0.15 ticket 016: 距底边 6 PT
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
        // v0.15 ticket 018 重写 ZoneModule.body 约束:
        //   老板 2026-08-19 拍: 区域组件不写死高度, 内容自适应
        //   顶栏: 向上约束 (居顶) + 宽度自适应 (maxWidth: .infinity)
        //   底栏: 向下约束 (居底) + 宽度自适应 (maxWidth: .infinity)
        //   内容区: 四方约束填充 (maxWidth: .infinity + maxHeight: .infinity)
        // 老板 2026-08-19 拍: 顶栏/底栏硬编码 30 PT (ticket 008), ICON 18×18 (ticket 013), 间距 9 (ticket 015), 占位文字左/右 18 (ticket 013), 距底 6 (ticket 011)
        VStack(spacing: 0) {
            // 顶栏: 居顶, 宽度自适应
            ZoneTopToolbar(iconNames: ["book.closed", "magnifyingglass", "slider.horizontal.3"], totalW: totalW)
                .frame(width: totalW, height: toolbarH, alignment: .top)  // 顶栏 30 PT 硬编码, 居顶
            // 内容区: 四方约束填充, 撑满剩余空间
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 底栏: 居底, 宽度自适应
            ZoneBottomToolbar(width: totalW)
                .frame(width: totalW, height: toolbarH, alignment: .bottom)  // 底栏 30 PT 硬编码, 居底
        }
        // v0.15 ticket 006 P3-4 撤回: surfaceColor background 跟 .editor overlay 套娃导致两道双层 bug
        // 回退到 v0.15 ticket 005 范式: 每个 case 自己画 Color + overlay
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
