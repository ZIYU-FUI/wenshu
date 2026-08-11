// EditorContentStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 中上编辑器内容 store (沿 LT-N1 ChapterTreeStore / LT-N2 ChatViewModel 范式)。
// 负责指定 chapter 的 content 加载 + debounced 1s 自动保存 + 失焦强制 flush。
//
// 行为契约 (DESIGN-LT-N3.md §4.3 + §7.2):
//   - @Published content / isLoading / isDirty
//   - updateContent(): 取消上一次 save task, 启动 1s debounce, 到点 flush
//   - flush(): 立即 save (切章节 / 关 app / .onDisappear 时调)
//   - 失败: silent-fail 兜底 (沿 v0.01.0 `persist()` 范式)
//
// 跟 ChapterTreeStore 平级 (@MainActor class : ObservableObject),
// 让 unit test 可以在 main actor 上构造 + 调 API。

import Foundation
import SwiftUI

@MainActor
final class EditorContentStore: ObservableObject {
    @Published private(set) var content: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isDirty: Bool = false

    /// 当前活跃 chapter id (LT-01-fix19 stable id, String)。
    /// 切换 chapter 时, EditorView 负责 flush 旧 store + 创建新 store。
    let chapterId: String

    private let store: WenshuProjectStore
    private var saveTask: Task<Void, Never>?

    init(chapterId: String, store: WenshuProjectStore = .shared) {
        self.chapterId = chapterId
        self.store = store
    }

    /// 字数 (顶 toolbar 左上 "N 字")。 实时跟随 content, 不等 debounced save。
    var wordCount: Int {
        content.split { $0.isWhitespace }.count
    }

    /// 加载章节正文。 失败兜底为空字符串 (跟 store.loadChapterContent 一致)。
    func load() async {
        isLoading = true
        defer { isLoading = false }
        content = (try? await store.loadChapterContent(chapterId: chapterId)) ?? ""
        isDirty = false
    }

    /// 用户输入触发。 取消上一次 save task, 启动 1s debounce。
    func updateContent(_ newContent: String) {
        content = newContent
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            await self?.flush()
        }
    }

    /// 立即 flush 当前 content 到 .ws。 切章节 / 关 app / .onDisappear 时调。
    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty else { return }
        do {
            try await store.saveChapterContent(chapterId: chapterId, content: content)
            isDirty = false
        } catch {
            // 沿 v0.01.0 `persist()` 范式: silent-fail 兜底, stderr 记日志。
            FileHandle.standardError.write(Data(
                "EditorContentStore.flush: \(error)\n".utf8
            ))
        }
    }
}
