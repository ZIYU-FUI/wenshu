// InspectorView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-02-v2 → v0.03.0 V0-fix-2 (Fix H)
//
// 右上 inspector 区 (AGENTS §8.1) 的 SwiftUI 视图。 跟 `ChatPanelView`
// 同形态: 顶上一个 ICON-only Picker 切 2 tab (伏笔 / 修订), 下方
// `Group { switch ... }` 渲染对应面板内容。 跟 ChatPanelView 同样不
// 写 `.sheet(isPresented:)` (AGENTS §6 + WO-006~010 5 个 sheet 焦点
// bug 全废), 不写 `.onAppear` (统一 `.task` 拉数据)。
//
// V0-fix-2 Fix H (装机 user 8/10 15:30 OOB 实机拍): Picker 改 ICON-only
// — `.segmented` → `.iconOnly` (macOS 13 segmented fallback 显 SF Symbol
// 名字, 必须 iconOnly 才真 ICON-only) + Picker a11y "检视" 改 "" (跟
// V0-fix-1 Fix B 同形态) + Picker 块 `Text(tab.title)` 改 `Image(systemName:)
// + .help(tab.title)` + 删 selfHeader H1 "检视" (整段 + body 调用,
// 跟 V0-fix-1 ChatPanelView Fix B 同策略) + 加 `iconName(for:)` inline
// 静态映射 (走 View 内, 不动 InspectorViewModel — 跟 V0-fix-1 不动
// ChatPanelViewModel 同策略)。 伏笔 = eye, 修订 = pencil.and.list.clipboard,
// 跟 V0-fix-1 Fix C 简化风格保持一致。
//
// 布局纪律 (LT-01-fix5 拍板"用功能告诉用户", PanelContainer 已删
// headerBar): panel content 不再顶 H1 self-identity "检视" — 直接 Picker
// chrome-free 进入 InspectorView (V0-fix-2 Fix H selfHeader 已删),
// 装机 user 看 ICON (eye / pencil.and.list.clipboard) 就知道区功能。
// PlaceholderContent 在 PanelContainer 里已经被 InspectorView 替换
// (见 LayoutShellView .panel(_:) switch 的 .topRight 分支)。
//
// Picker / `selectedTab` 协议: Picker 直接绑 `vm.selectedTab` (类型
// 是 `InspectorViewModel.Tab`), tag 走 `.tag(tab)` =
// InspectorViewModel.Tab 这个枚举本身 (CaseIterable + Hashable +
// Identifiable, VM 已经给到位)。 VM 已经在 init 里设默认
// `selectedTab = .foreshadow` — 装机 user 第一次进 inspector 看到的
// 就是伏笔 tab。
//
// `.task` 触发: 视图出现时一次性 `await vm.loadForeshadows()`, 拉当前
// currentChapterID / currentParagraphID 对应的 CDForeshadow 行 (= 历史
// v0.01.0 旧伏笔如果 chapterID/paragraphID 都没值就查 paragraphID ==
// nil 那批)。 当前 v0.02.0 文档内容浏览器还没实装 (v0.05.0 标记系
// 统), `currentChapterID / currentParagraphID` 默认 nil → 走全局兜
// 底 list, 显示全部旧伏笔 — 装机 user 上手 inspector 第一眼就看到
// 已有些伏笔, 而不是空 panel。
//
// 严禁: `.sheet(isPresented:)` / `.onAppear` / `NavigationStack push`
// 在 inspector 里走 detail (这里只有 tab 切换 + ForEach 静态渲染,
// 不需要导航 — v0.05.0 段落选中也不走 push, 走 setSelection 设置
// chapter/paragraph ID → 自动 reloadForgeshadows)。

import SwiftUI

struct InspectorView: View {

    /// 跟 `LayoutShellViewModel.shared` 同策略 — 文枢 inspector 是
    /// 5 区中**唯一**的 inspector (右上), 同进程只需一个 instance,
    /// 直接 `InspectorViewModel.shared` — 严防 inspector 多 instance
    /// race (LT-01-fix3 已踩过, 抄同款拍板)。
    @ObservedObject private var vm = InspectorViewModel.shared

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            // V0-fix-2 Fix H: Picker 改 ICON-only (.iconOnly + Image
            // + .help() 兜中文) + Picker a11y 改 "" (跟 ChatPanelView
            // Fix G §1.3 同形态). iconName(for:) 走 View 内 inline
            // 静态映射, 不动 InspectorViewModel (跟 V0-fix-1 不动
            // ChatPanelViewModel 同策略).
            Picker("", selection: $vm.selectedTab) {
                ForEach(InspectorViewModel.Tab.allCases) { tab in
                    Image(systemName: iconName(for: tab))
                        .tag(tab)
                        .help(tab.title)
                        .disabled(false)
                }
            }
            .pickerStyle(.iconOnly)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            Group {
                switch vm.selectedTab {
                case .foreshadow:
                    foreshadowList
                case .revision:
                    revisionList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            // v0.02.0 inspector 第一次出现时拉一次 — 跟 LT-04 ChatPanelView
            // 的 `.task` 同形态, 不用 `.onAppear` (后者在 SwiftUI 视图
            // 复用 / 折叠展开切时会重触发, 跟本卡的"一次性拉历史伏笔"
            // 语义不符)。 currentChapterID / currentParagraphID 默认
            // nil → store 走 paragraphID == nil 兜底 → 显示全部
            // v0.01.0 旧伏笔。
            await vm.loadForeshadows()
        }
    }

    // MARK: - V0-fix-2 Fix H: iconName(for:) inline 静态映射

    /// Inspector 2 tab 的 SF Symbol 映射 — 走 View 内 inline, 不动
    /// InspectorViewModel (跟 V0-fix-1 不动 ChatPanelViewModel 同策略).
    /// 伏笔 = eye (表"看穿 / 注视"), 修订 = pencil.and.list.clipboard
    /// (表"用铅笔 + 列表改写"). 跟 V0-fix-1 Fix C 简化风格保持一致.
    private func iconName(for tab: InspectorViewModel.Tab) -> String {
        switch tab {
        case .foreshadow: return "eye"
        case .revision: return "pencil.and.list.clipboard"
        }
    }

    // MARK: - 伏笔 tab

    @ViewBuilder
    private var foreshadowList: some View {
        if vm.foreshadows.isEmpty {
            emptyForeshadowState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.foreshadows) { row in
                        ForeshadowRowView(row: row)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    /// 兜底空态 — 当前 v0.02.0 装机 user 还没进段落选中的情况下走
    /// 这里, 但只要 .ws 文件里有 v0.01.0 历史伏笔 (没 chapterID /
    /// paragraphID 字段), store 会查出 paragraphID == nil 的所有行,
    /// 装机 user 能立刻看到 — 不会真走到这条空态。 给一句兜底文案,
    /// 不让 panel 完全空白 (没内容会让装机 user 误以为 inspector
    /// 没工作)。
    private var emptyForeshadowState: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("暂无伏笔")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("去文档选中段落联动")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    // MARK: - 修订 tab

    @ViewBuilder
    private var revisionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(vm.revisionCandidates) { candidate in
                    RevisionRowView(candidate: candidate)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Row views

/// 单条伏笔行的渲染。 hook + status + 是否已回收。 v0.02.0 不点
/// 击行为 (修订/编辑留 v0.05.0 段落选中联动)。
private struct ForeshadowRowView: View {
    let row: ForeshadowRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.hook)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Spacer(minLength: 8)
                if row.isResolved {
                    Text("已回收")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 0.5)
                        )
                }
            }
            HStack(spacing: 6) {
                if let status = row.status, !status.isEmpty {
                    Text("状态: \(status)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(plantedAtString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var plantedAtString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return "种于 \(formatter.string(from: row.plantedAt))"
    }
}

/// 单条修订候选的渲染 — `InspectorViewModel.mockRevisionCandidates`
/// (3 条 hardcoded) 在这里走静态渲染。 真接 LLM 留 v0.04.0 (per
/// brief §2.2)。
private struct RevisionRowView: View {
    let candidate: RevisionCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(candidate.revisedContent)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                Spacer(minLength: 8)
                if candidate.accepted {
                    Text("已采用")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("候选")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 0.5)
                        )
                }
            }
            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        )
    }
}
