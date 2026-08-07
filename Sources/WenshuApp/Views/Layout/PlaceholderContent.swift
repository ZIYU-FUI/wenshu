// PlaceholderContent.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix5
//
// Empty-state content shown inside each of the 5 panels during LT-01.
// Subsequent LTs replace these with their real content:
//   - LT-02 → 右上 inspector (伏笔 + 修订 tab)
//   - LT-03 → 左上 项目管理 (项目 / 章节 / 设定 / 资料 / 看板 tab)
//   - LT-04 → 下左 聊天区 (聊天 / 时间线 / 关系图 / 大纲 tab)
//
// Design intent (visual contract for 装机 user verification):
// - H1 panel-identification 标题 ("项目管理" / "文档" / "检视" / "聊天" /
//   "状态") + 居中 SF Symbol + 1-line hint of what lands here. 这是
//   LT-01-fix5 优化3 沿用 FCP 范式: panel 自己告诉用户"我是啥", 不靠
//   toolbar title bar.
// - 删了 PanelContainer 的 headerBar 后, 这里必须在 content 里自带 H1,
//   否则用户没法知道哪个 panel 是哪个. 保留 centered SF Symbol + hint
//   给 v0.02.0 期间占位.
// - Avoids looking like a TODO-list or broken UI — looks intentional
//   ("LT-01: layout shell, content lands in LT-N").

import SwiftUI

struct PlaceholderContent: View {
    let panel: PanelID

    var body: some View {
        VStack(spacing: 12) {
            // LT-01-fix5 优化3: H1 self-identity, 替代删掉的 headerBar.
            // 用 .largeTitle 等级显著度让用户在 panel 第一眼就知道"这是
            // 哪个区". 后续 LT 把内容真的填进去后, 各 panel 自己的 root
            // View (InspectorView / ChatView 等) 会用自己的 H1 取代这
            // 个 placeholder 标头.
            Text(h1Title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    /// LT-01-fix5 优化3: 每个 panel 的"我是谁" H1 文案, 匹配 AGENTS §8.1
    /// 拍板的 5 区命名. 用 `panel.title` 的同款字符串保持一致 (避免
    /// 数据漂移). 装机 user 验时这块是 content 顶部最显眼的元素.
    private var h1Title: String {
        switch panel {
        case .topLeft: return "项目管理"
        case .topCenter: return "文档"
        case .topRight: return "检视"
        case .bottomLeft: return "聊天"
        case .bottomRight: return "状态"
        }
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
