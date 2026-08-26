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
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // OOB '能不能让那个小横线的动画变成左右移动 不是渐隐渐显'. See
    // DynamicZoneTabBar comment (= matchedGeometryEffect pattern). One
    // namespace per tab bar class (= SwiftUI requires the namespace to
    // scope within a single view tree).
    @Namespace private var tabBarNamespace

    // v0.24 boss验收fix: selectedItem (Item with matching label) for icon highlighting.
    private var selectedItem: Item? {
        items.first(where: { $0.label == selection })
    }

    var body: some View {
        HStack(spacing: 18) {
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
                // v0.25.1 (= ticket 009 zone-content Lucide icon swap):
                // owner 2026-08-26 OOB '左上的项目管理区的顶栏 icon 换成
                // square-library' = SF books.vertical.fill → Lucide .squareLibrary
                // (= 2x2 stack of horizontal lines, like a library shelf icon).
                // Minimal-impact: same Lucide-first / SF-symbol-fallback helper
                // pattern (= Layer 3 fallback); when item.icon matches a Lucide
                // kebab-case name, render via Lucide; else fall back to SF
                // Image(systemName:). Both .bot and .squareLibrary are valid
                // Lucide icons so Layer 1 path is used.
                zoneContentTabBarIcon(item.icon)
                    .font(.system(size: LayoutTokens.iconSize))
                    .imageScale(.large)  // v0.24 boss验收fix (Boss 8/24): 12 PT font → ~12 PT visual boss验收fix (Boss 8/24): SF Symbol 视觉 size = ~17 PT
                    // (= .medium at 18 PT font, slightly smaller than font to fit
                    // in 18×18 PT frame with 0.5 PT padding each side)
                    .frame(width: LayoutTokens.iconSize, height: LayoutTokens.iconSize)
                                        // v0.25.1 (= ticket 020 hot area centered over icon):
                    // owner 2026-08-26 OOB '热区是写了 但是没有叠加到
                    // ICON 上 而是放在了 ICON 后在'. Per Apple SwiftUI
                    // hit-testing rules = Button's hit area = label's
                    // intrinsic content size, NOT outer .frame. Fix = wrap
                    // icon in explicit Color.clear.frame(28, 28).contentShape
                    // (.rect) INSIDE the label closure.
                    .overlay(alignment: .center) {
                        Color.clear
                            .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(item == selectedItem ? Color.accentColor : Color.secondary)
                    // v0.25.1 (= ticket 010 tab selected-state underline):
                    // owner 2026-08-26 OOB '现在的 tab 的选定状态 ICON 下
                    // 没有那个选定的小横线' = add Apple HIG canonical
                    // selected-tab underline (= 2 PT accent bar at
                    // bottom of selected tab, full button width).
                    // v0.25.1 (= ticket 011 unified tab hot area):
                    // owner 2026-08-26 OOB '所有的都按聊天的这个小机器人的
                    // 位置实现 居底' = apply chat-tab hot-area pattern
                    // (= 28×28 PT inflated via inline .padding(.all,
                    // chatTabHitPad)) to zone-content tabs (= 4 zones:
                    // 项目侧栏/素材预览/编辑/工具). All site tab bars
                    // (chat zone + dynamic zone + 4 zone-content zones)
                    // now use the same 28×28 hot area + Apple HIG
                    // underline + reliability contentShape + clear
                    // background pattern.
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
                    // hot area.
                    .buttonStyle(IconButtonStyle())
                    .overlay(alignment: .bottom) {
                        if item == selectedItem {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: LayoutTokens.tabUnderlineHeight)
                                .matchedGeometryEffect(id: "tabBarUnderline", in: tabBarNamespace, isSource: true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .background(Color.clear)
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

    /// v0.25.1 (= ticket 009 zone-content Lucide icon swap): same Lucide-first /
    /// SF-symbol-fallback pattern as `chatZoneTabBarIcon` (= App.swift ChatZoneTabBar
    /// helper, ticket 005). Try `Lucide(systemName)` first; on nil fall back to
    /// `Image(systemName:)`. Preserves 100% SF Symbol behavior for non-Lucide
    /// icon names (= 5 zones with mixed SF + Lucide icons keep working).
    @ViewBuilder
    private func zoneContentTabBarIcon(_ systemName: String) -> some View {
        if let lucide = Lucide(systemName) {
            lucide
        } else {
            Image(systemName: systemName)
        }
    }
}