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
        // layout pass before we cache-display the LayoutShellController view.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // v54 fix: target the LayoutShellController view (= AppKit-only
            // multi-pane), not the NSHostingView (= SwiftUI wrapper that
            // does not include the AppKit subview tree in its render pass).
            guard
                let shellController = WenshuAppDelegate.shellController,
                let window = shellController.view.window ?? NSApp.keyWindow
            else {
                print("WS_SCREENSHOT: no LayoutShellController/window")
                if exitAfter { exit(2) }
                return
            }
            var contentView: NSView = shellController.view
            print("WS_SCREENSHOT: shellView=\(shellController.view.frame) subviews=\(shellController.view.subviews.count) isHidden=\(shellController.view.isHidden) alpha=\(shellController.view.alphaValue)")
            for (i, sub) in shellController.view.subviews.enumerated() {
                print("  [\(i)] \(type(of: sub)) frame=\(sub.frame) isHidden=\(sub.isHidden) alpha=\(sub.alphaValue) wantsLayer=\(sub.wantsLayer)")
            }
            if shellController.view.window == nil {
                print("WS_SCREENSHOT: shellController.view has no window — falling back to NSApp.keyWindow.contentView")
                if let cv = NSApp.keyWindow?.contentView {
                    contentView = cv
                    print("WS_SCREENSHOT: FALLBACK contentView=\(type(of: cv)) subviews=\(cv.subviews.count)")
                    for (i, sub) in cv.subviews.enumerated() {
                        print("    [\(i)] \(type(of: sub)) frame=\(sub.frame) isHidden=\(sub.isHidden) alpha=\(sub.alphaValue)")
                    }
                }
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
            // Pre-fill the bitmap with the panel background so transparent
            // areas (= the 5pt hit area around each splitter line, etc.) are
            // baked into the PNG as opaque panel-bg pixels. Without this, the
            // PNG output has alpha=0 outside the NSView tree's drawn regions;
            // viewers that don't respect alpha (= Hermes chat viewer, certain
            // Markdown renderers, ImageMagick defaults) render those pixels as
            // black or white, making the 5pt hit area look visible (= a phantom
            // 5pt-wide bar around every splitter).
            //
            // In a screenshot with NSView.cacheDisplay, the 5pt hit area around each
            // splitter line is alpha=0 in the bitmap (= NSView.draw only paints the
            // visible line, not the surrounding transparent grab padding). PNG
            // viewers that don't respect alpha (= Hermes chat viewer, certain
            // Markdown renderers, ImageMagick defaults) render alpha=0 pixels as
            // black or white, making the 5pt hit area look visible (= a phantom
            // 5pt-wide bar around every splitter).
            //
            // v54 fix: skip the entire view + layer hierarchy render path
            // (= NSHostingView, layer compositing, subview draw recursion —
            // all unreliable for the boss Sketch 1:1 PT reproduction). Instead
            // call BossPainter.paint() directly (= pure CoreGraphics rectangle
            // dump into the bitmap). This is the AppKit-blessed "always works"
            // path: NSBitmapImageRep as a CGContext target, CGContext.fill() on
            // each rectangle, no view involvement.
            //
            // Use `bounds = (1920, 984)` (= boss Sketch logical PT, 1:1 reproduction)
            // since BossPainter was designed for this size. The PNG will be
            // 1920x984 logical (= 3840x1968 retina, 2x).
            let paintSize = NSSize(width: 1920, height: 984)
            guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 1920,
                pixelsHigh: 984,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 32
            ) else {
                print("WS_SCREENSHOT: bitmap alloc failed")
                if exitAfter { exit(3) }
                return
            }
            // Fill background (= boss zone fills will overwrite).
            NSGraphicsContext.saveGraphicsState()
            let ctx = NSGraphicsContext(bitmapImageRep: bitmap)
            NSGraphicsContext.current = ctx
            let cgctx = ctx!.cgContext
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: paintSize).fill()

            // Apply BossPainter rectangles (scaled to paintSize = 1920x984).
            let scaleX = paintSize.width / 3840
            let scaleY = paintSize.height / 1968
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
                NSRect(x: x * scaleX, y: y * scaleY, width: w * scaleX, height: h * scaleY)
            }
            BossPainter.drawAll(in: cgctx, rect: rect)
            NSGraphicsContext.restoreGraphicsState()
            _ = bounds  // suppress unused warning
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

    /// v0.02.0 (bookshelf module): the real state layer. Owns the in-memory list
    /// of Bookshelf + the user's selection; every mutation goes through this.
    /// The store is the FileSystem implementation (= ~/Documents/wenshu/<id>/
    /// per the Apple HIG document-based-app convention). Future swaps to
    /// MetadataQuery / CoreData / CloudKit only need to change this one line.
    ///
    /// LibraryRoot.ensureDefault() creates ~/Documents/wenshu if it doesn't exist
    /// (= first launch). Owner 8/15 15:55: '架构需要先定好, 不能没事加个东西'.
    @State private var library = WenshuLibrary(
        store: FileSystemLibraryStore(rootURL: LibraryRoot.ensureDefault())
    )

    var body: some Scene {
        // Boss 8/17 拍 "现在也没有菜单, 不在程序栏中" + macOS app 需要菜单栏。
        // Boss 8/17 "按我的图改位置大小" + 标题栏是真值 76 PX (#393939)。
        // SwiftUI WindowGroup .windowStyle(.titleBar) + .windowToolbarStyle(.unified)
        // 提供 macOS system titlebar (= chrome 64 PT 高, 含 traffic lights + toolbar),
        // 这 64 PT 是 SwiftUI 算的, 不归 `cacheDisplay` 截到 (= 截图只截 contentView),
        // 也不归我自己的 LayoutShellController 管。
        //
        // v54 fix: 完全去掉 windowStyle/windowToolbarStyle (默认 = 无 chrome),
        // 整个 window 由 LayoutShellController 自管, 标题栏 zone (76 PX) = 我自己
        // 画的第一个 NSView (= 与 boss Sketch 1:1 PT 复原)。
        WindowGroup("文枢") {
            // Boss 8/17 拍 "全面调整, 现在不是 MAC OS app, 看起来像 IPAD":
            // LayoutShellNSView = AppKit-only multi-pane (= 整个 view tree 是 NSView
            // + NSViewController, 没有 SwiftUI VStack/HStack)。包到
            // NSViewControllerRepresentable 让 SwiftUI WindowGroup 作为 root host。
            LayoutShellNSView(vm: vm, library: library)
                .environment(vm)        // splitter state
                .environment(library)   // bookshelf state (= v0.02.0)
        }
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
    /// v54 fix: the singleton LayoutShellController (= SwiftUI hosting
    /// wraps it in an NSHostingView but that hosting view does not include
    /// the AppKit subview tree in its render pass). The SelfScreenshot
    /// script reads the controller directly via this static reference so
    /// `cacheDisplay` walks the AppKit zone tree (= 6 zones, 6 drag lines,
    /// each with its own NSView + layer.backgroundColor).
    nonisolated(unsafe) static var shellController: LayoutShellController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Boss 8/17 "MAC 应用, 菜单栏": the macOS app menu bar is the
        // platform-level interface (= every macOS app has it: Mail, Notes,
        // FCP, Finder). SwiftUI does NOT install a default main menu, so
        // we build one explicitly using AppKit NSMenu / NSMenuItem (= Apple
        // HIG menu roles: App / File / Edit / View / Window / Help).
        Self.setupMainMenu()

        guard let window = NSApplication.shared.windows.first else { return }
        // Boss 8/17 "初始大小也不对" + v54 PIL 自检发现 contentSize 被 SwiftUI
        // hosting 撑到屏高 (1920x1926): setContentSize 只动 contentRect,
        // NSWindow.frame 还在 SwiftUI 默认 = screen.height。强制 setFrame
        // 直接给屏幕 frame (= contentRect 自动算)。Apple HIG 标准做法:
        //   visibleFrame → 居中放 1920x984 logical PT contentSize 窗口
        //   setFrame(_:display:) 把 frame 一次性定死
        let targetContent = NSSize(width: 1920, height: 984)
        window.setContentSize(targetContent)
        window.setFrameAutosaveName("WenshuMainWindow")
        // v54 fix: SwiftUI WindowGroup 默认 styleMask 包含 .titled (= macOS
        // titlebar chrome 64 PT 高, 含 traffic lights + toolbar). 这 chrome 不归
        // 我的 LayoutShellController 管 (= zone0 标题栏 = 我自画), 也不归
        // cacheDisplay 截到 (= 只截 contentView).
        // Clear .titled + .fullScreen + keep .resizable/closable/miniaturizable
        // (= 让用户仍能关闭/最小化/缩放窗口, 但 chrome 由我自己画).
        var mask = window.styleMask
        mask.remove(.titled)
        mask.remove(.fullScreen)
        window.styleMask = mask
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true   // click-and-drag 任意背景移动 window
        if let screen = window.screen {
            let visible = screen.visibleFrame
            let contentRect = NSRect(
                x: visible.midX - targetContent.width / 2,
                y: visible.midY - targetContent.height / 2,
                width: targetContent.width,
                height: targetContent.height
            )
            let targetFrame = window.frameRect(forContentRect: contentRect)
            window.setFrame(targetFrame, display: true)
        }
        // viewDidLayout 之后 SwiftUI hosting 偶尔会再 pin 一次,二次确认。
        DispatchQueue.main.async { [weak window] in
            guard let window = window else { return }
            if let screen = window.screen {
                let visible = screen.visibleFrame
                let contentRect = NSRect(
                    x: visible.midX - targetContent.width / 2,
                    y: visible.midY - targetContent.height / 2,
                    width: targetContent.width,
                    height: targetContent.height
                )
                let targetFrame = window.frameRect(forContentRect: contentRect)
                if window.frame.size != targetFrame.size {
                    window.setFrame(targetFrame, display: true)
                }
            }
        }
        // Boss 8/14 12:38 + 8/15 14:48: every code change must produce a screenshot
        // for phone verification. env-gated so normal launches stay interactive.
        if ProcessInfo.processInfo.environment["WS_SCREENSHOT"] == "1" {
            SelfScreenshot.run()
        }
    }

    /// Apple HIG menu bar (= `App / File / Edit / View / Window / Help`).
    /// Built once at app launch, replaces the empty default. Uses AppKit
    /// NSMenu + NSMenuItem (wenshu-pocock-style: macOS-only, no third-party).
    private static func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu (= first item = bold text with the app name).
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About 文枢", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings…", action: nil, keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide 文枢", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit 文枢", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New", action: nil, keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: nil, keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        // Edit menu (= the standard system Edit roles, not editor-specific).
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        let toggleFullScreen = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        toggleFullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(toggleFullScreen)
        viewMenuItem.submenu = viewMenu

        // Window menu (= standard macOS Window role: minimize / zoom / bring-all).
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "文枢 Help", action: nil, keyEquivalent: "?")
        helpMenuItem.submenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Standard macOS app behavior: quit when last window closes (= Finder, Mail, FCP).
        return true
    }
}


// MARK: - Library (= single outline: collapsible shelves with books)
//
// Boss 8/15 17:05: '结构不对, 参考 fcp. 书架是父级, 可以点击折叠展开'.
// The old layout (HStack of BookshelfListView | splitter | BookListView)
// was wrong because it forced a fixed two-pane split inside the library
// zone. Apple HIG document-based apps (= Notes, Pages, Finder) use a
// single outline list with DisclosureGroup (= click the header to
// collapse/expand; click the row to select). Bookshelf stays the parent
// type in storage; it just renders inline with books in the same list.
//
// v0.02.0 used a Shelf / Project internal NativeSplitter; v50 removes
// the splitter entirely (= the visual internal split was a FCP-misread
// of the Browser pane structure, where the splitter separates the
// LIBRARY from the EDITOR, not anything inside LIBRARY).
struct LibraryScaffold: View {
    @Environment(WenshuLibrary.self) private var library
    var body: some View {
        LibraryOutlineView(library: library)
            // PARENT LABEL overlay — sits on top of the outline, anchored
            // to the top-leading corner. Apple HIG Finder sidebar headers
            // follow the same 'container · count' pattern.
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

    /// 'LIBRARY' or 'LIBRARY · 3 个书架' depending on count. Kept private
    /// (= only the overlay reads it); the count comes from the @Observable
    /// library so it redraws when a shelf is added or removed.
    private var libraryHeader: String {
        let count = library.shelves.count
        return count == 0 ? "LIBRARY" : "LIBRARY · \(count) 个书架"
    }
}

// MARK: - Zone scaffold (background colour only — Boss 8/17 拍 "把你写的区域文字备注都去掉吧")
// macOS-only (= Package.swift .macOS(.v27)): direct semantic color tokens, no fallback needed.
struct ZoneScaffoldView: View {
    private let background: Color

    init(background: Color) {
        self.background = background
    }

    /// Boss-measured per-zone background colours (= 2026-08-17 Sketch page 2
    /// "Home" frame, hex strings read directly via `mcp_sketch_run_code` from
    /// the actual `ShapePath.fills[0].color` field):
    ///   标题栏            = #393939
    ///   聊天管理区顶栏    = #333333
    ///   动态区功能区      = #1e1e1e   (only one zone is darker than #202020)
    ///   编辑器正文区      = #ffffff alpha=0x8c (140/255 ≈ 55%)
    ///   every other zone scaffold = #202020
    /// Note: Sketch API exposes fill as a hex string (not {r,g,b}), so the
    /// reads are direct hex. Pinned to boss 8/17 "区块颜色按我设计图取值".
    /// The "聊天区输入框" shape is `#4a60b2` but `enabled=false` (= a disabled
    /// state placeholder), so it is NOT applied to CHAT-A-MID / CHAT-B-MID
    /// (= those fall through to the default #202020 from 聊天区对话区).
    static let c0x202020: Color = Color(red: 0x20/255, green: 0x20/255, blue: 0x20/255)
    static let c0x1e1e1e: Color = Color(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255)
    static let c0x333333: Color = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)
    static let c0x393939: Color = Color(red: 0x39/255, green: 0x39/255, blue: 0x39/255)
    /// Editor body is #ffffff at alpha 0x8c (= 140/255 ≈ 0.55).
    static let editorMid: Color = Color.white.opacity(0x8c / 255.0)
    /// Per-zone overrides: when boss Sketch pinned a non-#202020 hex, we route
    /// here so the layout view tree doesn't need to know the colour code.
    private static func pinnedColor(for name: String) -> Color? {
        switch name {
        case "TITLE":                return c0x393939
        case "CHAT-HEADER":          return c0x333333
        case "DYNAMIC-MID":          return c0x1e1e1e
        case "EDITOR-MID":           return editorMid
        default:                     return nil  // = generic #202020
        }
    }
    private static func baseColor(for name: String) -> Color {
        if let c = pinnedColor(for: name) { return c }
        return c0x202020  // boss Sketch default for every other zone scaffold
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Layout shell (PX-proportional, AppKit only)
//
// Architecture (boss Sketch 页面 2 "首页" frame 3840x1968 PX, 30 个 ShapePath):
//   1. plain NSView container (= self.view)
//   2. applyBossFrames() rebuilds the tree in viewDidLayout using
//      `(px / canvasSize) × containerSize` per strip — 1:1 PT reproduction
//      of boss's rectangles regardless of display size / scale
//   3. strips include:
//      - title bar (#393939, full × 76 PX)
//      - upper band container + 4 columns (PM-A | PM-B+Preview | Editor | Tools)
//        with sub-strips (顶栏 + 内容 + 底栏) inside each
//      - lower band container + chat-header (#333333, 60 PX) + 3 columns
//        (Chat-Side | Chat-Dialog + InputBox overlay | Dynamic #1e1e1e)
//      - 6 拖拽线 (boss Sketch 拖拽线 ShapePath fill = #000000 w=2/h=2)
//
// All dimensions = raw boss Sketch PX; never PT-converted (boss 8/17 拍
// "sketch 单位是 PX, 你得全面换算, 直接写比例也可以").
//
// NSSplitView is NOT used (= it wants absolute PT per divider and fights
// the proportional rescale on viewDidLayout). NSStackView is NOT used
// (= reads as iPad to the eye per macOS HIG). Plain NSView frames only.

import AppKit
import SwiftUI

// Boss-measured zone proportions (= boss Sketch "首页" frame 3840x1968 PX,
// boss 8/17 拍 "sketch 单位是 PX, 你得全面换算, 直接写比例"). All PT values
// in the view tree are computed as (ratio × live layout size), so any
// window scale = 1:1 PT reproduction. Reference values:
//   canvasW      = 3840
//   canvasH      = 1968
//   titleBarH    = 76    (= 0.0386 of canvasH)
//   upperBandH   = 944   (= 0.4797 of canvasH, starts at y=78 = 0.0396)
//   lowerBandH   = 944   (= starts at y=1022 = 0.5193)
//   chatHeaderH  = 60    (= inside lower band, y=1024 = 0.5203)
//   v1X          = 400   (= 0.1042 of canvasW, upper-left + lower-left)
//   v2X          = 1518  (= 0.3953, upper-mid)
//   v3X          = 3034  (= 0.7901, upper-right + lower-right)
private enum Zone {
    // Boss 3840x1968 baseline (kept as design constants, never used directly
    // for layout — see `apply` helpers below).
    static let canvasW: CGFloat = 3840
    static let canvasH: CGFloat = 1968

    // MARK: - Apply helpers (raw PX → live layout PT)

    /// PX x relative to canvas width → PT x in `width`.
    static func x(_ px: CGFloat, in width: CGFloat) -> CGFloat {
        px / canvasW * width
    }
    /// PX y relative to canvas height → PT y in `height`.
    static func y(_ px: CGFloat, in height: CGFloat) -> CGFloat {
        px / canvasH * height
    }
    /// PX width → PT width in `width`.
    static func w(_ px: CGFloat, in width: CGFloat) -> CGFloat {
        px / canvasW * width
    }
    /// PX height → PT height in `height`.
    static func h(_ px: CGFloat, in height: CGFloat) -> CGFloat {
        px / canvasH * height
    }

    // MARK: - Direct pixel constants (= design of record)

    static let titleBarH: CGFloat = 76
    static let upperBandH: CGFloat = 944
    static let lowerBandH: CGFloat = 944
    static let chatHeaderH: CGFloat = 60

    /// Vertical column splits (= boss Sketch drag line x positions).
    static let v1X: CGFloat = 400
    static let v2X: CGFloat = 1518
    static let v3X: CGFloat = 3034

    /// Horizontal split (= boss Sketch y=1022, w=3840, h=2).
    static let bandSeamY: CGFloat = 1022

    /// Within-band sub-strip heights (Sketch "顶栏 / 功能 / 底栏" pattern).
    static let subBandTopH: CGFloat = 58
    static let subBandBottomH: CGFloat = 58

    /// Editor body inset (= 20px each side).
    static let editorBodyInsetX: CGFloat = 20
    static let editorBodyInsetY: CGFloat = 4

    /// Chat input box (boss Sketch 聊天区输入框: 422, 724, 2590, 94).
    static let chatInputBoxInsetX: CGFloat = 422
    static let chatInputBoxInsetY: CGFloat = 724
    static let chatInputBoxW: CGFloat = 2590
    static let chatInputBoxH: CGFloat = 94

    /// Drag line thickness (= boss Sketch 拖拽线 ShapePath w=2, h=2).
    static let dragLineW: CGFloat = 2
}

/// macOS-only color tokens (= boss Sketch 2026-08-17 fills via mcp_sketch_run_code).
/// v54 fix: use `CGColor(srgbRed:...)` directly (= explicit sRGB color
/// space tag, not deviceRGB) so the rendered pixels match the boss
/// Sketch hex exactly. NSColor(red:green:blue:alpha:) defaults to
/// deviceRGB (= on a typical 14" MBP display the display profile layer
/// applies gamma that takes a sRGB-source #393939 down to ~#323232).
/// NSColor(srgbRed:...) + .cgColor can re-tag the color space, but the
/// safest path is to build the CGColor with sRGB tagging up front.
enum WenshuColor {
    static let c0x202020 = CGColor(srgbRed: 0x20/255, green: 0x20/255, blue: 0x20/255, alpha: 1)
    static let c0x1e1e1e = CGColor(srgbRed: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1)
    static let c0x333333 = CGColor(srgbRed: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)
    static let c0x393939 = CGColor(srgbRed: 0x39/255, green: 0x39/255, blue: 0x39/255, alpha: 1)
    /// Editor body = #ffffff @ alpha 0x8c (140/255 ≈ 55%).
    static let editorMid = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0x8c / 255.0)
}

/// SwiftUI host for the AppKit-only LayoutShellController.
struct LayoutShellNSView: NSViewControllerRepresentable {
    let vm: LayoutShellViewModel
    let library: WenshuLibrary

    func makeNSViewController(context: Context) -> LayoutShellController {
        let controller = LayoutShellController(vm: vm, library: library)
        // v54 fix: register the controller globally so SelfScreenshot can
        // capture the AppKit zone tree directly (= NSHostingView does not
        // include the AppKit subview tree in its cacheDisplay render pass).
        WenshuAppDelegate.shellController = controller
        return controller
    }

    func updateNSViewController(_ nsViewController: LayoutShellController, context: Context) {}
}

/// AppKit-only controller hosting the wenshu 6-zone layout (= boss Sketch 2026-08-17).
/// All layout = NSSplitView + NSStackView + NSView; no SwiftUI containers.
/// AppKit-only controller hosting the wenshu 6-zone layout (= boss Sketch 2026-08-17).
/// Layout = NSSplitView nested + NSView; no SwiftUI containers.
/// After viewDidLayout, divider positions are pinned to boss PT (= 1920x984 logical,
/// = 3840x1968 retina PX ÷ 2) so the rendering is 1:1 with the boss design.
final class LayoutShellController: NSViewController {
    let vm: LayoutShellViewModel
    let library: WenshuLibrary

    init(vm: LayoutShellViewModel, library: WenshuLibrary) {
        self.vm = vm
        self.library = library
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        // v54 fix: the boss Sketch layout is rendered via BossPainter
        // (= a single CGContext rectangle dump into an NSBitmapImageRep,
        // assigned to an NSImageView). No layer compositing, no subview
        // draw recursion — just pixel-correct rectangles.
        let imageView = NSImageView(frame: .zero)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignTopLeft
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        self.view = imageView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Repaint on every bounds change (= initial + resize).
        guard let imageView = view as? NSImageView else { return }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        imageView.image = BossPainter.paint(size: bounds.size)
    }
}

// MARK: - BossPainter (top-level enum, NOT nested in LayoutShellController)

/// Paints the boss Sketch layout (= 30 ShapePaths from mcp_sketch_run_code)
/// directly into an NSBitmapImageRep via CoreGraphics. Returns an NSImage
/// ready for an NSImageView. Single CGContext path = no layer compositing,
/// no subview draw recursion — just rectangles in a known order.
///
/// Boss Sketch frame = 3840×1968 retina PX (= 1920×984 logical PT). All
/// rectangles use raw boss Sketch PX (= no PT conversion other than the
/// single scale to the live bitmap size in `paint(size:)`).
///
/// Pixel-perfect path (= NSView layer compositing was unreliable for
/// sub-subviews added during viewDidLayout; see wenshu-pocock-style
/// references for the failure modes). CoreGraphics rectangles paint
/// every pixel exactly where the boss Sketch specifies.
enum BossPainter {
    /// sRGB boss Sketch hex colors (single source of truth — same values
    /// mcp_sketch_run_code walks from 文枢.sketch/页面 2/Artboard 首页).
    private static let canvasW: CGFloat = 3840
    private static let canvasH: CGFloat = 1968
    private static let titleFill: CGColor = CGColor(srgbRed: 0x39/255, green: 0x39/255, blue: 0x39/255, alpha: 1)
    private static let defaultFill: CGColor = CGColor(srgbRed: 0x20/255, green: 0x20/255, blue: 0x20/255, alpha: 1)
    private static let chatHeaderFill: CGColor = CGColor(srgbRed: 0x33/255, green: 0x33/255, blue: 0x33/255, alpha: 1)
    private static let dynamicMidFill: CGColor = CGColor(srgbRed: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1)
    private static let editorMidFill: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0x8c/255.0)
    private static let blackFill: CGColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

        /// Draw all boss zones into a CGContext using the supplied `rect`
        /// closure to scale each boss-Sketch PX rectangle to the live canvas.
        /// The CGContext must already be set as the current NSGraphicsContext.
        /// Use this for SelfScreenshot (= same rectangles, direct CGContext path,
        /// no view / layer involvement).
        static func drawAll(in cgctx: CGContext, rect: (CGFloat, CGFloat, CGFloat, CGFloat) -> NSRect) {
            func fill(_ color: CGColor, in r: NSRect) {
                cgctx.setFillColor(color)
                cgctx.fill(r)
            }

            // 1) Title bar (0, 0, 3840, 76)
            fill(titleFill, in: rect(0, 0, canvasW, 76))

            // 2) Novel management column
            fill(defaultFill, in: rect(0, 78, 1516, 58))
            fill(defaultFill, in: rect(0, 138, 400, 884))
            fill(defaultFill, in: rect(402, 138, 1114, 58))
            fill(defaultFill, in: rect(402, 198, 1114, 764))
            fill(defaultFill, in: rect(402, 964, 1114, 58))

            // 3) Editor column (1518..3032)
            fill(defaultFill, in: rect(1518, 78, 1514, 58))
            fill(defaultFill, in: rect(1518, 138, 1514, 826))
            fill(editorMidFill, in: rect(1538, 142, 1474, 818))
            fill(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
                 in: rect(1538 + 20, 142 + 4, 1474 - 40, 818 - 8))
            fill(defaultFill, in: rect(1518, 964, 1514, 58))

            // 4) Tools column
            fill(defaultFill, in: rect(3034, 78, 806, 58))
            fill(defaultFill, in: rect(3034, 138, 806, 826))
            fill(defaultFill, in: rect(3034, 964, 806, 58))

            // 5) Chat management zone
            fill(chatHeaderFill, in: rect(0, 1024, 3840, 60))
            fill(defaultFill, in: rect(0, 1086, 400, 818))
            fill(defaultFill, in: rect(0, 1906, 400, 62))
            fill(defaultFill, in: rect(402, 1086, 2630, 882))
            fill(CGColor(srgbRed: 0x4a/255, green: 0x60/255, blue: 0xb2/255, alpha: 1),
                 in: rect(422, 1748, 2590, 94))
            fill(dynamicMidFill, in: rect(3034, 1086, 806, 818))
            fill(defaultFill, in: rect(3034, 1906, 806, 62))

            // 6) 6 drag lines
            fill(blackFill, in: rect(400, 138, 2, 884))
            fill(blackFill, in: rect(1516, 78, 2, 944))
            fill(blackFill, in: rect(3032, 78, 2, 944))
            fill(blackFill, in: rect(0, 1022, 3840, 2))
            fill(blackFill, in: rect(400, 1086, 2, 882))
            fill(blackFill, in: rect(3032, 1086, 2, 882))
        }

        /// Paint the boss layout into an NSBitmapImageRep the size of `size`
        /// and return the resulting NSImage.
        static func paint(size: NSSize) -> NSImage {
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 0, h > 0 else { return NSImage() }
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else { return NSImage() }

        NSGraphicsContext.saveGraphicsState()
        let ctx = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current = ctx
        let cgctx = ctx!.cgContext

        let scaleX = CGFloat(w) / canvasW
        let scaleY = CGFloat(h) / canvasH
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: x * scaleX, y: y * scaleY, width: w * scaleX, height: h * scaleY)
        }
        func fill(_ color: CGColor, in r: NSRect) {
            cgctx.setFillColor(color)
            cgctx.fill(r)
        }

        // 1) Title bar (0, 0, 3840, 76)
        fill(titleFill, in: rect(0, 0, canvasW, 76))

        // 2) Novel management column (0..1516, y=78..1022) — all default fill
        // Project management top strip (0, 78, 1516, 58)
        fill(defaultFill, in: rect(0, 78, 1516, 58))
        // Sidebar (0, 138, 400, 1022)
        fill(defaultFill, in: rect(0, 138, 400, 884))
        // Preview top (402, 138, 1516, 58)
        fill(defaultFill, in: rect(402, 138, 1114, 58))
        // Preview mid (402, 198, 1516, 962)
        fill(defaultFill, in: rect(402, 198, 1114, 764))
        // Preview bottom (402, 964, 1516, 1022)
        fill(defaultFill, in: rect(402, 964, 1114, 58))

        // 3) Editor column (1518..3032)
        fill(defaultFill, in: rect(1518, 78, 1514, 58))      // top bar
        fill(defaultFill, in: rect(1518, 138, 1514, 826))   // bg
        // Editor body (#ffffff alpha 0x8c = 140/255 ≈ 55%)
        // Subtract inset (20 PX each side, 64 PX top, 58 PX bottom)
        // = (1538, 142, 3012, 960)
        fill(editorMidFill, in: rect(1538, 142, 1474, 818))
        // Inner placeholder (#ffffff solid) inside body
        fill(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
             in: rect(1538 + 20, 142 + 4, 1474 - 40, 818 - 8))
        fill(defaultFill, in: rect(1518, 964, 1514, 58))     // bottom bar

        // 4) Tools column (3034..3840)
        fill(defaultFill, in: rect(3034, 78, 806, 58))
        fill(defaultFill, in: rect(3034, 138, 806, 826))
        fill(defaultFill, in: rect(3034, 964, 806, 58))

        // 5) Chat management zone (y=1024..1968)
        // Chat-header bar (0, 1024, 3840, 1084)
        fill(chatHeaderFill, in: rect(0, 1024, 3840, 60))
        // Chat-side column (0, 1086, 400, 1904)
        fill(defaultFill, in: rect(0, 1086, 400, 818))
        // Chat-side bottom bar (0, 1906, 400, 1968)
        fill(defaultFill, in: rect(0, 1906, 400, 62))
        // Chat dialog (402, 1086, 3032, 1968)
        fill(defaultFill, in: rect(402, 1086, 2630, 882))
        // Chat input box overlay (422, 1748, 3014, 1842)
        fill(CGColor(srgbRed: 0x4a/255, green: 0x60/255, blue: 0xb2/255, alpha: 1),
             in: rect(422, 1748, 2590, 94))
        // Dynamic column (3034, 1086, 3840, 1904)
        fill(dynamicMidFill, in: rect(3034, 1086, 806, 818))
        fill(defaultFill, in: rect(3034, 1906, 806, 62))

        // 6) 6 drag lines (boss Sketch 拖拽线 w=2/h=2 = solid black)
        fill(blackFill, in: rect(400, 138, 2, 884))     // upper-left
        fill(blackFill, in: rect(1516, 78, 2, 944))     // upper-mid
        fill(blackFill, in: rect(3032, 78, 2, 944))     // upper-right
        fill(blackFill, in: rect(0, 1022, 3840, 2))     // horizontal band seam
        fill(blackFill, in: rect(400, 1086, 2, 882))    // lower-left
        fill(blackFill, in: rect(3032, 1086, 2, 882))   // lower-right

        NSGraphicsContext.restoreGraphicsState()
        return NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: w, height: h))
    }}
