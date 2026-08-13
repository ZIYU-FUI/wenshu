// EditorTopToolbar.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 顶 toolbar (DESIGN-LT-N3.md §5.5.1) — 28pt 高, FCP viewer 范式。
// 3 槽: 左上字数 / 中上章节面包屑 / 右上 (本卡 MVP 留空, 留给字号 / 显示菜单)。

import SwiftUI

struct EditorTopToolbar: View {
    let chapterTitle: String
    let wordCount: Int

    var body: some View {
        HStack(spacing: 0) {
            // 左上: 字数
            Text("\(wordCount) 字")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .padding(.leading, 12)
            Spacer()
            // 中上: 章节名
            HStack(spacing: 4) {
                // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.docItem
                // (`doc.text`) — 单一真值源。
                Image(systemName: IconLibrary.Action.docItem.symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(chapterTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            Spacer()
            // 右上: 真留空 (FCP 范式, 留给字号 / 显示菜单)
            Color.clear.frame(width: 100)
        }
        .frame(height: 28)
        .background(.thinMaterial)
    }
}
