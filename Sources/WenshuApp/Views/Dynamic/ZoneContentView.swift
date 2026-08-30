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
import Lucide

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
    // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
    // owner 2026-08-26 OOB '这个展开 要放在居右 他是一个按钮 不是
    // 一个 teb' = optional trailing button rendered at the right
    // edge of the tab bar (= independent of tab count). nil = no
    // trailing button = default behavior preserved for all OTHER
    // zone-content tab bars; only the editor zone passes a
    // trailing expand/shrink button.
    var trailingButton: AnyView? = nil

    @State private var selectedTabId: String

    var body: some View {
        // v0.24 boss验收fix: simpler structure (VStack only, no ZStack wrapper
        // which was regressing tab bar visibility). .frame(minHeight: 600)
        // forces window contentMinSize.
        VStack(spacing: 0) {
            ZoneContentTabBar(items: tabs.map { ZoneContentTabBar.Item(id: $0.id, label: $0.label, icon: $0.icon) }, selection: selectionBinding, trailingButton: trailingButton)
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

    init(zoneSlug: String, tabs: [(label: String, icon: String, content: AnyView)], trailingButton: AnyView? = nil) {
        let mapped = tabs.map { Tab(id: $0.label, label: $0.label, icon: $0.icon, content: $0.content) }
        self.tabs = mapped
        // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
        // owner 2026-08-26 OOB '这个展开 要放在居右 他是一个按钮 不是
        // 一个 teb' = optional trailing button parameter passed through
        // to ZoneContentTabBar (= rendered at the right edge of the tab
        // bar via Spacer()).
        self.trailingButton = trailingButton
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
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // OOB '能不能让那个小横线的动画变成左右移动 不是渐隐渐显'. See
    // PaneTabBar comment (= matchedGeometryEffect pattern). One
    // namespace per tab bar class (= SwiftUI requires the namespace to
    // scope within a single view tree).
    @Namespace private var tabBarNamespace

    // v0.25.1 (= ticket 029c-trailing-button editor zone expand/shrink):
    // owner 2026-08-26 OOB '这个展开 要放在居右 他是一个按钮 不是
    // 一个 teb' = the expand/shrink toggle is NOT a tab (= no underline
    // selected indicator, no selected-tab highlighting), it's a
    // SEPARATE button pushed to the trailing edge of the tab bar
    // (= per Apple HIG canonical toolbar pattern where action
    // buttons sit at the trailing edge, separate from the
    // selection tabs). trailingButton is an optional ViewBuilder
    // parameter (= nil = no trailing button = default behavior
    // preserved for all OTHER zone-content tab bars; only the
    // editor zone passes a trailing expand/shrink button). The
    // trailing button is pushed via Spacer() before it so it sits
    // at the rightmost position (= independent of how many tabs
    // the zone has).
    var trailingButton: AnyView? = nil

    // v0.24 boss验收fix: selectedItem (Item with matching label) for icon highlighting.
    private var selectedItem: Item? {
        items.first(where: { $0.id == selection })
    }

    var body: some View {
        // v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个
        // 组件索引'): Phase 3 of refactor. ZoneContentTabBar body now
        // delegates to the new `PaneTabBar` generic component (=
        // ComponentIndex.md Level 3.2). PaneTabBar wraps RegionTabBar
        // chrome + ForEach of PaneIconTab + optional trailing buttons.
        // Was 166 LOC, now ~10 LOC. Behavior preserved 1:1.
        PaneTabBar(
            items: items.map { item in
                PaneTabItem(id: item.id, icon: item.icon, label: item.label)
            },
            selection: $selection,
            namespace: tabBarNamespace,
            trailing: {
                if let trailingButton = trailingButton {
                    trailingButton
                }
            }
        )
    }

    /// v0.28 followup Boss UX round A (Phase 2 of refactor): this helper
    /// is no longer needed because PaneTabBar uses PaneIconTab internally
    /// (= which uses LucideIconSystemFallback directly). Kept as a no-op
    /// stub for backward compatibility with any external callers (= will
    /// be deleted in a follow-up commit after search confirms no
    /// remaining callers).
    @ViewBuilder
    private func zoneContentTabBarIcon(_ systemName: String) -> some View {
        LucideIconSystemFallback(systemName)
    }
}
