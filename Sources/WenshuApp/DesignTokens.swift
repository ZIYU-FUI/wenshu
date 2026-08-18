// DesignTokens.swift · Wenshu · v0.09.0
// 老板 8/18 拍板: "好很多, 横向的拖拽线都没有显示出来. 换我预留的缝隙用线画出来. 换算完, 应该都 1PT 的粗细".
//
// 颜色全 Apple Semantic Color (NSColor.*), 0 RGB 硬编码.
// Dark mode 强制 (boss Sketch 全 dark).
// 拖拽线 1 PT 黑 (boss 拍 "自带的 divider 都用纯黑色").
// 0 个 LayoutRatio 死代码 (LayoutTokens 在 App.swift 集中真值, 老板 8/18 1:1 PT 落).

import SwiftUI
import AppKit

// DesignColor enum 删 (v0.10.6 移到 App.swift, DesignTokens.swift 留空文件作为历史 trace)
