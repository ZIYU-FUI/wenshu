// InspectorViewModel.swift · 文枢 (Wenshu) · v0.02.0 LT-02 v2
//
// 右侧 inspector (右上区, AGENTS §8.1) 的 view model。LT-02 v2 拍板
// 真值 (PM-LT-02-v2-brief.md §1):
//
//   - 伏笔 tab 真读 CDForeshadow entity (按 chapter / paragraph ID 过滤,
//     用 8/10 新增的可空关联字段)
//   - 修订 tab 显示 3 条 hardcoded mock CDRevision,
//     **真 LLM 生成留在 v0.04.0**
//
// 跟 `LayoutShellViewModel.shared` 同样的"共享 single instance"策略:
// 文枢 inspector 是 5 区中**唯一**的 inspector (右上), 没有任何
// 同 panel 多实例的需求 — 直接 `static let shared`,避免 macOS menu /
// View 双场景引用不同 instance 的 race (LT-01-fix3 已踩过这个坑)。
//
// 选中态协议 (PM-direct §"currentChapterID 怎么从 ProjectListView 传"):
// LT-02 v2 阶段, 文档内容浏览器还没实装 (v0.05.0 标记系统 + 段落选中),
// `currentChapterID / currentParagraphID` 默认都是 nil — View 看到 nil
// 就显示"还没选中段落"的兜底文案 (并且把 paragraphID=nil 的历史伏笔
// 显示出来,保留 v0.01.0 数据可读)。v0.05.0 接段落选中时,DocumentView
// 在 onChange 里调 `InspectorViewModel.shared.setSelection(...)`,
// VM 自动 `loadForeshadows()`。这是 LT-02 v2 唯一对外接口协议。
//
// 修订 mock = 3 条 hardcoded struct,不接 store,不调 LLM。v0.04.0 真生成
// 才会替换为 `CDRevision` 读 + LLM 改写流水线。
//
// Threading: @MainActor — InspectorView 把 `vm` 当 @ObservedObject,
// store 跨 actor 走 `await store.xxx(...)`, 不会让 .ws 读阻塞 layout
// paint。

import Foundation
import SwiftUI

@MainActor
final class InspectorViewModel: ObservableObject {

    /// 共享 singleton — 跟 `LayoutShellViewModel.shared` 同样的拍板。 若有
    /// 业务场景需要在同一进程内多个 InspectorView (例如未来 inspector 模板
    /// 化,多个 inspector 视窗), 改成 init 注入并拿掉 static。
    static let shared = InspectorViewModel()

    // MARK: - Inspector tab 标识

    enum Tab: String, CaseIterable, Hashable, Identifiable {
        case foreshadow    // 伏笔
        case revision      // 修订

        var id: String { rawValue }

        /// 显示用标题 (macOS UI 中文, 跟 AGENTS §8.1 中文风格一致)。
        var title: String {
            switch self {
            case .foreshadow: return "伏笔"
            case .revision: return "修订"
            }
        }
    }

    // MARK: - Published state

    /// 装机 user 当前选中的 chapter。 v0.05.0 接 DocumentView 段落选中
    /// 时会 setter 入,LayoutShellView/InspectorView 用 onChange 监听。
    /// nil = 没有选中 = 显示"全局兜底"伏笔列表(paragraphID=nil 旧数据)。
    @Published private(set) var currentChapterID: UUID? = nil

    /// 装机 user 当前选中的 paragraph。 paragraph 优先级 > chapter
    /// (per PM-LT-02-v2-brief.md §2.3)。
    @Published private(set) var currentParagraphID: UUID? = nil

    /// 当前选中的 tab。 默认 = 伏笔,跟 AGENTS §8.1 inspector 拍板
    /// "默认显示 2 tab (伏笔 + 修订)" 一致 (两者都显示,初始焦点伏笔)。
    ///
    /// v0.05.0 Zone 协议 (t_8fc5c872) ViewModel 收口 (沿 DECISION §4.2 #4 + DESIGN-Zone.md §7.3):
    /// 加 `private(set)`, write access 收口到 VM 内部 method (selectTab(_ tab:))。
    /// InspectorView 调 vm.selectTab(.revision) 而非 vm.selectedTab = .revision
    /// (Picker 改 HStack + 4 Button onAction)。
    @Published private(set) var selectedTab: Tab = .foreshadow

    /// 当前伏笔 tab 渲染的列表 — 跟 `loadForeshadows()` 写入。InspectorView
    /// ForEach 直接绑这个。
    @Published private(set) var foreshadows: [ForeshadowRow] = []

    /// 当前修订 tab 显示的 mock CDRevision。 3 条 hardcoded,不接 store,
    /// 不调 LLM。v0.04.0 真生成时改用 `CDRevision` 查 + LLM pipeline。
    @Published private(set) var revisionCandidates: [RevisionCandidate] = []

    /// `loadForeshadows` 是否在飞。用来 inspector UI 上显示"加载中…",
    /// 但 v0.02.0 mock 阶段 in-memory store 一般 < 5ms,可以忽略。
    /// 留 `false` 默认值避免每次 View 出现 spinner 抖动。
    @Published private(set) var isLoadingForeshadows: Bool = false

    // MARK: - Init

    init(revisionCandidates: [RevisionCandidate] = InspectorViewModel.mock3) {
        // 修订 mock = 3 条硬编码。 允许测试注入,默认走 mock3。 mock3 在
        // 下方 extension 里 (= InspectorViewModel.mock3) — 不是在
        // RevisionCandidate 上,不要写 RevisionCandidate.mock3 (编译错)。
        self.revisionCandidates = revisionCandidates
    }

    // MARK: - Tab 切换 (v0.05.0 Zone 协议 收口, 沿 t_8fc5c872)

    /// v0.05.0 Zone 协议 (t_8fc5c872) ViewModel 收口: write access 收口
    /// 到 VM 内部 method, InspectorView 调 vm.selectTab(.revision) 而非
    /// vm.selectedTab = .revision (Picker 改 HStack + 4 Button onAction)。
    /// selectedTab 已 `private(set)`, 外部无法直接赋值。
    func selectTab(_ tab: Tab) {
        selectedTab = tab
    }

    // MARK: - 选中态协议

    /// 装机 user/其他面板 → inspector 方向唯一入口。 文档内容浏览器
    /// (v0.05.0) 接段落选中时,在这 setter 里:
    ///   1. 更新 published `currentChapterID / currentParagraphID`
    ///   2. 异步调 `loadForeshadows()` 拉新过滤结果
    ///
    /// 任一参数传 nil = "该级别还没选中" (= 兜底:chapter 选了但 paragraph 还没,
    /// 或都没选)。 这跟 brief §2.3 "paragraph 优先 > chapter" 一致:
    /// paragraph 非 nil → 走 paragraph 过滤;否则 chapter 非 nil → 走 chapter;
    /// 否则 paragraphID == nil 的旧伏笔。
    func setSelection(chapterID: UUID?, paragraphID: UUID?) {
        let chapterChanged = currentChapterID != chapterID
        let paragraphChanged = currentParagraphID != paragraphID
        guard chapterChanged || paragraphChanged else { return }
        currentChapterID = chapterID
        currentParagraphID = paragraphID
        Task { [weak self] in
            await self?.loadForeshadows()
        }
    }

    /// 兜底:既没当前 chapter 也没当前 paragraph (装机 user 没进文档,
    /// 或文档还没段落)。 LT-02 v2 inspector 伏笔 tab 在兜底模式下显示
    /// 全部 `paragraphID == nil` 的伏笔 (= 历史 v0.01.0 创建时没标
    /// paragraph 的旧行)。 这保住了 v0.01.0 fixture 可读,也让装机 user
    /// 上手 inspector 第一眼就看到"已经有些伏笔",而不是一个空 panel。
    func loadForeshadows() async {
        let paragraphID = currentParagraphID
        let chapterID = currentChapterID
        let store = WenshuStoreActor.shared
        isLoadingForeshadows = true
        defer { isLoadingForeshadows = false }
        do {
            // paragraph 优先级 > chapter (per brief §2.3)。
            let rows: [ForeshadowRow]
            if paragraphID != nil {
                rows = try await store.listForeshadows(forParagraph: paragraphID)
            } else if chapterID != nil {
                rows = try await store.listForeshadows(forChapter: chapterID)
            } else {
                // 全局兜底: paragraphID == nil 的伏笔 = v0.01.0 旧数据
                rows = try await store.listForeshadows(forParagraph: nil)
            }
            foreshadows = rows
        } catch {
            // 单 row 取值失败都不能炸 inspector — 留空 list 让 UI 显示空态。
            FileHandle.standardError.write(Data(
                "InspectorViewModel.loadForeshadows: \(error)\n".utf8
            ))
            foreshadows = []
        }
    }

    // MARK: - 修订 mock

    /// 当前伏笔 tab 真读, 但**真 LLM 改写**留 v0.04.0。 LT-02 v2 阶段
    /// 全部都是 hardcoded — 这样装机 user 能立刻看到 3 条候选在 inspector
    /// 修订 tab 里, 不需要 LLM key / Provider。
    static let mockRevisionCandidates: [RevisionCandidate] = [
        RevisionCandidate(
            id: UUID(),
            originalChapterID: UUID(),
            revisedContent: "雨落在屋顶, 烟囱里冒出第一缕烟——文枢镇今天醒得比往常更早。",
            reason: "开篇节奏: 让时间 / 空间锚点前置, 帮读者快速进入场景, 避免从人物动作切入的缓起。",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            accepted: false
        ),
        RevisionCandidate(
            id: UUID(),
            originalChapterID: UUID(),
            revisedContent: "沈白没说话, 只是把窗推开一条缝, 让七月末的雨气溜进店里。",
            reason: "心理-动作桥: 用身体动作替代「沈白心想」的内心独白, 跟文枢镇 npc 的克制人设对齐。",
            createdAt: Date(timeIntervalSince1970: 1_700_001_800),
            accepted: false
        ),
        RevisionCandidate(
            id: UUID(),
            originalChapterID: UUID(),
            revisedContent: "文枢镇开店的人都记得那一天——不是因为雨大, 是因为沈白没接伞。",
            reason: "伏笔显化: 把「沈白不接伞」挑到第一句, 提前暴露给读者后续 trust / betray 的张力; 跟 v0.05.0 伏笔系统约定对齐。",
            createdAt: Date(timeIntervalSince1970: 1_700_003_600),
            accepted: false
        )
    ]
}

// MARK: - 修订候选 mock

/// Inspector 修订 tab 渲染一条候选用的不可变 view-model。DIP 看
/// `CDRevision` schema (5 列: originalChapterID / revisedContent /
/// reason / createdAt / accepted) — 所有字段都是 hardcoded mock,不接
/// store,不调 LLM。 v0.04.0 真生成会被换成 `CDRevision` 查 → 真修订。
/// 跟 `ForeshadowRow` 同样是 plain Sendable,跨 actor 边界安全。
struct RevisionCandidate: Identifiable, Sendable, Equatable {
    let id: UUID
    let originalChapterID: UUID
    let revisedContent: String
    let reason: String
    let createdAt: Date
    let accepted: Bool

    init(
        id: UUID = UUID(),
        originalChapterID: UUID,
        revisedContent: String,
        reason: String,
        createdAt: Date,
        accepted: Bool
    ) {
        self.id = id
        self.originalChapterID = originalChapterID
        self.revisedContent = revisedContent
        self.reason = reason
        self.createdAt = createdAt
        self.accepted = accepted
    }
}

extension InspectorViewModel {
    /// 3 条 hardcoded mock CDRevision。 必须严格 3 条 — WenshuInspectorRevisionMockTests
    /// 测的就是这个数。 不接 store,完全脱 LLM 决定 — 即使 `FeatureFlag.useRealLLM == true`
    /// 这里也走 mock (v0.04.0 真生成时改)。
    static let mock3: [RevisionCandidate] = mockRevisionCandidates
}
