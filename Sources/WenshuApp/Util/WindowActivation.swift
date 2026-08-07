// WindowActivation.swift · 文枢 (Wenshu) · v0.01.0 WO-007
//
// 修复 SwiftUI macOS sheet 在 parent app 不是 foreground 时的 key window bug。
//
// 根因(装机 user 8/7 反馈):
// 装机 user 用 Hermes/飞书 时 focus 在那两个 app,点 WenshuApp 的 +
// → sheet 弹出 + TextField 视觉激活(蓝色边框/光标闪)
// → 但键盘输入实际路由回原 key app(Hermes/飞书),WenshuApp 的
//   sheet 没收到任何 key event。
//
// 原因:SwiftUI 的 `.sheet(isPresented:)` 在 macOS 上包装成
// NSWindow(贴在 parentWindow 上),但 SwiftUI 调 `parentWindow.makeKeyAndOrderFront`
// 时,有时不会自动给 sheet window 也 makeKey,AppKit 的 key
// window dispatch 还停在原 key app 上,导致 TextField 看着 active
// 但 firstResponder 不在自己 NSWindow 里。
//
// 修法(Solution A per WO-007 spec):
// - sheet .onAppear 后 0.3s,遍历 NSApp.windows,找 sheet window(空
//   title 或 .titled styleMask),调 `makeKey()` 强制抢 key window。
// - 0.3s delay 错开 sheet 弹出动画(动画期间 SwiftUI 内部正在做
//   view hierarchy 重建,直接 makeKey 会被覆盖)。
// - 仅在 macOS 上激活(iOS/iPadOS 的 sheet 不需要这个)。
//
// 边界:
// - 不动 WenshuStoreActor / LLM 签名 / ChatViewModel。
// - 不动 Package.swift / AGENTS.md / CLAUDE.md / README.md。
// - 只修 ProjectCreateView 这个 sheet 的焦点路由。

import AppKit

enum WindowActivation {
    /// 强制把当前最上层的 sheet window 抢成 key window。
    /// 必须在 sheet 已经 animating in 之后调用(0.3s delay 错开动画)。
    ///
    /// 行为:
    /// 1. 遍历 NSApp.windows,过滤 visible
    /// 2. 优先找 sheet 类型的 window(sheet parent != nil 且 title == 空)
    /// 3. 找不到再 fallback 到第一个 title 非空的 visible window
    /// 4. 都没有就 no-op(用户可能关掉了所有 window)
    ///
    /// 调用点:ProjectCreateView .onAppear。
    static func forceKeyToWenshuSheet() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // 优先找 sheet window(sheet 是 child window,parent 非空 + title 空)
            let sheetWindow = NSApp.windows.first(where: { window in
                window.isVisible
                    && window.parent != nil
                    && window.title.isEmpty
                    && window.styleMask.contains(.titled)
            })

            if let sheet = sheetWindow {
                sheet.makeKey()
                return
            }

            // fallback:找不到 sheet(可能 sheet 在 macOS 27 SDK 上不再以
            // child window 形式存在),就直接拿第一个 title 非空的
            // visible window makeKey。装机器 user 实机验证用。
            for window in NSApp.windows where window.isVisible {
                if !window.title.isEmpty && window.styleMask.contains(.titled) {
                    window.makeKey()
                    return
                }
            }
        }
    }
}
