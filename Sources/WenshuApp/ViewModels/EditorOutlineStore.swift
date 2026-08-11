// EditorOutlineStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器章节 sidebar 的 @MainActor ObservableObject (DESIGN-LT-N3.md §5.4)。
//
// 范式: 沿 LT-N1 ChapterTreeStore 的 `@MainActor final class ObservableObject`
// 模式, 持有 `chapters: [ChapterSnapshot]` @Published, `load()` 调
// `WenshuProjectStore.listChapters(projectId:)` 真读 (不调 mock)。
//
// 跨项目隔离: `listChapters(projectId:)` 走 actor.projectId-scoped 路径
// (LT-N1 P0-3 修), 自动继承, EditorOutlineStore 不需要再过滤。 ctor
// 必须接 `projectId: UUID` (非可选, 沿 ChapterTreeStore 范式)。
//
// 不修真: ChapterTreeStore (LT-N1 已实装, 在 Views/Project/ChapterTreeView
// 下) 不动, 仅供 ProjectListView 章节 tab 渲染。 EditorOutlineStore 是
// 中上 editor viewer sidebar 专用, consumer 不同, 不冲突。

import Foundation
import SwiftUI

@MainActor
final class EditorOutlineStore: ObservableObject {

    /// 章节列表 (从 actor.listChapters(projectId:) 拉)。 空 = 项目还没章节
    /// (v0.04.0 长篇工具 阶段才接新建章节)。
    @Published private(set) var chapters: [ChapterSnapshot] = []

    /// 项目 UUID (不可变, init 注入)。 沿 ChapterTreeStore 范式, 非可选 —
    /// 强制 caller 走真实 projectId, 避免 review LT-N1 §3.3.1 死路径重演。
    let projectId: UUID

    /// Store 引用 (可注入, 测试用)。 默认 `.shared` 沿 ChatViewModel /
    /// ProjectListStore 范式。
    let store: WenshuProjectStore

    init(projectId: UUID, store: WenshuProjectStore = .shared) {
        self.projectId = projectId
        self.store = store
    }

    /// 拉章节列表。 失败兜底: chapters 保持原值 (沿 ChatViewModel.loadChatHistory
    /// silent-fail 范式, 仅 stderr 记日志)。
    func load() async {
        do {
            chapters = try await store.listChapters(projectId: projectId)
        } catch {
            FileHandle.standardError.write(Data(
                "EditorOutlineStore.load: \(error)\n".utf8
            ))
            // 加载失败: chapters 保持原值, 由 emptyState 兜底
        }
    }
}
