// EditorContentStore.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc → v0.05.0 B+ 重 (t_0f6bd6f6)
// Doc-Role: ViewModels/editor
// Responsibilities: 章节正文 store — 加载 + debounced 1s 自动保存 + 失焦强制 flush
// Inputs: 章节 id、新正文
// Outputs: content、isLoading、isDirty、wordCount
// Dependencies: WenshuProjectStore
// Threading: @MainActor
//
// B+ 重 6 维度 (t_0f6bd6f6): ObservableObject → @Observable。 3 个 @Published
// 全部移除。 EditorContentStoreProtocol 已暴露 content/isLoading/isDirty/
// wordCount read-only + load/updateContent/flush 三入口。

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class EditorContentStore {
    private(set) var content: String = ""
    private(set) var isLoading: Bool = false
    private(set) var isDirty: Bool = false

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

// MARK: - B+ 重 协议 extension (沿 DECISION §4.2 #2, t_0f6bd6f6)
extension EditorContentStore: EditorContentStoreProtocol {}
