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
// `.task` 触发: 视图出现时一次性 `await vm.loadForeshadows()`, 拉当前
// currentChapterID / currentParagraphID 对应的 CDForeshadow 行。 当前
// v0.02.0 文档内容浏览器还没实装 (v0.05.0 标记系统), 走全局兜底 list。

import SwiftUI

struct InspectorView: View {

    @ObservedObject private var vm = InspectorViewModel.shared

    var body: some View {
        // V0-fix-11 修真 #4: Picker(.iconOnly) 修真 HStack +
        // ForEach { IconButton } (修真 V0-fix-4 Fix 5 +
        // V0-fix-8 修真 #2 + V0-fix-10.1 修真 #5 衍生). 修真后:
        //   - macOS 系统矩形分段框背景 修真 (Picker(.iconOnly) 仍
        //     修真 SegmentedPickerStyle 修真矩形分段框, 装机 user
        //     8/11 16:20 红字 "纯 ICON 按钮" — 修真 HStack + Button
        //     (.plain) 修真矩形)
        //   - padding(.vertical: 8 → 4) 修真 inspector tab 栏 (FCP
        //     timeline 修真, memi §3.5 layout 修真)
        //   - 修真 Picker a11y "" 修真 (IconButton 自修真 .help(label))
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                ForEach(InspectorViewModel.Tab.allCases) { tab in
                    IconButton(
                        systemImage: IconLibrary.tab(tab),
                        label: tab.title,
                        isActive: vm.selectedTab == tab,
                        isDisabled: false,
                        action: { vm.selectedTab = tab }
                    )
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
                }
            }
            .frame(maxHeight: .infinity)
        }
        .task {
            await vm.loadForeshadows()
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
