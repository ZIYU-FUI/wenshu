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
        // v0.24 boss验收fix: use String label as ID (UUID auto-generated per re-render
        // → stale selectedTabId after re-render → no tab marked selected).
        let id: String
        let label: String
        let icon: String
        let content: AnyView
    }

    let tabs: [Tab]

    @State private var selectedTabId: String

    var body: some View {
        // v0.24 boss验收fix: simpler structure (VStack only, no ZStack wrapper
        // which was regressing tab bar visibility). .frame(minHeight: 600)
        // forces window contentMinSize.
        VStack(spacing: 0) {
            ZoneContentTabBar(items: tabs.map { ZoneContentTabBar.Item(id: $0.id, label: $0.label, icon: $0.icon) }, selection: selectionBinding)
            // v0.24 boss验收fix (2026-08-24): pass maxWidth/maxHeight explicitly to AnyView
            // so it inherits zone size (not forces zone to grow). Without this,
            // AnyView collapses to its intrinsic size and zone shrinks to ~0.
            Group {
                if let selected = tabs.first(where: { $0.label == selectedTabId }) {
                    selected.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTabId)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
        // Note: do NOT add .frame(minHeight: 600) - it breaks upper band
        // (which is only ~485 PT tall, 600 PT min would push it out of view).
    }

    // v0.24 boss验收fix (2026-08-24): persist tab selection per zone across launches.
// Boss 8/24 feedback: '每个区域的 tab 应该有一个是选中的, 选中状态应该持久化'.
// Implemented via zone-specific UserDefaults key (one per zone).
    private let storageKey: String

    init(zoneSlug: String, tabs: [(label: String, icon: String, content: AnyView)]) {
        let mapped = tabs.map { Tab(id: $0.label, label: $0.label, icon: $0.icon, content: $0.content) }
        self.tabs = mapped
        self.storageKey = "wenshu.tabIndex.\(zoneSlug)"
        // Restore selected tab from UserDefaults (or default to first tab).
        // v0.24 boss验收fix: handle invalid saved value (e.g. tab list changed)
        // by falling back to first tab + resetting stored index.
        let savedIndex = UserDefaults.standard.integer(forKey: self.storageKey)
        let initialLabel: String
        if mapped.indices.contains(savedIndex) {
            initialLabel = mapped[savedIndex].label
        } else {
            initialLabel = mapped.first?.label ?? ""
            // Reset stored index to 0 so future launches start at first tab.
            UserDefaults.standard.set(0, forKey: self.storageKey)
        }
        _selectedTabId = State(initialValue: mapped.first?.label ?? "")
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: { selectedTabId },
            set: { newId in
                selectedTabId = newId
                // Persist current tab index for next launch.
                if let idx = tabs.firstIndex(where: { $0.id == newId }) {
                    UserDefaults.standard.set(idx, forKey: storageKey)
                }
            }
        )
    }
}

/// ZoneContentTabBar: Apple HIG tab bar (跟 ChatZoneTabBar / DynamicZoneTabBar 一致).
/// 顶栏 SF Symbol + 中文 label + .accentColor on selected.
struct ZoneContentTabBar: View {
    struct Item: Identifiable, Equatable {
        let id: String  // stable String (matches Tab.id)
        let label: String
        let icon: String
    }

    let items: [Item]
    @Binding var selection: String

    // v0.24 boss验收fix: selectedItem (Item with matching label) for icon highlighting.
    private var selectedItem: Item? {
        items.first(where: { $0.label == selection })
    }

    var body: some View {
        HStack(spacing: 9) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    // v0.24 boss验收fix: icon only, no title label.
// Boss 8/24 follow-up: 'tab 里标题小字不需要' (was: labels added earlier, now removed).
// Boss feedback: '所有 icon 后面不要加文字, tab 只有 icon'.
// 未选中 .secondary, icon size 18 PT (LayoutTokens.iconSize = 18 PT 占面积).
                // v0.24 boss验收fix (Boss 8/24): 显式 .frame(width: 18, height: 18)
                // 强制 18x18 PT 占面积, 不要只靠 .font(size: 18) (font only sets
                // point size, visual box can grow with implicit .imageScale).
                Image(systemName: item.icon)
                    .font(.system(size: LayoutTokens.iconSize))
                    .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                    .foregroundStyle(item == selectedItem ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        // v0.24 boss验收fix: flush at top of zone (was: padded 6 PT down, made tab
// bar appear mid-zone).
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LayoutTokens.toolbarHeight)
        .background(DesignColor.zoneSurface)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
        .animation(.default, value: selection)
    }
}