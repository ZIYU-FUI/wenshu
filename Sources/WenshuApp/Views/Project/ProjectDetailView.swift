// ProjectDetailView.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 项目详情 destination (沿 LT-N1-merge 真值)。
// 5 tab (项目 / 章节 / 设定 / 资料 / 看板) — 跟 LT-N1 / V0-fix-6/7 拍板一致。
//
// LT-N3 修真 (DESIGN-LT-N3.md §1 步 4 + §5.3):
//   - 加 `@Binding selectedChapterID` binding
//   - 章节 tab (selectedTab == 1) 真接 ChapterTreeView (沿 LT-N1 真值),
//     并在 chapter row click 时驱动 selectedChapterID (→ 中上 EditorView)
//   - 章节 row click 后自动 pop navPath 回到 topCenter (FCP 范式: topCenter
//     是编辑主区, 用户选章节 → 立即进入编辑)
//
// 边界:
//   - 不动 LT-N1 修真后的 Picker.segmented + 5 tab 居中铺满 (P0-1 fix)
//   - 不动 selectedTab @State 默认 0

import SwiftUI

struct ProjectDetailView: View {
    let projectId: UUID
    @Binding var selectedChapterID: String?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("项目").tag(0); Text("章节").tag(1); Text("设定").tag(2); Text("资料").tag(3); Text("看板").tag(4)
            }.pickerStyle(.segmented).padding()
            if selectedTab == 0 {
                Text("项目 \(projectId.uuidString)").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 1 {
                // LT-N3: 章节 tab 真接 ChapterTreeView (沿 LT-N1 真值),
                // 并通过 chapter row click 驱动 selectedChapterID。
                // 点击后立即 pop 回 topCenter (用户选章节 → 立即进入编辑)。
                ChapterTreeView(
                    projectId: projectId,
                    onSelectChapter: { chapterId in
                        selectedChapterID = chapterId
                        dismiss()
                    }
                )
            } else {
                Text("此功能将在后续阶段开放").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.navigationTitle("项目详情")
    }
}
