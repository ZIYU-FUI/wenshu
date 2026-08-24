//
//  CustomTitleBar.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 拍: 标题栏 2 选 1 (.titleBar 28 PT, .hiddenTitleBar + 自定 52 PT)
//  → 选 52 PT 那款. Apple SwiftUI macOS 14+ 不提供 native 52 PT windowStyle,
//  所以 .hiddenTitleBar + 在 LayoutShellView body 顶部画一个 52 PT 自定标题栏.
//
//  Apple HIG 范式:
//  - 52 PT 高 (跟 Sketch 1920×984 标注一致: 52 + 932 = 984)
//  - 左: traffic light area (左 78 PT 留白, macOS 自动画红黄绿 3 个按钮)
//  - 中: 标题文字 "文枢" (Apple system font, 13 PT, .primary color)
//  - 右: 留白 (right inset 18 PT)
//  - 背景: DesignColor.titleBar (= .windowBackgroundColor, 老板 Sketch #393393939)
//  - bottom: 1 PT splitter line (.splitterLine color)

import SwiftUI

/// CustomTitleBar: 自定 52 PT 顶部标题栏 (替换 macOS native 28 PT titlebar).
/// Boss 8/24 拍用 52 PT 那款 (vs 28 PT Apple 标准).
public struct CustomTitleBar: View {
    public init() {}

    public var body: some View {
        // Apple HIG: traffic light area (78 PT) + title (center) + spacer (right).
        HStack(spacing: 0) {
            // 左 78 PT 留白给 macOS 画 traffic lights (红黄绿 3 个按钮)
            Color.clear.frame(width: 78)
            // 中间标题: 文枢 (Apple system font)
            Text("文枢")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
        }
        .frame(height: 52)  // 老板 Sketch 真值: 52 PT
        .frame(maxWidth: .infinity)
        .background(DesignColor.titleBar)
        // v0.15 ticket 008: 底 1 PT splitter line (zone 分隔)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
    }
}