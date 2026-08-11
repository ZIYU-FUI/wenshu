// EditorOutlineStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 中上编辑器内部的章节 sidebar store (DESIGN-LT-N3.md §5.4)。
// 跟 topLeft ChapterTreeStore 平级 (都 listChapters), 但 consumer 不同:
//   - ChapterTreeStore → topLeft "章节" tab (LT-N1 已实装, 不动)
//   - EditorOutlineStore → topCenter EditorOutlineView (本卡新增)
//
// 沿 LT-N1 ChapterTreeStore 范式 (@MainActor class : ObservableObject),
// 加 activeChapter 衍生 (顶 toolbar 中上章节名用, selectedChapterID 变化时取)。

import Foundation
import SwiftUI

@MainActor
final class EditorOutlineStore: ObservableObject {
    @Published private(set) var chapters: [ChapterSnapshot] = []
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
