// ChapterTreeTab.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-03 v2
//
// Tab 2 = 章节. NavigationStack push 章节详情。
//
// v0.02.0 拍板边界 (AGENTS §5/§7 + PM-direct):
// - **不**读 CDChapter entity — .ws schema 是 PM-direct 决策, CC 不动
// - 用 mock 章节列表 (per-project 1-3 章), push 进 ChapterDetailView
//   (本文件定义) 显示章节标题 + 占位正文
// - 装机 user 实机验通过后, 后续 WO 接 CDChapter 时这个 file 是真路径

import SwiftUI

/// Mock 章节行 (替代 CDChapter entity, 等 .ws 接通后替换)
struct ChapterRow: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let index: Int  // 章序 (1-based)

    init(id: UUID = UUID(), title: String, index: Int) {
        self.id = id
        self.title = title
        self.index = index
    }
}

/// 一棵 per-project 的章节树 (mock data)
struct ChapterTree: Identifiable, Hashable, Sendable {
    let id: UUID
    let projectName: String
    let chapters: [ChapterRow]

    init(id: UUID = UUID(), projectName: String, chapters: [ChapterRow]) {
        self.id = id
        self.projectName = projectName
        self.chapters = chapters
    }
}

struct ChapterTreeTab: View {
    let projects: [ProjectSnapshot]
    @Binding var navPath: NavigationPath

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationDestination(for: ChapterTree.self) { tree in
                    ChapterListView(tree: tree, navPath: $navPath)
                        .navigationDestination(for: ChapterRow.self) { row in
                            ChapterDetailView(row: row, projectName: tree.projectName)
                        }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if projects.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: ProjectManagementTab.chapters.symbolName)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("暂无项目")
                    .font(.title3)
                Text("请先在项目 tab 新建一个项目")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("章节")
        } else {
            List {
                ForEach(mockTrees, id: \.id) { tree in
                    NavigationLink(value: tree) {
                        chapterTreeRow(tree)
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("章节")
        }
    }

    /// Mock 章节树生成器 (per-project 给 3 章 stub, 等接 CDChapter 后替换)
    private var mockTrees: [ChapterTree] {
        projects.enumerated().map { (offset, project) in
            let count = min(3, max(1, (project.name.count % 3) + 1))
            let chapters = (1...count).map { idx in
                ChapterRow(title: "第 \(idx) 章", index: idx)
            }
            return ChapterTree(
                projectName: project.name,
                chapters: chapters
            )
        }
    }

    private func chapterTreeRow(_ tree: ChapterTree) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ProjectManagementTab.chapters.symbolName)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(tree.projectName)
                    .font(.headline)
                Text("\(tree.chapters.count) 章")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 中间层: 章节目录

struct ChapterListView: View {
    let tree: ChapterTree
    @Binding var navPath: NavigationPath

    var body: some View {
        List {
            Section("\(tree.projectName) · 共 \(tree.chapters.count) 章") {
                ForEach(tree.chapters) { row in
                    NavigationLink(value: row) {
                        HStack(spacing: 10) {
                            Text("\(row.index).")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .trailing)
                            Text(row.title)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(tree.projectName)
    }
}

// MARK: - 章节详情 (push 终点)

struct ChapterDetailView: View {
    let row: ChapterRow
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: ProjectManagementTab.chapters.symbolName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.title2)
                    Text("\(projectName) · 第 \(row.index) 章")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("章节正文", systemImage: "doc.text")
                    .font(.headline)
                Text("正文编辑器在 v0.05.0 标记系统阶段接入, 当前为占位。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }

            Spacer()
        }
        .padding()
        .navigationTitle(row.title)
    }
}
