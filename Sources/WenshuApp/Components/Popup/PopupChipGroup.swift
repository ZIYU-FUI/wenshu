// PopupChipGroup.swift · 文枢 (Wenshu) · v0.05.0 t_ce783c49
//
// Doc-Role:
//   横向 chip 单选组。 老板 8/13 01:25 OOB "选择框横向 chip 排列" —
//   替代 macOS `.pickerStyle(.segmented)` 的系统分段框 (规范 §3)。
//   视觉沿 FoldToggleButton 既有约定 (accentColor + 白字 = 选中)。
//
// Responsibilities:
//   - options 横向平铺, 间距 6pt
//   - 选中 = accentColor 填充 + 白字; 未选 = quaternary 填充 + primary 字
//   - chip 8pt 圆角 + 横 8pt / 竖 6pt 内边距 (规范 §3)
//   - 点击 chip 写回 selection binding
//
// Inputs:
//   - options: [String] — chip 文案清单 (调用方给顺序)
//   - selection: Binding<String> — 当前选中值
//
// Outputs:
//   selection binding 被写回 (单选, 点谁选谁, 不支持取消选中)。
//
// Dependencies:
//   SwiftUI + PopupMetrics (PopupFrame.swift)。 不依赖 4 单例,
//   不依赖 WenshuStoreActor。
//
// Threading:
//   SwiftUI View = @MainActor 隐式。 点击 action 同步写 @State, 无异步。

import SwiftUI

/// 横向 chip 单选组。 选中 = 主色填充 + 白字, 未选 = 次色填充 + 主字。
///
/// ponytail: 只吃 [String] — 现有 2 处调用 (文笔风格 / 题材) 都是
/// String 清单。 等出现非 String 选项 (带 icon / 带 id 的模型) 再泛型化。
struct PopupChipGroup: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: String) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
        } label: {
            Text(option)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(
                    isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary)
                )
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: PopupMetrics.chipCorner)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(option)
    }
}
