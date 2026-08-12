// InspectorViewModelProtocol.swift · 文枢 (Wenshu) · v0.05.0 B+ 重 6 维度 (t_0f6bd6f6)
// Doc-Role: ViewModels/Protocols
// Responsibilities: InspectorViewModel 抽象接口 — 伏笔/修订 2 tab + 选中态协议
// Inputs: tab 枚举、chapter/paragraph id
// Outputs: currentChapterID、currentParagraphID、selectedTab、foreshadows、revisionCandidates、isLoadingForeshadows
// Dependencies: InspectorViewModel (默认实现 .shared)
// Threading: @MainActor

import Foundation

/// B+ 重 (沿 DECISION §4.2 #2): InspectorViewModel 抽象接口。 暴露
/// 选中态协议 `setSelection` + tab 切换 `selectTab` + 列表 read-only。
@MainActor
protocol InspectorViewModelProtocol: AnyObject {
    var currentChapterID: UUID? { get }
    var currentParagraphID: UUID? { get }
    var selectedTab: InspectorViewModel.Tab { get }
    var foreshadows: [ForeshadowRow] { get }
    var revisionCandidates: [RevisionCandidate] { get }
    var isLoadingForeshadows: Bool { get }
    func setSelection(chapterID: UUID?, paragraphID: UUID?)
    func selectTab(_ tab: InspectorViewModel.Tab)
    func loadForeshadows() async
}