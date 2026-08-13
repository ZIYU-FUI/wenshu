// PlaceholderContent.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-01 → LT-01-fix6 → v0.05.0 t_a315aa5b
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
//
// v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): 右下 (bottomRight) 顶
// 加 28pt header tab bar (3 ICON) — 沿 OOB "右侧边栏 3 ICON" 真值
// "右下底栏 1: list 2: branch 3: clock" (TODO 修真为 3 ICON 占位)。
// 4 其他 panel (.topLeft/.topCenter/.topRight/.bottomLeft) 不动 header
// bar 范式 — 仅 bottomRight 修真。

import SwiftUI

/// v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): 右下底栏 TODO 占位
/// 修真为 3 ICON tab (沿 OOB "1: list 2: branch 3: clock" 真值)。
/// .list 走 IconLibrary.Action.fileList 单一真值源;
/// .branch / .clock SF Symbol 字面量留待 v0.05.x 加 IconLibrary.Name
/// (沿红线"不加 IconLibrary 新 case")。
enum TodoPanelTab: String, CaseIterable, Identifiable {
    case list = "列表"
    case branch = "分支"
    case clock = "时钟"

    var id: String { rawValue }

    /// SF Symbol 字面量 (TODO tab 3 ICON 占位, 沿 OOB "1: list 2: branch
    /// 3: clock" 真值)。
    var symbolName: String {
        switch self {
        case .list:   return IconLibrary.Action.fileList.symbolName
        case .branch: return "arrow.triangle.branch"  // 待 v0.05.x 加 IconLibrary.Name
        case .clock:  return "clock"                   // 待 v0.05.x 加 IconLibrary.Name
        }
    }
}

struct PlaceholderContent: View {
    let panel: PanelID

    @State private var activeTodoTab: TodoPanelTab = .list

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): 右下底栏
            // TODO 修真为 3 ICON tab bar (28pt header, 沿 TopLeftHeaderBar /
            // ChatPanelView 同范式 — 14pt ICON + 选中态 8pt 底部 indicator)。
            // 沿 OOB "1: list 2: branch 3: clock" 真值。
            // 仅 bottomRight 修真, 其他 4 panel 不动 (沿红线"不实装
            // bottomRight 内容" 修真为 "画 ICON 占位")。
            if panel == .bottomRight {
                HStack(spacing: 2) {
                    ForEach(TodoPanelTab.allCases) { tab in
                        Button {
                            activeTodoTab = tab
                        } label: {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 28, height: 22)
                                .foregroundStyle(activeTodoTab == tab ? Color.accentColor : .secondary)
                                .overlay(alignment: .bottom) {
                                    // 选中态 8pt 底部 indicator — 沿 TopLeftHeaderBar / ChatPanelView 同范式
                                    if activeTodoTab == tab {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(width: 14, height: 2)
                                            .offset(y: 4)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(tab.rawValue)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 28)
                .padding(.horizontal, 12)

                Divider()
            }

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
