// ZoneRenderer.swift · 文枢 (Wenshu) · v0.05.0 B+ 拆 Zone/ (t_1831ad61)
//
// Doc-Role: Zone/ZoneRenderer
// Responsibilities: Zone 入口 View 协议 + 5 Zone 入口 struct
// Inputs: ZoneContext
// Outputs: View (按 PanelID 渲染对应内容)
// Dependencies: ProjectListView / EditorView / InspectorView / ChatPanelView / PlaceholderContent
// Threading: @MainActor
//
// 红线 (沿 DECISION §4.3 + DESIGN-Zone.md §4.2):
//   - 不拆 SPM (单 module)
//   - 不加 ViewModel 关联类型 (ZoneRenderer 只约束 context)
//   - 不实装 bottomRight 内容 (BottomRightZone 仅占位)
//   - 4 zone 内容不动 (TopLeft / TopCenter / TopRight / BottomLeft)

import SwiftUI

@MainActor
protocol ZoneRenderer {
    associatedtype Content: View
    var context: ZoneContext { get }
    @ViewBuilder func render() -> Self.Content
}

struct TopLeftZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View {
        ProjectListView(
            projects: context.projects,
            navPath: context.navPath,
            activeTab: context.activeTab,
            selectedProjectID: context.selectedProjectID
        )
    }
}

struct TopCenterZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View {
        EditorView(
            selectedProjectID: context.selectedProjectID,
            selectedChapterID: context.selectedChapterID
        )
    }
}

struct TopRightZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { InspectorView() }
}

struct BottomLeftZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { ChatPanelView() }
}

struct BottomRightZone: View, ZoneRenderer {
    let context: ZoneContext
    var body: some View { render() }
    func render() -> some View { PlaceholderContent(panel: .bottomRight) }
}
