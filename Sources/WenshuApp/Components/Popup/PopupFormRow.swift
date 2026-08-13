// PopupFormRow.swift · 文枢 (Wenshu) · v0.05.0 t_ce783c49
//
// Doc-Role:
//   弹窗单行: 横向 label-左 / control-右。 替代 SwiftUI `Form` +
//   `Section` 的 iOS list 竖排观感 (规范 §2 / §5)。
//
// Responsibilities:
//   - label 固定 96pt 右对齐 → 多行 label 竖向对齐成一列
//   - control 吃掉剩余宽度, 居左
//   - 行内 label ↔ control 间距 12pt (规范 §4)
//
// Inputs:
//   - label: String — 行标签
//   - content: 右侧控件 (TextField / Slider / Toggle / PopupChipGroup ...)
//
// Outputs:
//   无回调。 值变化由 content 自己的 Binding 负责。
//
// Dependencies:
//   SwiftUI + PopupMetrics (PopupFrame.swift)。 不依赖 4 单例,
//   不依赖 WenshuStoreActor。
//
// Threading:
//   SwiftUI View = @MainActor 隐式。 无异步。

import SwiftUI

/// 横向 label-left / control-right 单行。 label 固定 96pt 右对齐。
struct PopupFormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: PopupMetrics.inner) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: PopupMetrics.label, alignment: .trailing)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
