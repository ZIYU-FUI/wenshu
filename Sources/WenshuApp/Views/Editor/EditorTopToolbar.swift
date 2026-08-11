// EditorTopToolbar.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器顶 toolbar (DESIGN-LT-N3.md §5.5.1):
//
// 拍板 MVP (DESIGN-LT-N3 §2.2.1 顶 toolbar = 28pt 高, 3 段):
//   ✅ 左上 (100pt) — `字数` 实时 + `●` 脏标记
//   ✅ 中上 — 章节名面包屑 (SF Symbol doc.text + Text 章节名)
//   ✅ 右上 (100pt) — 空槽 (留给 v0.04.0 字号 / 显示菜单, 本卡不画)
//
// 背景: `.thinMaterial` (DESIGN-LT-N3 §5.5.1, macOS SwiftUI 材质, 暗色
// toolbar 背景首选, 沿 FCP viewer 范式)。
//
// 不实装 (DESIGN-LT-N3 §2.2.1 派生):
//   ❌ 右上 字号 / 显示 / 同步 菜单 — v0.04.0 子卡

import SwiftUI

struct EditorTopToolbar: View {
    let chapterTitle: String
    let wordCount: Int
    let isDirty: Bool

    var body: some View {
        HStack(spacing: 0) {
            // 左上: 字数 + 脏标记 (DESIGN-LT-N3 §7.2 dirty 状态)
            HStack(spacing: 4) {
                if isDirty {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
                Text("\(wordCount) 字")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 100, alignment: .leading)
            .padding(.leading, 12)

            Spacer(minLength: 0)

            // 中上: 章节名面包屑 (SF Symbol doc.text + 章节名)
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(chapterTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // 右上: 空槽 (留给 v0.04.0 字号 / 显示菜单, 本卡不画)
            Color.clear
                .frame(width: 100)
        }
        .frame(height: 28)
        .background(.thinMaterial)
    }
}
