// PopupButtonBar.swift · 文枢 (Wenshu) · v0.05.0 t_ce783c49
//
// Doc-Role:
//   弹窗底部按钮栏: 取消 (次) + 主操作 (主色填充), 整条右对齐 (规范 §5)。
//
// Responsibilities:
//   - 主操作走 `.borderedProminent` = macOS 原生 accent 填充 + 白字
//     (HIG 兼容, 跟随系统强调色, 不自绘背景)
//   - 键盘: 取消 = Esc (.cancelAction), 主操作 = Enter (.defaultAction)
//   - 主操作可禁用 (表单非法时)
//
// Inputs:
//   - cancelTitle: String = "取消"
//   - confirmTitle: String — 主操作文案 ("创建" / "保存")
//   - confirmDisabled: Bool = false
//   - onCancel / onConfirm: () -> Void
//
// Outputs:
//   onCancel / onConfirm 回调。 本组件不碰数据, 不落库。
//
// Dependencies:
//   SwiftUI + PopupMetrics (PopupFrame.swift)。 不依赖 4 单例,
//   不依赖 WenshuStoreActor。
//
// Threading:
//   SwiftUI View = @MainActor 隐式。 回调在主线程同步触发。

import SwiftUI

/// 弹窗底部按钮栏。 取消 (次) 在左, 主操作 (主色填充) 在右, 整条右对齐。
struct PopupButtonBar: View {
    var cancelTitle: String = "取消"
    let confirmTitle: String
    var confirmDisabled: Bool = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: PopupMetrics.inner) {
            Spacer(minLength: 0)
            Button(cancelTitle, role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: onConfirm)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(confirmDisabled)
        }
    }
}
