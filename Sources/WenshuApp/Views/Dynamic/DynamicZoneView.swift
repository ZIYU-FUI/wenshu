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
        VStack(spacing: 0) {
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
        .background(DesignColor.dynamicZoneSurface)
    }
}

/// DynamicZoneTabBar: 顶栏 3 SF Symbol tab + 选中态 .accentColor (跟 ChatZoneTabBar 范式一致)
struct DynamicZoneTabBar: View {
    @Binding var selectedTab: DynamicZoneView.DynamicTab
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // OOB '能不能让那个小横线的动画变成左右移动 不是渐隐渐显' =
    // replace the per-button crossfade underline (= ticket 010 = each
    // tab's .overlay(alignment:.bottom) renders its own bar, so switching
    // tabs fades old bar out + fades new bar in = crossfade) with a
    // SINGLE shared bar that translates horizontally between selected
    // tab positions (= 老板 '左右移动' = left-right slide, NOT crossfade).
    // Implementation per Apple HIG + SwiftUI docs: SwiftUI's
    // .matchedGeometryEffect(id:in:isSource:) on the underline Rectangle
    // lets SwiftUI animate the bar's position across HStack tab buttons.
    // When the selected tab changes, SwiftUI computes the new tab's
    // frame and slides the matched bar (= via internal CAAnimation).
    // `@Namespace` provides the match scope (= one per tab bar class).
    @Namespace private var tabBarNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DynamicZoneView.DynamicTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    // v0.24 boss验收fix: icon only, no title label.
// Boss 8/24 follow-up: 'tab 里标题小字不需要'.
                // v0.25.1 (= ticket 021 followup Apple HIG canonical):
                // owner 2026-08-26 OOB '热区是写了 但是没有叠加到 ICON
                // 上 而是放在了 ICON 后在' = previous ticket 020 attempt
                // put Color.clear INSIDE the icon's .overlay (= clipped
                // to 18×18 because overlay inherits base view's frame).
                // Per Apple HIG + medium hit-testing traps article, the
                // CORRECT pattern = Color.clear as the BASE view (= its
                // .frame(28, 28) becomes the label's intrinsic size =
                // Button's hit area), icon (Lucide 18 PT) as .overlay
                // aligned .center (= icon visually centered within the
                // 28×28 hot area, no clipping).
                // v0.25.1 (= ticket 023 dynamic zone Lucide-first):
                // owner 2026-08-26 OOB '右下看板和 todo 的两个 ICON
                // 没有显示出来' = ticket 022 changed icon names to
                // Lucide kebab-case ('layout-grid' / 'layout-list'),
                // but raw `Image(systemName: tab.icon)` returns empty
                // for non-SF names (= icons invisible even though
                // AXButton is rendered with empty label). Fix = use
                // `dynamicZoneTabBarIcon(tab.icon)` helper (= Layer 1
                // Lucide path = Layer 3 SF fallback = ticket 009
                // pattern = ZoneContentView's zoneContentTabBarIcon).
                Color.clear
                    .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                    .overlay(alignment: .center) {
                        dynamicZoneTabBarIcon(tab.icon)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                            .foregroundStyle(tab == selectedTab ? Color.accentColor : Color.secondary)
                    }
                    .contentShape(Rectangle())
                    // v0.25.1 (= ticket 010 tab selected-state underline):
                    // owner 2026-08-26 OOB '现在的 tab 的选定状态 ICON 下
                    // 没有那个选定的小横线' = add Apple HIG canonical
                    // selected-tab underline (= 2 PT accent bar at
                    // bottom of selected tab, full button width).
                    // v0.25.1 (= ticket 011 unified tab hot area):
                    // owner 2026-08-26 OOB '所有的都按聊天的这个小机器人的
                    // 位置实现 居底' = apply chat-tab hot-area pattern
                    // (= 28×28 PT inflated via inline .padding(.all,
                    // chatTabHitPad)) to dynamic zone tabs (= '.aiDynamic
                    // zone 看板/待办') for visual consistency. Chat tab
                    // pattern (= .padding(.all, 5) inside the label
                    // extends the icon render bounds to 28 PT; .overlay
                    // (.bottom) keeps the Apple HIG selected-tab underline
                    // anchored at the bottom of the inflated box).
                    // v0.25.1 (= ticket 013 underline slide animation):
                    // matchedGeometryEffect namespace ID on the bar
                    // Rectangle so SwiftUI can slide it between tab
                    // positions (= replaces ticket 010's per-button
                    // crossfade with single shared bar translating L/R).
                    // v0.25.1 (= ticket 018 explicit 28×28 hot zone):
                    // owner 2026-08-26 OOB '现在的 ICON 还是不是很好点 能不能
                    // 写一个 28×28 的透明矩形的热区' = ticket 011's
                    // .padding inflation was still flaky (= owner reported
                    // icons hard to click). Replace with explicit
                    // Color.clear.frame(28, 28).contentShape(.rect) =
                    // Apple HIG canonical pattern for plain-style button
                    // hot area (= explicit rectangular layer reserves
                    // 28×28 layout space + registers hit area via
                    // contentShape + provides the Color.clear backing
                    // SwiftUI hit-tester needs for reliable detection).
                    .buttonStyle(IconButtonStyle())
                    .overlay(alignment: .bottom) {
                        if tab == selectedTab {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: LayoutTokens.tabUnderlineHeight)
                                .matchedGeometryEffect(id: "tabBarUnderline", in: tabBarNamespace, isSource: true)
                                    .offset(y: 0)  // v0.25.1 ticket 024: offset adjusted for tabUnderlineHeight 3 PT (= underline at y=28-3=25 to 28 PT, flush with toolbar bottom = no offset needed since icon is centered at y=5-23 PT, 2 PT gap between icon bottom and underline top)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .background(Color.clear)
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

    /// v0.25.1 (= ticket 023 dynamic zone Lucide-first icon helper):
    /// owner 2026-08-26 OOB '右下看板和 todo 的两个 ICON 没有显示出来' =
    /// ticket 022 swapped the dynamic zone icon strings to Lucide
    /// kebab-case names ('layout-grid' / 'layout-list') but DynamicZoneView
    /// tab bar was still using direct `Image(systemName: tab.icon)`. Since
    /// 'layout-grid' / 'layout-list' are NOT valid SF Symbol names,
    /// `Image(systemName: ...)` returns an empty image (= the icon is
    /// invisible even though the AXButton is rendered). Fix = apply the
    /// same Lucide-first / SF-symbol-fallback pattern (= Layer 3 fallback)
    /// used in ZoneContentView's zoneContentTabBarIcon helper (ticket 009).
    /// When tab.icon matches a Lucide kebab-case name, render via Lucide;
    /// else fall back to `Image(systemName:)`. 'layout-grid' /
    /// 'layout-list' are valid Lucide cases (= Layer 1 path fires).
    @ViewBuilder
    private func dynamicZoneTabBarIcon(_ systemName: String) -> some View {
        // v0.27 boss 8/27 OOB: use the project-wide LucideIcon helper.
        LucideIconSystemFallback(systemName)
    }
}