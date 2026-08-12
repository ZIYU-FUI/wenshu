// FoldToggleButton.swift · 文枢 (Wenshu) · v0.04.0 t_bfa84198
//
// FCP Viewer 顶部 toolbar 的 3 toggle 折叠按钮 (范式 = Final Cut Pro /
// Pages / Numbers: 默认描边 + 区显, 点亮 = fill + accent blue 背景 +
// 区隐)。 1 按钮 ↔ `.topCenter` (中上 viewer), 2 按钮 ↔ 整条下半栏
// (`.bottomLeft` + `.bottomRight`), 3 按钮 ↔ `.topRight` (检视)。
//
// 拍板真值沿 designer wenshu-fcp-fold-3buttons-2026-08-12.md §3.1,
// 8 组合 (3 toggle × OR 关系) 见 FCP3ToggleVisibilityTests。
//
// 边界: `.topLeft` 永远不折叠 (项目列表 常驻); share 按钮 (占位)
// 走单独的 helper 或直接 inline `Button { } label: { Image(...) }
// .disabled(true) }`, 不复用本组件。

import SwiftUI

/// 单个 fold toggle 按钮的视觉变体。 `isVisible == true` → 区显,
/// SF Symbol 描边 + secondary 颜色; `isVisible == false` → 区隐,
/// SF Symbol 白字 + accent blue 圆角背景。
///
/// 复用点: LayoutShellView toolbar 3 toggle + 未来 inspector/底部
/// toolbar 同类按钮。 沿 V0-fix-11 紧凑范式 (28×22 frame, font 14
/// medium, FCP 单 icon 不带按钮背景)。
struct FoldToggleButton: View {
    /// SF Symbol 名字 (e.g. "rectangle.split.3x1", "checklist")。
    let symbol: String
    /// true = 区显 (描边), false = 区隐 (fill + accent blue 背景)。
    let isVisible: Bool
    let action: () -> Void
    /// SwiftUI tooltip 文案。
    let help: String

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 22)
                .foregroundStyle(isVisible ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
                .background(
                    isVisible
                        ? AnyShapeStyle(Color.clear)
                        : AnyShapeStyle(Color.accentColor.opacity(0.85)),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
