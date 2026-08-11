// EditorContentStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器章节正文的 @MainActor ObservableObject (DESIGN-LT-N3.md §4.3)。
//
// 核心职责:
//   - 持 `@Published var content: String` (章节正文)
//   - `load()` 调 `WenshuProjectStore.loadChapterContent(...)` 从 .ws 读
//   - `updateContent(_:)` 用户输入触发, debounced 1s 后自动存
//   - `flush()` 取消当前 saveTask, 立即落 .ws (切章节 / 关 app 时调)
//
// debounce 范式: `Task.sleep(for: .seconds(1))`, 配合 `saveTask?.cancel()`
// 实现"用户连续输入 → 1s 内不存 → 停手 1s 后存"。 沿 LT-N1 / LT-N2 派单
// 硬规则"debounced 1s 自动存" + DESIGN-LT-N3 §2.2.3 TextEditor 派生。
//
// 范式: `@MainActor final class ObservableObject` (沿 ChapterTreeStore /
// EditorOutlineStore 平级), 可被 unit test (DESIGN-LT-N3 §9.3 提的 4 个
// EditorContentStore tests 都可在本类直接验)。
//
// storyboard: 不动 WenshuStoreActor 已有 signature, 不动 CoreData entity
// 字段, 跟 WenshuProjectStore+LTN3.swift 配套。

import Foundation
import SwiftUI

@MainActor
final class EditorContentStore: ObservableObject {

    /// 章节正文 (`@Published` 让 TextEditor binding 推数据)。
    @Published private(set) var content: String = ""

    /// 加载中标记 (UI 显示 spinner / disable input)。
    @Published private(set) var isLoading: Bool = false

    /// 脏标记 (用户改过、还没 flush 落 .ws)。 顶 toolbar 显示 dot 指示器
    /// (DESIGN-LT-N3 §7.2 dirty 状态)。
    @Published private(set) var isDirty: Bool = false

    /// 实时字数 (debounced 跟 content 同步, 顶 toolbar 左上显示)。
    @Published private(set) var wordCount: Int = 0

    /// 项目 UUID (不可变, init 注入)。 沿 EditorOutlineStore 范式。
    let projectId: UUID

    /// 章节 ID (NSManagedObjectID.uriRepresentation().absoluteString, 沿
    /// LT-N1 P0-4 拍板真值, 跨多次 fetch 不变)。
    let chapterId: String

    /// 注入 store (测试可换 in-memory 容器)。 默认 `.shared`。
    private let store: WenshuProjectStore

    /// debounced save Task (用户连续输入时反复 cancel + restart)。
    private var saveTask: Task<Void, Never>?

    init(projectId: UUID, chapterId: String, store: WenshuProjectStore = .shared) {
        self.projectId = projectId
        self.chapterId = chapterId
        self.store = store
    }

    /// 加载章节正文。 失败兜底: content 保持空 (跟 loadChapterContent
    /// 返回 "" 对齐, 渲染空编辑器)。
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let saved = try await store.loadChapterContent(projectId: projectId, chapterId: chapterId)
            content = saved
            wordCount = Self.computeWordCount(saved)
            isDirty = false
        } catch {
            FileHandle.standardError.write(Data(
                "EditorContentStore.load: \(error)\n".utf8
            ))
            // 加载失败: content 保持空, 由 TextEditor 兜底
        }
    }

    /// 用户输入触发 (debounced 1s 自动存)。 反复 cancel + restart last
    /// saveTask 实现"停手 1s 后存"。
    func updateContent(_ newContent: String) {
        content = newContent
        wordCount = Self.computeWordCount(newContent)
        isDirty = true
        saveTask?.cancel()
        let projectId = self.projectId
        let chapterId = self.chapterId
        let store = self.store
        let toSave = newContent
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            await Self.performSave(projectId: projectId, chapterId: chapterId, content: toSave, store: store, self: self)
        }
    }

    /// 立即 flush (切章节 / 关 app 时调 — DESIGN-LT-N3 §4.3 Key points)。
    /// 取消 pending saveTask, 立即 save。
    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        let toSave = content
        do {
            try await store.saveChapterContent(projectId: projectId, chapterId: chapterId, content: toSave)
            isDirty = false
        } catch {
            FileHandle.standardError.write(Data(
                "EditorContentStore.flush: \(error)\n".utf8
            ))
            // flush 失败: isDirty 仍 true, 顶 toolbar 红字 (DESIGN-LT-N3 §7.2 error 状态)
        }
    }

    // MARK: - Helpers

    /// 静态派发 save (避免 capture self 进 Task 闭包, 减少 Swift 6 strict
    /// concurrency 警告)。
    private static func performSave(
        projectId: UUID,
        chapterId: String,
        content: String,
        store: WenshuProjectStore,
        self: EditorContentStore?
    ) async {
        do {
            try await store.saveChapterContent(projectId: projectId, chapterId: chapterId, content: content)
            self?.isDirty = false
        } catch {
            FileHandle.standardError.write(Data(
                "EditorContentStore.save: \(error)\n".utf8
            ))
        }
    }

    /// 字数计算 (沿 DESIGN-LT-N3 §6.2 派生: 标准 word count = split
    /// whitespace, 跟 WenshuProjectStore.listChapters 字数计算逻辑一致)。
    nonisolated static func computeWordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace }.count
    }
}
