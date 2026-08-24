//
//  ZoneContentView.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 拍 (out-of-band): 所有区域都 一样, 可以叫 tab 视图.
//  不可以加顶栏, 只保留一层顶栏, 可以多 tab.
//
//  Pattern (跟 ChatZoneView 的 ChatZoneTabBar + DynamicZoneView 的 DynamicZoneTabBar 统一):
//  - 1 layer per zone (no ZoneTopToolbar / ZoneBottomToolbar outer shells)
//  - 多 internal tabs (Apple HIG Button(.plain) + .accentColor on selected)
//  - 中文 tab labels (per AGENTS.md §12 中文为主)
//
//  Applied to 4 zones:
//  - projectSidebar: 大纲 / 收藏 / 模板
//  - projectPreview: 预览 / 图 / 搜索
//  - editor: 编辑 / 大纲 / 反链
//  - specializedTools: 画布 / 数据库 / 词数
//
//  Other 2 zones (chat, dynamic) have their own specialized tab bars:
//  - ChatZoneView: ChatZoneTabBar (chat / search / settings)
//  - DynamicZoneView: DynamicZoneTabBar (进度 / 待办 / 搜索)
//

import SwiftUI

/// Generic tab content view: 1-layer pattern with multiple internal tabs.
/// Used by the 4 "general" zones (projectSidebar / projectPreview / editor / specializedTools).
struct ZoneContentView: View {
    struct Tab: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let content: AnyView
    }

    let tabs: [Tab]

    var body: some View {
        VStack(spacing: 0) {
            ZoneContentTabBar(items: tabs.map { ZoneContentTabBar.Item(id: $0.id, label: $0.label, icon: $0.icon) }, selection: selectionBinding)
            Group {
                if let selected = tabs.first(where: { $0.id == selectedTabId }) {
                    selected.content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTabId)
        }
    }

    @State private var selectedTabId: UUID

    init(tabs: [(label: String, icon: String, content: AnyView)]) {
        let mapped = tabs.map { Tab(label: $0.label, icon: $0.icon, content: $0.content) }
        self.tabs = mapped
        _selectedTabId = State(initialValue: mapped.first?.id ?? UUID())
    }

    private var selectionBinding: Binding<UUID> {
        Binding(
            get: { selectedTabId },
            set: { selectedTabId = $0 }
        )
    }
}

/// ZoneContentTabBar: Apple HIG tab bar (跟 ChatZoneTabBar / DynamicZoneTabBar 一致).
/// 顶栏 SF Symbol + 中文 label + .accentColor on selected.
struct ZoneContentTabBar: View {
    struct Item: Identifiable {
        let id: UUID
        let label: String
        let icon: String
    }

    let items: [Item]
    @Binding var selection: UUID

    var body: some View {
        HStack(spacing: 9) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                        Text(item.label)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(item.id == selection ? Color.accentColor : DesignColor.accentBlue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.leading, 18)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LayoutTokens.toolbarHeight)
        .background(DesignColor.zoneSurface)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
        .animation(.default, value: selection)
    }
}