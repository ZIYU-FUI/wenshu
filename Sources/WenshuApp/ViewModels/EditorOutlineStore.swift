// EditorOutlineStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc → v0.05.0 B+ 重 (t_0f6bd6f6)
// Doc-Role: ViewModels/editor
// Responsibilities: 中上编辑器章节 sidebar store — 项目下章节列表 + 顶 toolbar 章节名查
// Inputs: 项目 id
// Outputs: chapters、[projectId]
// Dependencies: WenshuProjectStore
// Threading: @MainActor
//
// B+ 重 6 维度 (t_0f6bd6f6): ObservableObject → @Observable。 @Published
// chapters 移除。 EditorOutlineStoreProtocol 已暴露 chapters/projectId
// read-only + load + chapter(withId:)。

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class EditorOutlineStore {
    private(set) var chapters: [ChapterSnapshot] = []
    let projectId: UUID
    private let store: WenshuProjectStore

    init(projectId: UUID, store: WenshuProjectStore = .shared) {
        self.projectId = projectId
        self.store = store
    }

    /// 加载项目下所有章节。 失败兜底 = [] (跟 listChapters 失败语义一致)。
    func load() async {
        chapters = (try? await store.listChapters(projectId: projectId)) ?? []
    }

    /// 顶 toolbar 中上章节名 ("第 N 章 · 标题")。 没选中 → nil。
    /// 通过 `selectedChapterID` (String) 找当前 chapter row。
    func chapter(withId id: String?) -> ChapterSnapshot? {
        guard let id else { return nil }
        return chapters.first { $0.id == id }
    }
}

// MARK: - B+ 重 协议 extension (沿 DECISION §4.2 #2, t_0f6bd6f6)
extension EditorOutlineStore: EditorOutlineStoreProtocol {}
