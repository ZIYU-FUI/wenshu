// EditorViewModelProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: EditorViewModel 抽象接口 — 暴露 activeChapter + isFullScreen
// Inputs: (toggle 入口)
// Outputs: activeChapter、isFullScreen 公开字段
// Dependencies: EditorViewModel (默认实现)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): EditorViewModel 抽象接口。 暴露
/// `activeChapter` (LT-N3 §5.2 派生,当前未真用) + `isFullScreen`
/// (底 toolbar ⤢ 按钮) + `toggleFullScreen()`。
@MainActor
protocol EditorViewModelProtocol: AnyObject {
    var activeChapter: ChapterSnapshot? { get }
    var isFullScreen: Bool { get }
    func toggleFullScreen()
}