// PlaceholderContent.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix6
//
// Empty-state content shown inside each of the 5 panels during LT-01.
// Subsequent LTs replace these with their real content:
//   - LT-02 → 右上 inspector (伏笔 + 修订 tab)
//   - LT-03 → 左上 项目管理 (项目 / 章节 / 设定 / 资料 / 看板 tab)
//   - LT-04 → 下左 聊天区 (聊天 / 时间线 / 关系图 / 大纲 tab)
//
// Design intent (visual contract for 装机 user verification):
// - LT-01-fix6 装机 user 拍板: **不要任何标题文字**. fix5 删了
//   PanelContainer 的 headerBar 却在 content 里补了一个 H1, 视觉上
//   跟原 headerBar 一模一样 — 等于没删. 真拍板真值是"用功能告诉
//   用户", 跟 FCP 浏览器一致 (FCP 的浏览器区没有标题).
// - 因此 panel 只露: 居中 SF Symbol + 1 行 "这里将来放什么" 的
//   placeholder 文案. 不渲染 panel 名 ("项目管理" / "文档" / "检视" /
//   "聊天" / "状态") 的任何 Text.
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
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
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
