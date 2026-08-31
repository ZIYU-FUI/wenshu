//
//  DynamicZoneView.swift · Wenshu · v0.24 boss验收
//
//  Boss 2026-08-24 拍: dynamic zone 应该是 tab 模式 (跟 chat zone 的 ChatZoneTabBar 一致),
//  不应该是 sheet 模式 (sheet 一次只能看一个, 不能 tab 切换).
//
//  Tab order (per boss 8/24 explicit feedback):
//  - tab1: 任务 (Todo) — TodoListView (h07)
//  - tab2: 进度 (Sub-agent progress) — SubAgentProgressView
//  - tab3: 搜索 (Search) — SearchPanel (o06)
//
//  Per AGENTS.md §12 中文为主, tab labels 中文.
//

import SwiftUI
import Lucide

/// DynamicZoneView: 动态区 body. 3 tabs (任务 / 进度 / 搜索) + Apple HIG TabBar pattern
/// (跟 ChatZoneTabBar 范式一致: 顶栏 SF Symbol + .accentColor 高亮选中态).
struct DynamicZoneView: View {
    enum DynamicTab: String, CaseIterable, Identifiable {
        // v0.24 boss验收fix (2026-08-24 OOB): Boss 拍 '这里不是看板吗, 这里怎么变成
        // 会话记录了' = dynamic zone 应该 be 看板 (kanban), not 子代理进度 (debug).
        // Per boss 8/24 拍 'dynamic zone 改 2 tab' = 看板 + 待办 only.
        // Hide: 子代理进度 (debug feature) + 搜索 (per 5c9ef2ee6 + chat zone pattern).
        case kanban = "看板"
        case todo = "待办"
        var id: String { rawValue }
        var label: String { rawValue }
        var icon: String {
            switch self {
            // v0.25.1 (= ticket 022 dynamic zone tab icons): owner
            // 2026-08-26 OOB 右下角区 两个 teb 切换: teb1 -> layout-grid, teb2 -> layout-list
            // layout-grid teb2 换成 layout-list' = SF rectangle.split.3x1
            // → Lucide layout-grid (= 4-cell grid icon, 看板 board
            // visual metaphor). SF checklist → Lucide layout-list
            // (= row-based list icon, 待办 list visual metaphor).
            case .kanban: return "layout-grid"
            case .todo: return "layout-list"
            }
        }
    }

    // v0.24 boss验收fix: persist tab selection across launches.
    @AppStorage("wenshu.tabIndex.aiDynamic") private var selectedTabRaw: String = "看板"

    private var selectedTab: DynamicTab {
        get { DynamicTab(rawValue: selectedTabRaw) ?? .kanban }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }

    var body: some View {
        // v0.30 boss 8/31 OOB: alignment: .leading so the top tab bar
        // (= DynamicZoneTabBar) is left-aligned instead of default
        // center-aligned (= SwiftUI VStack defaults to .center). Boss
        // spec: "动态 teb 图标改成居左" = the dynamic zone tabs should
        // sit at the left edge (= 18 PT padding from pane left) like
        // every other zone's top bar.
        VStack(alignment: .leading, spacing: 0) {
            DynamicZoneTabBar(selectedTab: Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            ))
            Group {
                switch selectedTab {
                case .kanban:
                    KanbanView()
                case .todo:
                    TodoListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // prevent window shrink
        // v0.28 followup Boss UX round 31 (Boss 2026-08-29 OOB '素材预览区,
// 动态区, 这个区的液态玻璃效果和其他区不一样'): .ultraThinMaterial
// replaced with RegionContentBackground (= single source of truth
// for per-pane content backgrounds = .regularMaterial = standard
// Liquid Glass tint = matches other panes including Preview).
        .regionContentBackground()
    }
}

/// DynamicZoneTabBar: 顶栏 3 SF Symbol tab + 选中态 .accentColor (跟 ChatZoneTabBar 范式一致)
struct DynamicZoneTabBar: View {
    @Binding var selectedTab: DynamicZoneView.DynamicTab
    // v0.25.1 (= ticket 013 underline slide animation): matchedGeometry
    // namespace for the shared underline (= PaneTabBar handles the
    // .matchedGeometryEffect internally). One namespace per tab bar
    // class (= SwiftUI requires the namespace to scope within a single
    // view tree).
    @Namespace private var tabBarNamespace

    var body: some View {
        // v0.28 followup Boss UX round A (Phase 3 of refactor): DynamicZoneTabBar
        // body now delegates to `PaneTabBar` generic component (= ComponentIndex.md
        // Level 3.2). Was 135 LOC, now ~10 LOC. Behavior preserved 1:1.
        PaneTabBar(
            items: DynamicZoneView.DynamicTab.allCases.map { tab in
                PaneTabItem(id: tab.id, icon: tab.icon, label: tab.label)
            },
            selection: Binding(
                get: { selectedTab.id },
                set: { newId in
                    if let newTab = DynamicZoneView.DynamicTab(rawValue: newId) {
                        selectedTab = newTab
                    }
                }
            ),
            namespace: tabBarNamespace
        )
    }
}