// EditorBottomToolbar.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器底 toolbar (DESIGN-LT-N3.md §5.5.2):
//
// 拍板 MVP (DESIGN-LT-N3 §2.2.1 底 toolbar = 32pt 高, 3 段):
//   ❌ 左下 (200pt) — 3 ICON 预留位 (FCP 范式, 本卡不画, 真留空 shell)
//   ❌ 中下 — 永远空 (FCP 时码, 文枢不复制)
//   ✅ 右下 — ⤢ 全屏 toggle (FCP viewer 范式 "专注模式")
//
// 背景: `.thinMaterial` (跟顶 toolbar 一致, 沿 FCP viewer 范式)。

import SwiftUI

struct EditorBottomToolbar: View {
    let isFullScreen: Bool
    let onToggleFullScreen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 左下: 3 ICON 预留位, 本卡 MVP 不画 (FCP 范式预留)。
            Color.clear
                .frame(width: 200, alignment: .leading)

            Spacer(minLength: 0)

            // 中下: 永远空 (FCP 时码, 文枢不复制)。
            Color.clear

            Spacer(minLength: 0)

            // 右下: ⤢ 全屏 toggle (沿 DESIGN-LT-N3 §5.5.2 真值真值真值真值)。
            Button(action: onToggleFullScreen) {
                Image(systemName: isFullScreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundStyle(isFullScreen ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isFullScreen ? "退出专注模式" : "专注模式")
            .padding(.trailing, 12)
        }
        .frame(height: 32)
        .background(.thinMaterial)
    }
}
