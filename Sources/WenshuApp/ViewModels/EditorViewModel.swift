// EditorViewModel.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc → v0.05.0 B+ 重 (t_0f6bd6f6)
// Doc-Role: ViewModels/editor
// Responsibilities: 编辑器总控 VM — activeChapter + isFullScreen (FCP ⤢ 专注模式)
// Inputs: (toggleFullScreen 入口)
// Outputs: activeChapter、isFullScreen
// Dependencies: EditorOutlineStore
// Threading: @MainActor
//
// B+ 重 6 维度 (t_0f6bd6f6): ObservableObject → @Observable。 2 个 @Published
// 全部移除。 EditorViewModelProtocol 已暴露 activeChapter/isFullScreen read-only
// + toggleFullScreen() 入口 (write 收口到 VM 内部, 沿 t_8fc5c872 §4.2 #4)。

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class EditorViewModel {

    /// 当前编辑章节快照。 留接口是方便 v0.04.0 / v0.05.0 接入"段落切换"
    /// 等功能。 本卡 MVP 只用 outlineStore.chapters.first(where: {...}) 算
    /// chapterTitle, 不真接 publish (DESIGN-LT-N3 §5.2 派生)。
    var activeChapter: ChapterSnapshot?

    /// FCP viewer ⤢ 专注模式 toggle (DESIGN-LT-N3 §5.5.2 底 toolbar)。
    /// true = 隐藏 4 panel, 只显中上 editor; false = 正常 5 区 layout。
    /// private(set) 收口 write access, toggle 通过 toggleFullScreen()。
    private(set) var isFullScreen: Bool = false

    init() {}

    /// toggle ⤢ 全屏 (快捷键不绑, 留 v0.09.0 统一处理)。
    func toggleFullScreen() {
        isFullScreen.toggle()
    }
}

// MARK: - B+ 重 协议 extension (沿 DECISION §4.2 #2, t_0f6bd6f6)
extension EditorViewModel: EditorViewModelProtocol {}
