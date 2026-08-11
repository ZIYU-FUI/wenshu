// EditorBottomToolbar.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 底 toolbar (DESIGN-LT-N3.md §5.5.2) — 32pt 高, FCP viewer 范式。
// 3 槽: 左下 (本卡 MVP 留空) / 中下 (永远空) / 右下 ⤢ 全屏 toggle。

import SwiftUI

struct EditorBottomToolbar: View {
    let isFullScreen: Bool
    let onFullScreenToggle: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 左下: 3 ICON 按钮预留位, 本卡 MVP 不画 (留空 shell)
            Color.clear.frame(width: 200, alignment: .leading)
            Spacer()
            // 中下: 永远空 (FCP 时码, 文枢不复制)
            Color.clear
            Spacer()
            // 右下: ⤢ 全屏 toggle
            Button(action: onFullScreenToggle) {
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
