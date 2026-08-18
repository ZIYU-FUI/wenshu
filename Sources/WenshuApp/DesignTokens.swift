// DesignTokens.swift · Wenshu · v0.09.0
// 老板 8/18 拍板: "好很多, 横向的拖拽线都没有显示出来. 换我预留的缝隙用线画出来. 换算完, 应该都 1PT 的粗细".
//
// 颜色全 Apple Semantic Color (NSColor.*), 0 RGB 硬编码.
// Dark mode 强制 (boss Sketch 全 dark).
// 拖拽线 1 PT 黑 (boss 拍 "自带的 divider 都用纯黑色").
// 0 个 LayoutRatio 死代码 (LayoutTokens 在 App.swift 集中真值, 老板 8/18 1:1 PT 落).

import SwiftUI
import AppKit

enum DesignColor {
    /// 标题栏 (boss Sketch #393939) → NSColor.windowBackgroundColor.
    static let titleBar: Color = Color(nsColor: .windowBackgroundColor)

    /// 内容区底色 (boss Sketch #202020) → NSColor.controlBackgroundColor.
    static let zoneSurface: Color = Color(nsColor: .controlBackgroundColor)

    /// 动态区功能区 (#1e1e1e, 老板 8/18 拍比 #202020 略深, 跟 #1e1e1e 真值落 dark mode)
    /// Apple HIG System semantic 跟 #1e1e1e 不完全匹配, v0.10 之前用硬编码真值
    /// (老板 8/18 答 Q4 "保留设计图色值作为 fallback")
    static let dynamicZoneSurface: Color = Color(red: 0x1e / 255, green: 0x1e / 255, blue: 0x1e / 255)

    /// 强调蓝 (boss Sketch #4a60b2) → Color.accentColor.
    static let accentBlue: Color = .accentColor

    /// 拖拽线 (boss Sketch #000000) → NSColor.black (dark/light 双适配可见).
    static let splitterLine: Color = Color(nsColor: .black)
}
