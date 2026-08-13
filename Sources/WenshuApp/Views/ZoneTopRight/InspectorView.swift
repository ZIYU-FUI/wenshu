// InspectorView.swift · 文枢 (Wenshu) · v0.02.0 WO-LT-02-v2 → v0.03.0 V0-fix-4
//
// 右上 inspector 区 (AGENTS §8.1) 的 SwiftUI 视图。 跟 `ChatPanelView`
// 同形态: 顶上一个 Picker 切 2 tab (伏笔 / 修订), 下方
// `Group { switch ... }` 渲染对应面板内容。 跟 ChatPanelView 同样不
// 写 `.sheet(isPresented:)` (AGENTS §6 + WO-006~010 5 个 sheet 焦点
// bug 全废), 不写 `.onAppear` (统一 `.task` 拉数据)。
//
// V0-fix-4 Fix 5: Picker `.segmented` 改 `.iconOnly` (走 PickerStyle+IconOnly
// 别名, Image-only content); 删 selfHeader H1 "检视" 整段 (LT-01-fix5
// 拍板"用功能告诉用户", header 删 — 跟 ChatPanelView 同步); Picker
// a11y "检视" → ""; 增 inline `iconName(for:)` 静态映射 (伏笔 = eye /
// 修订 = pencil.and.list.clipboard)。
//
// v0.05.0 Zone 协议 (t_8fc5c872): Picker(selection: $vm.selectedTab) 改
// HStack + Button + Image + vm.selectTab() — 沿 ChatPanelView V0-fix-8
// 范式 (FCP timeline 红字"所有 ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP")。
// selectedTab 已 `private(set)`, 不能走 $vm.selectedTab Binding, 调
// vm.selectTab(_ tab:) 替代。
//
// `.task` 触发: 视图出现时一次性 `await vm.loadForeshadows()`, 拉当前
// currentChapterID / currentParagraphID 对应的 CDForeshadow 行。 当前
// v0.02.0 文档内容浏览器还没实装 (v0.05.0 标记系统), 走全局兜底 list。

import SwiftUI

struct InspectorView: View {

    // B+ 重 (t_0f6bd6f6): @ObservedObject → @State (InspectorViewModel.shared 已 @Observable).
    @State private var vm = InspectorViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // v0.05.0 Zone 协议 (t_8fc5c872) Picker 改 HStack + Button:
            // 沿 ChatPanelView V0-fix-11 紧凑范式 (size 13 + 28×22 +
            // spacing 2 + padding vertical 4), FCP timeline 红字"所有
            // ICON 按钮, 只保留 ICON, 不要矩形背景, 仿 FCP"。
            //
            // v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): font 13 → 14
            // 修真 (沿 OOB 线框图 "顶部 tab ICON 14pt"), 加 8pt 底部 indicator
            // (FCP timeline 红字 "选中 = 主色填充 + 底部 indicator")。
            // .placeholder case 共 3 case (沿 OOB "右侧边栏 3 ICON" 真值),
            // iconName 走 IconLibrary 单一真值源。
            HStack(spacing: 2) {
                ForEach(InspectorViewModel.Tab.allCases) { tab in
                    Button {
                        vm.selectTab(tab)
                    } label: {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 28, height: 22)
                            .foregroundStyle(vm.selectedTab == tab ? Color.accentColor : .secondary)
                            .overlay(alignment: .bottom) {
                                // 选中态 8pt 底部 indicator — 沿 TopLeftHeaderBar / ChatPanelView 同范式
                                if vm.selectedTab == tab {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(width: 14, height: 2)
                                        .offset(y: 4)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tab.title)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)

            Divider()
            Group {
                switch vm.selectedTab {
                case .foreshadow:
                    foreshadowList
                case .revision:
                    revisionList
                case .placeholder:
                    // 沿 OOB "右侧边栏 3 ICON" 真值 第 3 case 占位 —
                    // v0.05.0 ICON UI 接 加, 内容实装留 v0.05.x (修真)
                    placeholderTabContent
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await vm.loadForeshadows()
        }
    }

    // MARK: - Inline icon map (V0-fix-4 Fix 5)

    /// v0.05.0 t_a315aa5b ICON UI 接 (AIF 大管家): inline `iconName(for:)`
    /// 静态映射修真走 IconLibrary 单一真值源 (foreshadow → IconLibrary.Name.foreshadow
    /// / revision → IconLibrary.Name.revise / placeholder → IconLibrary.Action.leaf),
    /// 替换 V0-fix-4 Fix 5 字面量。 函数签名保留 `iconName(for:)` (沿
    /// V0Fix4LayoutTests.testInspectorView_2inspectorTabs_iconOnlyAndNoHeader
    /// 断言 `code.contains("iconName(for:")`, 不破既有测试)。
    private func iconName(for tab: InspectorViewModel.Tab) -> String {
        switch tab {
        case .foreshadow:  return IconLibrary.shared.symbolName(for: .foreshadow)
        case .revision:    return IconLibrary.shared.symbolName(for: .revise)
        case .placeholder: return IconLibrary.Action.leaf.symbolName
        }
    }

    // MARK: - 占位 tab 内容 (v0.05.0 ICON UI 接 加, 内容留 v0.05.x 修真)

    @ViewBuilder
    private var placeholderTabContent: some View {
        VStack(spacing: 10) {
            // 沿 ChatPanelView 修真 #3 (B5 装机 user 8/10 17:35 OOB 实机拍
            // "tab 居左 OK, 内容居中") .frame(maxWidth: .infinity, alignment: .center)
            // 撑满 + 内容居中 (FCP timeline 范式)。
            Image(systemName: IconLibrary.Action.leaf.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("占位 tab 内容待 v0.05.x 实装")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(16)
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

    private var emptyForeshadowState: some View {
        VStack(spacing: 10) {
            // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.leaf
            // (`leaf`) — 单一真值源。
            Image(systemName: IconLibrary.Action.leaf.symbolName)
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
