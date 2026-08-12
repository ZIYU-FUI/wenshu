// LayoutShellRoutes.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆主控 (t_1831ad61)
//
// Doc-Role: Views/Layout/LayoutShellRoutes (NavigationStack destinations)
// Responsibilities: AppRoute enum → View 渲染 (LT-N1-merge + V0-fix-7 modal sheet)
// Inputs: AppRoute + selectedChapterID binding
// Outputs: 5 AppRoute case 对应的 destination View
// Dependencies: ProjectCreateView (modal sheet 兜底), ProjectDetailView
// Threading: @MainActor (跟 LayoutShellView 一致)
//
// 沿 DECISION §4.2 #4: LayoutShellView 拆主控 → destinationView 拆出。
// 5 AppRoute case 渲染 (createProject 走 modal sheet 不 push, chat/characterWorld
// 走 placeholder 兜底, detail 走 ProjectDetailView)。

import SwiftUI

@ViewBuilder
func layoutShellDestination(
    for route: AppRoute,
    selectedChapterID: Binding<String?>
) -> some View {
    switch route {
    case .createProject:
        // V0-fix-7 BUG 1: + 按钮改 modal sheet 后, .createProject
        // 路由不再被 + 按钮消费 (sheet 是真路由)。 保留 enum case
        // 不破坏外部引用, 这里走 placeholder 兜底。
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("请用顶部 + 按钮新建项目")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    case .chat:
        // chat 实装在 bottomLeft ChatPanelView, 这里走 placeholder。
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("请在底部聊天区继续创作")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    case .characterWorld:
        // 留 v0.04.0 长篇工具工单实装, 这里走 placeholder 兜底。
        VStack(spacing: 10) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text("人物世界 — v0.04.0 实现")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    case .detail(let projectId):
        // LT-N1-merge: ProjectDetailView 接 selectedChapterID binding,
        // 章节 tab row click 驱动 selectedChapterID + pop 回 topCenter →
        // EditorView 加载章节。
        ProjectDetailView(
            projectId: projectId,
            selectedChapterID: selectedChapterID
        )
    }
}
