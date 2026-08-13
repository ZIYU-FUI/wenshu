// PopupFrame.swift · 文枢 (Wenshu) · v0.05.0 t_ce783c49
//
// Doc-Role:
//   弹窗外壳。 老板 8/13 01:25 OOB 参考 FCP 项目标题弹窗规范 —
//   横向紧凑布局, 弹窗宽度 480-560pt, 边距 16pt, 圆角 12pt。
//   规范真值见 .hermes/kanban/reports/DESIGN-POPUP-FCP-2026-08-13.md。
//
// Responsibilities:
//   - 竖向串 3 段: 标题栏 → 主操作区 (content) → 按钮栏 (footer)
//   - 统一 16pt 外边距 + 8pt 行距 + 12pt 分段间距 + 12pt 圆角
//   - 宽度默认 nil (调用方自己锁), PopupMetrics.width = 520pt 供取用
//
// Inputs:
//   - title: String — 标题栏文案
//   - width: CGFloat? = nil — nil = 不锁宽 (调用方自己 .frame)
//   - height: CGFloat? = nil — nil = 高度跟内容 auto
//   - content: 主操作区 (放 PopupFormRow / PopupChipGroup)
//   - footer: 按钮栏 (放 PopupButtonBar)
//
// Outputs:
//   无回调。 纯布局壳, 交互由 content / footer 自己负责。
//
// Dependencies:
//   SwiftUI only。 不依赖 4 单例 (InspectorViewModel / ChatViewModel /
//   LayoutShellViewModel / WenshuProjectStore), 不依赖 WenshuStoreActor,
//   不碰 .ws schema。
//
// Threading:
//   SwiftUI View = @MainActor 隐式。 无异步、无 Task、无 actor 跨越。

import SwiftUI

/// FCP 风格弹窗外壳: 标题栏 + 主操作区 + 按钮栏, 三段竖排。
///
/// 用法:
///
///     PopupFrame(title: "项目设置", width: PopupMetrics.width) {
///         PopupFormRow(label: "项目名") { TextField("", text: $name) }
///     } footer: {
///         PopupButtonBar(confirmTitle: "保存", onCancel: onCancel, onConfirm: save)
///     }
///
struct PopupFrame<Content: View, Footer: View>: View {
    /// 标题栏文案 (headline, 居左)。
    let title: String
    /// 弹窗宽度。 nil = 不锁宽, 调用方自己挂 `.frame(width:)` —
    /// ProjectCreateView 走这条 (540×480 硬固定沿 V0-fix-1 Fix D)。
    var width: CGFloat?
    /// 弹窗高度。 nil = auto 跟内容 (规范 §1 默认行为)。
    var height: CGFloat?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)

            Divider()
                .padding(.vertical, PopupMetrics.section)

            // 主操作区: 行间距 8pt (规范 §4), 顶对齐 —
            // 高度锁死时多余空间留在下方, 不把行拉散。
            VStack(alignment: .leading, spacing: PopupMetrics.row) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
                .padding(.vertical, PopupMetrics.section)

            footer
        }
        .padding(PopupMetrics.outer)
        .frame(width: width, height: height)
        .background(.background, in: RoundedRectangle(cornerRadius: PopupMetrics.corner))
    }
}

/// 弹窗规范尺寸常量。 单一真值, 4 个 Popup 组件共用 —
/// 改这里 = 全弹窗跟着改 (规范 §1 / §4)。
enum PopupMetrics {
    /// 弹窗默认宽度 (规范区间 480-560pt 的中位)。
    static let width: CGFloat = 520
    /// 弹窗外边距。
    static let outer: CGFloat = 16
    /// 行与行的竖向间距。
    static let row: CGFloat = 8
    /// 行内 label ↔ control 的横向间距。
    static let inner: CGFloat = 12
    /// 分段 (标题 / 内容 / 按钮) 之间的间距。
    static let section: CGFloat = 12
    /// 弹窗圆角。
    static let corner: CGFloat = 12
    /// PopupFormRow label 固定宽度。
    static let label: CGFloat = 96
    /// chip 圆角。
    static let chipCorner: CGFloat = 8
}
