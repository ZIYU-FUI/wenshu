// ZoneStyle.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆 Zone/ (t_1831ad61)
//
// Doc-Role: Zone/ZoneStyle
// Responsibilities: Zone 视觉装饰 ViewModifier (FCP 范式 chrome)
// Inputs: 5 区 PanelID (用于差异化 spacing / corner radius)
// Outputs: View (沿 zoneStyle modifier 注入 chrome)
// Dependencies: 无 (纯 ViewModifier)
// Threading: @MainActor
//
// FCP 范式 chrome (沿 V0-fix-11 + LT-N1 + v0.04.0 fold 真值):
//   - 5 Zone 一致 spacing (8pt)
//   - 背景 = window background (系统色, 跟 macOS HIG 对齐)
//   - 不加 corner radius / shadow (Zone 边界由 NativeSplitter 1pt 细线
//     天然分隔, 不抢焦点)
//
// 红线: 不加 store/actor binding, 不改 ZoneContext 字段。

import SwiftUI

struct ZoneStyle: ViewModifier {
    let panelID: PanelID

    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

extension View {
    /// FCP 范式 Zone chrome — 8pt 内边距 + 窗口背景色。
    func zoneStyle(_ panelID: PanelID) -> some View {
        modifier(ZoneStyle(panelID: panelID))
    }
}
