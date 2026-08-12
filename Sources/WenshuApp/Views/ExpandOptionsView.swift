// ExpandOptionsView.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// 4-category 举一反三 checklist. Lives inside ChatView (above the input
// bar). Visible only when `vm.expandOptions` is non-empty.
//
// Categories (固定顺序展示): 核心冲突 / 主角延伸 / 世界观缺口 / 发展方向.
// Each row toggles selection via tap (checkbox icon flips state).

import SwiftUI

struct ExpandOptionsView: View {
    @ObservedObject var vm: ChatViewModel

    private let categoryOrder: [String] = ["核心冲突", "主角延伸", "世界观缺口", "发展方向"]

    var body: some View {
        if vm.expandOptions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header
                let grouped = Dictionary(grouping: vm.expandOptions, by: { $0.category })
                ForEach(categoryOrder, id: \.self) { category in
                    if let options = grouped[category] {
                        categorySection(category: category, options: options)
                    }
                }
                confirmBar
            }
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.expandOptions
            // (`sparkles`) — 单一真值源。
            Image(systemName: IconLibrary.Action.expandOptions.symbolName)
                .foregroundStyle(.tint)
            Text("AI 举一反三 · 选 2-3 个方向")
                .font(.headline)
            Spacer()
            Text("已选 \(vm.selectedDirectionIDs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }

    private func categorySection(category: String, options: [ExpandOption]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            ForEach(options) { option in
                optionRow(option)
            }
        }
    }

    private func optionRow(_ option: ExpandOption) -> some View {
        let isSelected = vm.selectedDirectionIDs.contains(option.id)
        return HStack(alignment: .top, spacing: 8) {
            // v0.05.0 t_d4e02b80 ICON v2: 抽 IconLibrary.Action.checkbox
            // (`square` 描边) + IconLibrary.Action.checkboxFillSymbol()
            // (`checkmark.square.fill` 选中态) — 单一真值源。
            Image(systemName: isSelected
                ? IconLibrary.Action.checkboxFillSymbol()
                : IconLibrary.Action.checkbox.symbolName)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.body)
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.toggleSelection(option.id)
        }
    }

    private var confirmBar: some View {
        HStack {
            Spacer()
            Button {
                Task { await vm.selectDirections() }
            } label: {
                Label("确认选择", systemImage: "checkmark.circle.fill")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.selectedDirectionIDs.isEmpty || vm.isGenerating)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
