// ProjectKanbanTab.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Tab 5 = 看板. 最小信息: "项目: 章节 N + 设定 M"。
//
// 拍板 (OOB 2026-08-07 拍板 §8.1): 看板从右下移到左上, 是 "本项目所有
// 信息的入口"。 v0.02.0 边界: 不接 CDChapter / CDNote / CDWorldRule
// (CC 不动 .ws schema, AGENTS §5), 只用 mock 计算 (per-project 3 章 +
// 1 设定)。 v0.04.0 长篇工具阶段再接真路径。

import SwiftUI

struct ProjectKanbanTab: View {
    /// 由 ProjectManagementView 传入当前 projects 数量, 用于显示
    /// "项目: N" 汇总
    let projectCount: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 30) {
                summaryTile(
                    title: "项目",
                    value: "\(projectCount)",
                    symbol: "folder"
                )
                summaryTile(
                    title: "章节",
                    value: "\(chapterEstimate)",
                    symbol: ProjectManagementTab.chapters.symbolName
                )
                summaryTile(
                    title: "设定",
                    value: "\(settingsEstimate)",
                    symbol: ProjectManagementTab.settings.symbolName
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: ProjectManagementTab.kanban.symbolName)
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("完整看板 (拖拽卡片 / 排程) v0.04.0 实现")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("看板")
    }

    /// 每项目 mock 3 章 (跟 ChapterTreeTab 对齐)
    private var chapterEstimate: Int {
        max(1, projectCount) * 3
    }

    /// 每项目 mock 1 设定 (跟 ProjectSettingsTab 对齐 — 只有当前选中的
    /// project 显示设定, 所以这里给个保守值)
    private var settingsEstimate: Int {
        min(1, projectCount)
    }

    private func summaryTile(title: String, value: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 90, height: 90)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .overlay(
            Rectangle()
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
}
