// EditorViewModel.swift · 文枢 (Wenshu) · v0.03.0 LT-N3-cc
//
// 编辑器总控 ViewModel (DESIGN-LT-N3.md §5.2):
//
// 拍板 MVP 范围 (DESIGN-LT-N3 §5.2 派生):
//   ✅ activeChapter: 当前编辑章节快照 (从 outlineStore 同步, 留接口)
//   ✅ isFullScreen: 专注模式 toggle (本卡实装, 底 toolbar ⤢ 按钮)
//   ❌ isOutlineVisible: 显示大纲 true/false (留给 v0.04.0 子卡跟"显示菜单"一起做)
//
// 范式: 沿 LT-N1 ChapterTreeStore / LT-N2 ChatViewModel, 走
// `@MainActor final class ObservableObject`。 EditorView 接
// `@StateObject private var viewModel = EditorViewModel()`, 生命周期
// 跟 EditorView 同步 (push 路由下每次新建 EditorView → 新 ViewModel 实例)。
//
// 不修真: 不动 ChatViewModel / LayoutShellView 等已重做 view (派单硬规则)。

import Foundation
import SwiftUI

@MainActor
final class EditorViewModel: ObservableObject {

    /// 当前编辑章节快照。 留接口是方便 v0.04.0 / v0.05.0 接入"段落切换"
    /// 等功能。 本卡 MVP 只用 outlineStore.chapters.first(where: {...}) 算
    /// chapterTitle, 不真接 publish (DESIGN-LT-N3 §5.2 派生)。
    @Published var activeChapter: ChapterSnapshot?

    /// FCP viewer ⤢ 专注模式 toggle (DESIGN-LT-N3 §5.5.2 底 toolbar)。
    /// true = 隐藏 4 panel, 只显中上 editor; false = 正常 5 区 layout。
    /// 本卡 MVP 留 state, 未来 v0.04.0 真接 panel 隐藏 (现在 layout shell
    /// 没动, toggle 只触发 viewModel 状态变化, EditorView 内部根据 isFullScreen
    /// 切换 outline 的显隐)。
    @Published var isFullScreen: Bool = false

    init() {}

    /// toggle ⤢ 全屏 (快捷键不绑, 留 v0.09.0 统一处理)。
    func toggleFullScreen() {
        isFullScreen.toggle()
    }
}
