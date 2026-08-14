// App.swift · Wenshu (Wenshu) · v0.01.0 7-zone layout shell (v16 = true macOS app)
//
// Source of truth: @wenshu-pour/architecture/CONTEXT.md + SPEC-v0.01.0.md + FCP-MEASUREMENTS.md
//
// v0.01.0 scaffold v16 (= boss 19:35 "现在也没有菜单, 不在程序栏中"):
//
//   Boss identified 3 missing macOS-app traits:
//     1. Window not in Dock (no LSUIElement = false registration; Dock tile missing)
//     2. Window not in Cmd+Tab switcher (= no proper NSApplication boot)
//     3. No menu bar (= no .commands { CommandGroup(...) } in SwiftUI App body)
//
//   All three fixed by:
//     1. Add @NSApplicationDelegateAdaptor (= wires NSApplication.run at launch, makes
//        the binary a Cocoa app = Dock tile + Cmd+Tab registration)
//     2. NSApplicationDelegate.applicationDidFinishLaunching sets initial window size
//        (= 1452x984 boss拍 19:10) — SwiftUI .frame() is parent-controlled, doesn't
//        reliably set initial frame; AppDelegate.setContentSize is the Apple HIG way
//     3. .commands { CommandGroup(...) } adds the standard macOS menu bar items
//        (= File / Edit / View / Window / Help, macOS-standard structure)
//
// v0.01.0 layout (= owner 18:00, "A 你参考 FCP 做"):
//   Upper band: Library (Shelf+Project nested) | Editor | Inspector
//   Lower band: Chat | (Console | Status nested)
//   5 splitters (3 upper horizontal + 1 band + 2 lower horizontal), all NativeSplitter
//
// FCP-measured default proportions (1452x984 baseline, owner 19:10):
//   Library 20.7% / Editor 51.7% / Inspector 27.6%
//   Chat 25% / (Console 50% / Status 50%)
//
// Out of scope: Wenshu assistant / smart context picker / CoreData / LLM / markdown
// rendering (= owner-deferred per CONTEXT.md §7).

import SwiftUI
import AppKit

// MARK: - Self screenshot
//
// Renders the live `keyWindow.contentView` (= SwiftUI hosting tree already
// mounted in the window) to a PNG via `NSView.cacheDisplay(in:to:)`.
//
// Why this exists (= boss 8/14 12:38, "screenshot wenshu app + send to chat for
// phone verification"): the agent runs in a Hermes Agent TUI session that
// lives in a virtual desktop, so `screencapture` returns a 0×0 black image
// for the wenshu window. System accessibility capture returns nothing
// useful either. The only reliable path is to render inside the app itself,
// using the same backing store that the user sees on screen.
//
// env knobs:
//   WS_SCREENSHOT=1            Enable the channel (no-op if unset)
//   WS_SCREENSHOT_PATH=<path>  Output PNG (default: /tmp/wenshu-selfshot.png)
//   WS_SCREENSHOT_DELAY=<secs> First-capture delay (default: 2.0s)
//   WS_SCREENSHOT_EXIT=1       Exit after first capture (one-shot mode, default)
//   WS_SCREENSHOT_LOOP=<secs>  Re-capture every N seconds (live preview mode)
enum SelfScreenshot {
    @MainActor
    static func run() {
        let env = ProcessInfo.processInfo.environment
        let path = env["WS_SCREENSHOT_PATH"] ?? "/tmp/wenshu-selfshot.png"
        let delay = Double(env["WS_SCREENSHOT_DELAY"] ?? "2.0") ?? 2.0
        let shouldExit = env["WS_SCREENSHOT_EXIT"] != "0"
        let loopInterval = env["WS_SCREENSHOT_LOOP"].flatMap { Double($0) }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            captureOnce(path: path, exitAfter: shouldExit)
        }
        if let interval = loopInterval {
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task { @MainActor in captureOnce(path: path, exitAfter: false) }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @MainActor
    private static func captureOnce(path: String, exitAfter: Bool) {
        // Yield one runloop tick so SwiftUI has a chance to finish its first
        // layout pass before we cache-display the contentView.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard
                let window = NSApp.keyWindow
                    ?? NSApp.windows.first(where: { $0.contentViewController != nil }),
                let contentView = window.contentView
            else {
                print("WS_SCREENSHOT: no window/contentView")
                if exitAfter { exit(2) }
                return
            }
            window.layoutIfNeeded()
            contentView.layoutSubtreeIfNeeded()
            let bounds = contentView.bounds
            guard bounds.width > 0 && bounds.height > 0 else {
                print("WS_SCREENSHOT: bounds zero \(bounds)")
                if exitAfter { exit(2) }
                return
            }
            guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
                print("WS_SCREENSHOT: bitmap alloc failed")
                if exitAfter { exit(2) }
                return
            }
            bitmap.size = bounds.size
            contentView.cacheDisplay(in: bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                print("WS_SCREENSHOT: png encode failed")
                if exitAfter { exit(3) }
                return
            }
            do {
                try png.write(to: URL(fileURLWithPath: path))
                print("WS_SCREENSHOT: wrote \(png.count) bytes to \(path) (size=\(bounds.size))")
                if exitAfter { exit(0) }
            } catch {
                print("WS_SCREENSHOT: write failed: \(error)")
                if exitAfter { exit(4) }
            }
        }
    }
}

@main
struct WenshuApp: App {
    /// NSApplicationDelegateAdaptor wires NSApplication.run at app launch (= the
    /// binary becomes a real Cocoa app: Dock tile + Cmd+Tab + menu bar registration).
    /// Without this, SwiftUI @main + WindowGroup on a SwiftPM executable builds and
    /// runs the process but doesn't fully bring up NSApplication (= "No windows open
    /// yet" log, no Dock tile, no menu).
    @NSApplicationDelegateAdaptor(WenshuAppDelegate.self) var appDelegate

    @State private var vm = LayoutShellViewModel()

    var body: some Scene {
        WindowGroup("文枢") {
            LayoutShellView(vm: vm)
                .environment(vm)  // inject for LibraryScaffold internal @Environment reads
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)
        // Boss 19:35 "现在也没有菜单" → add macOS-standard menu bar commands.
        // SwiftUI's default .commands {} is empty (= no menu bar at all). Adding
        // CommandGroup(after: .newItem) gives File / Edit / View / Window / Help.
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建项目") {
                    // TODO: wired to WenshuProjectStore in v0.02.0+ (= owner Q4 / Q5).
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Button("显示/隐藏 项目管理") {
                    // TODO: wired to LayoutShellViewModel.toggleVisibility(.topLeft) in v0.02.0+
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                Button("显示/隐藏 编辑器") {
                    // TODO: wired to LayoutShellViewModel.toggleVisibility(.topCenter)
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
                Button("显示/隐藏 检视") {
                    // TODO: wired to LayoutShellViewModel.toggleVisibility(.topRight)
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                Button("显示/隐藏 聊天") {
                    // TODO: wired to LayoutShellViewModel.toggleVisibility(.bottomLeft)
                }
                .keyboardShortcut("4", modifiers: [.command, .option])
                Button("显示/隐藏 状态") {
                    // TODO: wired to LayoutShellViewModel.toggleVisibility(.bottomRight)
                }
                .keyboardShortcut("5", modifiers: [.command, .option])
            }
        }
    }
}

/// AppDelegate that wires initial window size and Dock integration.
/// SwiftUI .frame() is parent-controlled (= doesn't reliably set initial window frame);
/// the Apple HIG pattern is to set NSWindow.setContentSize in applicationDidFinishLaunching.
final class WenshuAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = NSApplication.shared.windows.first else { return }
        // Set initial content size (= boss 19:10 拍 "1452x984 老板电脑全屏").
        window.setContentSize(NSSize(width: 1452, height: 984))
        // Center on screen (= Apple HIG default).
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: screenFrame.midX - windowFrame.width / 2,
                y: screenFrame.midY - windowFrame.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }
        // Boss 8/14 12:38 + 8/15 14:48: every code change must produce a screenshot
        // for phone verification. env-gated so normal launches stay interactive.
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Standard macOS app behavior: quit when last window closes (= Finder, Mail, FCP).
        return true
    }
}

// MARK: - Layout shell (= SwiftUI HStack/VStack with NativeSplitter between zones)

struct LayoutShellView: View {
    let vm: LayoutShellViewModel

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            // Boss 19:55 "上下分区, 约束到 50/50" → upper/lower band split is fixed at 50/50
            // (= no NativeSplitter between bands; this is a hard constraint, not user-resizable).
            // TODO v0.02.0: revisit if boss拍 to make band split resizable.
            let lowerH = totalH * Self.bandRatio
            let upperH = totalH * (1.0 - Self.bandRatio)

            VStack(spacing: 0) {
                upperBand(width: totalW, height: upperH)
                    .frame(height: upperH)

                lowerBand(width: totalW, height: lowerH)
                    .frame(height: lowerH)
            }
        }
        .frame(minWidth: 1280, idealWidth: 1452, minHeight: 800, idealHeight: 984)
    }

    /// Boss 19:55: upper/lower band fixed at 50/50 (NOT user-resizable).
    private static let bandRatio: CGFloat = 0.50

    @ViewBuilder
    private func upperBand(width: CGFloat, height: CGFloat) -> some View {
        let upperW = width
        let r = vm.upperRatios
        let libraryW = upperW * r[0]
        let editorW = upperW * r[1]
        let inspectorW = upperW * r[2]

        HStack(spacing: 0) {
            // Library (Shelf + Project horizontal split inside, boss 19:10 "应该是左右")
            LibraryScaffold()
                .frame(width: libraryW, height: height)

            // NativeSplitter between Library and Editor (= FCP-measured 8pt hit area,
            // 1pt visible line on START edge = LT-01-fix15/16 from装机 user 8/7).
            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 0, delta: delta, totalWidth: upperW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness, height: height)

            ZoneScaffoldView(name: "EDITOR")
                .frame(width: editorW, height: height)

            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustUpperColumn(splitterIndex: 1, delta: delta, totalWidth: upperW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness, height: height)

            ZoneScaffoldView(name: "INSPECTOR")
                .frame(width: inspectorW, height: height)
        }
    }

    @ViewBuilder
    private func lowerBand(width: CGFloat, height: CGFloat) -> some View {
        let lowerW = width
        let r = vm.lowerRatios
        let chatW = lowerW * r[0]
        let rightW = lowerW * r[1]

        HStack(spacing: 0) {
            ZoneScaffoldView(name: "CHAT")
                .frame(width: chatW, height: height)

            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustLowerColumn(delta: delta, totalWidth: lowerW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness, height: height)

            // Boss 19:55: "上下结构的区域约束宽度是一样大小的" — Inspector 30% upper
            // and Status 30% lower must be the same width. Upper band has 2 splitters
            // (Library|Editor + Editor|Inspector), lower band needs 2 splitters too
            // (Chat|Console + Console|Status) so both bands deduct equal splitter widths.
            // Boss 19:45: "console 15 status 15 这两个加一起是状态区" — but this layout
            // needs an INTERNAL Console|Status splitter so widths align with the upper
            // band's two-splitter deduction. Console + Status are still conceptually one
            // "状态区" (= single Status pane); the splitter is the necessary structural
            // cost of the band width-matching constraint.
            ZoneScaffoldView(name: "CONSOLE")
                .frame(width: rightW * vm.consoleStatusRatio, height: height)

            NativeSplitter(orientation: .horizontal) { delta in
                vm.adjustConsoleStatus(delta: delta, totalWidth: rightW)
            }
            .frame(width: NativeSplitterView.hitAreaThickness, height: height)

            ZoneScaffoldView(name: "STATUS")
                .frame(width: rightW * (1.0 - vm.consoleStatusRatio), height: height)
        }
    }
}

// MARK: - Library (Shelf + Project nested horizontal split, left/right)
// Boss 19:10 "项目管理区的分隔有问题, 不是左右结构" → HStack (left=Shelf, right=Project).
// Boss 19:30: FCP 的项目管理 = 两栏 (= 目录树 + 素材). Wenshu 落地 = Shelf (= 目录树/
// 多小说) + Project (= 素材/项目文档). Boss 19:35 followup: Library 父区 + Shelf +
// Project 之间都用 NativeSplitter (= 视觉拆开, 不是粘在一起).
// Boss 19:45: Shelf|Project = 各 10% (= 1:1 internal split, libraryShelfFraction = 0.50).
struct LibraryScaffold: View {
    @Environment(LayoutShellViewModel.self) private var splits
    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor).ignoresSafeArea()
            GeometryReader { geo in
                // Compute explicit pixel widths from parent's actual size (= boss 19:55
                // style: use real GeometryReader, not magic .infinity). This avoids the
                // HStack + maxWidth:.infinity collision that visually crushed the splitter.
                let totalW = geo.size.width
                let totalH = geo.size.height
                let hitW = CGFloat(NativeSplitterView.hitAreaThickness)
                let shelfW = (totalW - hitW) * splits.libraryShelfFraction
                let projectW = (totalW - hitW) * (1.0 - splits.libraryShelfFraction)

                HStack(spacing: 0) {
                    ZoneScaffoldView(name: "SHELF")
                        .frame(width: shelfW, height: totalH)
                    NativeSplitter(orientation: .vertical) { delta in
                        // Library internal split: Shelf vs Project (= boss 19:45 "各 10").
                        let totalWidth = totalW - hitW
                        let deltaRatio = Double(delta / totalWidth)
                        let newFraction = splits.libraryShelfFraction + deltaRatio
                        splits.libraryShelfFraction = min(max(newFraction, LayoutShellViewModel.minRatio), LayoutShellViewModel.maxRatio)
                    }
                    .frame(width: hitW, height: totalH)
                    ZoneScaffoldView(name: "PROJECT")
                        .frame(width: projectW, height: totalH)
                }
            }
            parentLabel
        }
    }

    /// Library occupies 20% of total window width (= boss 19:45 "library 20").
    /// This constant is the total-width reference for Library internal drag delta math.
    /// TODO v0.02.0: replace with GeometryReader { $0.size.width } to read actual width.
    private static let parentLibraryFraction: CGFloat = 0.20

    private var parentLabel: some View {
        Text("LIBRARY")
            .font(.system(size: 18, weight: .semibold, design: .default))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
    }
}

// MARK: - Zone scaffold (dim watermark + Apple Semantic Color background)
//
// Boss 19:20 "颜色用苹果新的颜色规则, 不写色值" → use macOS 27.0 system semantic
// colors (= .windowBackgroundColor / .controlBackgroundColor / .black) instead of
// hardcoded RGB. SOUL Law 6: walk Apple's path (= no raw RGB).
struct ZoneScaffoldView: View {
    let name: String
    let background: Color

    init(name: String, background: Color? = nil) {
        self.name = name
        self.background = background ?? Self.defaultBackground(for: name)
    }

    /// Apple Semantic Color per zone role (= macOS 27.0 Liquid Glass design system).
    /// NO raw RGB — uses system tokens that automatically adapt to dark/light/contrast.
    static func defaultBackground(for name: String) -> Color {
        switch name {
        case "EDITOR":
            return Color.black                                    // FCP Viewer convention
        case "INSPECTOR":
            return Color(nsColor: NSColor.controlBackgroundColor)  // slightly lighter than windowBackground in dark mode
        case "LIBRARY", "SHELF", "PROJECT", "CHAT", "CONSOLE", "STATUS":
            return Color(nsColor: NSColor.windowBackgroundColor)
        default:
            return Color(nsColor: NSColor.windowBackgroundColor)
        }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            watermark
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var watermark: some View {
        Text(name)
            .font(.system(size: 72, weight: .bold, design: .default))
            .foregroundStyle(.secondary.opacity(0.18))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsHitTesting(false)
    }
}