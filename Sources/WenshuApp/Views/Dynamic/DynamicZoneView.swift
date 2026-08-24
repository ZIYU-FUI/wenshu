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

/// DynamicZoneView: 动态区 body. 3 tabs (任务 / 进度 / 搜索) + Apple HIG TabBar pattern
/// (跟 ChatZoneTabBar 范式一致: 顶栏 SF Symbol + .accentColor 高亮选中态).
struct DynamicZoneView: View {
    enum DynamicTab: String, CaseIterable, Identifiable {
        // v0.24 boss验收fix (2026-08-24): Tab order per boss 8/24 explicit request:
        // tab1 = 进度 (Sub-agent progress), tab2 = 待办 (Todo), tab3 = 搜索 (Search).
        case subAgentProgress = "进度"
        case todo = "待办"
        case search = "搜索"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .subAgentProgress: return "checklist.checked"
            case .todo: return "checklist"
            case .search: return "magnifyingglass"
            }
        }
    }

    // v0.24 boss验收fix: persist tab selection across launches.
    @AppStorage("wenshu.tabIndex.aiDynamic") private var selectedTabRaw: String = "进度"

    private var selectedTab: DynamicTab {
        get { DynamicTab(rawValue: selectedTabRaw) ?? .subAgentProgress }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            DynamicZoneTabBar(selectedTab: Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            ))
            Group {
                switch selectedTab {
                case .todo:
                    TodoListView()
                case .subAgentProgress:
                    SubAgentProgressView()
                case .search:
                    SearchPanel()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.default, value: selectedTab)
        }
        .background(DesignColor.dynamicZoneSurface)
    }
}

/// DynamicZoneTabBar: 顶栏 3 SF Symbol tab + 选中态 .accentColor (跟 ChatZoneTabBar 范式一致)
struct DynamicZoneTabBar: View {
    @Binding var selectedTab: DynamicZoneView.DynamicTab

    var body: some View {
        HStack(spacing: 9) {
            ForEach(DynamicZoneView.DynamicTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    // v0.24 boss验收fix: icon only, no title label.
// Boss 8/24 follow-up: 'tab 里标题小字不需要'.
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(tab == selectedTab ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        // v0.24 boss验收fix: flush at top of zone (was: padded 6 PT down).
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LayoutTokens.toolbarHeight)
        .background(DesignColor.zoneSurface)
        .overlay(alignment: .bottom) {
            DesignColor.splitterLine.frame(height: 1)
        }
        .animation(.default, value: selectedTab)
    }
}