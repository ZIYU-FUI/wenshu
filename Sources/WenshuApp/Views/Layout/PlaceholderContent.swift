// PlaceholderContent.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01
//
// Empty-state content shown inside each of the 5 panels during LT-01.
// Subsequent LTs replace these with their real content:
//   - LT-02 → 右上 inspector (伏笔 + 修订 tab)
//   - LT-03 → 左上 项目管理 (项目 / 章节 / 设定 / 资料 / 看板 tab)
//   - LT-04 → 下左 聊天区 (聊天 / 时间线 / 关系图 / 大纲 tab)
//
// Design intent (visual contract for 装机 user verification):
// - Centered SF Symbol + panel title + a 1-line hint of what lands here.
// - Avoids looking like a TODO-list or broken UI — looks intentional
//   ("LT-01: layout shell, content lands in LT-N").

import SwiftUI

struct PlaceholderContent: View {
    let panel: PanelID

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: panel.symbolName)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text(panel.title)
                .font(.title3)
                .fontWeight(.medium)
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var hint: String {
        switch panel {
        case .topLeft:
            return "LT-03 将在此填充：项目 / 章节 / 设定 / 资料 / 看板"
        case .topCenter:
            return "v0.05.0 起填充：正文编辑器 + 标记系统 + 选区右键"
        case .topRight:
            return "LT-02 将在此填充：伏笔 / 修订 inspector"
        case .bottomLeft:
            return "LT-04 将在此填充：聊天（实装）+ 时间线 / 关系图 / 大纲（disabled）"
        case .bottomRight:
            return "v0.03.0 阶段门 / v0.04.0 长篇工具 阶段在此填充：TODO + 状态变化"
        }
    }
}
