// SheetWindow.swift · 文枢 (Wenshu) · v0.01.0 WO-008
//
// 修 SwiftUI macOS sheet 焦点路由 bug 的方案 C(WO-008 spec):
// 不走 SwiftUI `.sheet(isPresented:)` 容器,改用 NSHostingController +
// 显式 NSWindow 完全独立管理弹出窗口。
//
// 根因(WO-008 spec):
// WO-007 方案 A(`NSWindow.makeKey()` 强抢)在装机 user 实机验中失败。
// 截图显示 sheet 视觉激活(蓝色边框/光标闪),但键盘输入仍路由到
// 原 key app(终端/Hermes/飞书)。这是 macOS SwiftUI `.sheet(isPresented:)`
// 已知 bug——sheet 的 NSWindow 被 SwiftUI 内部 lifecycle 强制管理,
// 手动 makeKey() 不一定能稳定生效。
//
// 修法(方案 C,macOS 上公认最稳):
// - 用 NSHostingController 把 SwiftUI view 包成 AppKit NSWindow 的
//   contentViewController,完全脱离 SwiftUI sheet 容器。
// - NSWindow.makeKeyAndOrderFront(nil) 显式抢 key window 状态。
// - NSApp.activate(ignoringOtherApps: true) 强制 app 激活(脱离
//   parentWindow.makeKey 的竞争)。
// - 用 NSWindowDelegate.windowWillClose 监听关闭,触发 onDismiss
//   回调让 parent 做 state 清理(NSWindowDelegate 是 AppKit
//   标准方式,比 NotificationCenter token 在 Swift 6.4 strict
//   concurrency 下更稳 — 后者的 closure 不能 forward-capture
//   自己持有的 token)。
//
// 边界:
// - 不动 WenshuStoreActor / LLM 签名 / ChatViewModel / Package.swift。
// - 不动 AGENTS.md / CLAUDE.md / README.md / swift-tools-version。
// - 只新增本文件 + 改 ProjectListView 的 sheet 触发端。
// - ProjectCreateView 本身不动(它内部仍可能触发 WindowActivation
//   fallback,但因为本文件已显式 makeKeyAndOrderFront,会自然冗余)。

import AppKit
import SwiftUI

// MARK: - NSWindowDelegate(包装 onDismiss)
//
// `NSWindow.delegate` 是 weak 引用,所以 delegate 必须被 strong
// 持有。用 objc associated object 把 delegate 绑到 window 上,window
// 不 dealloc,delegate 就不会 dealloc,父 SwiftUI view 不需要额外
// 持有 delegate(否则会污染 SwiftUI state)。
//
// windowWillClose 是 NSWindowDelegate 标准回调,在窗口即将关闭时
// 触发,适合做 cleanup。NSWindowDelegate 在 AppKit SDK 里继承自
// NSResponder chain,默认 main actor-isolated。
private final class _SheetWindowDelegate: NSObject, NSWindowDelegate {
    let onDismiss: @MainActor () -> Void

    init(onDismiss: @escaping @MainActor () -> Void) {
        self.onDismiss = onDismiss
    }

    func windowWillClose(_ notification: Notification) {
        onDismiss()
    }
}

// associated object key(必须是 fileprivate/global 唯一地址)
private nonisolated(unsafe) var _sheetDelegateAssocKey: UInt8 = 0

enum SheetWindow {
    /// 弹出 SwiftUI view 作为独立 NSWindow(不是 SwiftUI sheet 容器)。
    /// - 自动 makeKey() + makeMain(),脱离 SwiftUI sheet lifecycle。
    /// - 关闭时(用户点 × / ⌘W / Window close button)调 `onDismiss`。
    ///
    /// 用法:
    /// ```swift
    /// SheetWindow.present(
    ///     title: "新建项目",
    ///     content: {
    ///         ProjectCreateView(
    ///             onCreate: { newProject in ... },
    ///             onCancel: { NSApp.keyWindow?.close() }
    ///         )
    ///     },
    ///     onDismiss: { showCreate = false }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - title: 窗口标题(显示在 title bar)
    ///   - content: 返回要显示的 SwiftUI view
    ///   - onDismiss: 窗口即将关闭时调用(parent 用来 reset state)
    ///
    /// - Note: 必须从 main actor 调用(SwiftUI Button action 默认就是
    ///   main actor,所以从 `.sheet(...)` / `Toolbar` / `Button { }` 里
    ///   直接调没问题)。这里显式标 `@MainActor` 是因为 Swift 6.4 strict
    ///   concurrency 强制要求 `NSApp.activate(ignoringOtherApps:)` /
    ///   `NSApp.keyWindow` 这两个 macOS 27 SDK 改 main actor-isolated
    ///   的 API 必须在 main actor 上调用。
    @MainActor
    static func present<V: View>(
        title: String,
        content: () -> V,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 540, height: 500))
        window.center()

        // 装 NSWindowDelegate 监听关闭 → onDismiss
        let delegate = _SheetWindowDelegate(onDismiss: onDismiss)
        window.delegate = delegate
        // 强引用 delegate(window.delegate 是 weak,否则 window 一
        // dealloc delegate 就跟着没了,后续 NSWindow.willClose
        // 触发的 onDismiss 会被 silent drop)
        objc_setAssociatedObject(
            window,
            &_sheetDelegateAssocKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN
        )

        // 方案 C 关键:显式 makeKey + makeMain + activate,脱离 SwiftUI
        // sheet 容器,自己管 window lifecycle。
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
