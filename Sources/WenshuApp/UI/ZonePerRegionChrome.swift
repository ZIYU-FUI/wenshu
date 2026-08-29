// ZonePerRegionChrome.swift · Wenshu (文枢) · v0.28 followup Boss UX round 2
//
// Boss 2026-08-29 OOB '老的六区, 是顶栏底栏在各区域里都有配' =
// in the old 6区 (= LayoutShellView + ZoneModule), every region has
// ITS OWN top toolbar (30 PT) + bottom toolbar (30 PT) with per-region
// icons + status text. The new framework only has GLOBAL AppTitlebar
// (top) + AppStatusbar (bottom) (= no per-region toolbar). Boss wants
// BOTH layers: global chrome + per-region chrome stacked.
//
// Architecture (= matches old 6区 pattern + new contribution-driven):
// - WenshuChromeOverlay wraps the main content (= LayoutShellView /
//   WorkspaceView). Provides the global chrome.
// - INSIDE the main content, each region (= sidebar, preview, editor,
//   tools, chat, dynamic) is wrapped in ZonePerRegionChrome
//   (= top + content + bottom) where top + bottom are populated via
//   the contribution registry (= same `area: 'panes'` pattern as
//   the panes themselves, but with `data: {kind: 'region-top' |
//   'region-bottom'}` discriminator).
// - Each region's chrome (= top + bottom) is automatically
//   propagated to ALL builtin presets + user-saved presets
//   (= same contribution pattern as panes). New region feature =
//   add 1 new contribution; no preset edits needed.

import Foundation
import SwiftUI
import AppKit

// MARK: - Region top/bottom toolbar items

/// Per-region top toolbar item. Reuses the WenshuChromeOverlay's
/// TitlebarTool style (= 24x24 PT hit area + hover wash).
public struct RegionTopItem: Identifiable, Sendable {
    public let id: String
    public let iconName: String
    public let label: String
    public let onSelect: (@Sendable () -> Void)?

    public init(
        id: String,
        iconName: String,
        label: String,
        onSelect: (@Sendable () -> Void)? = nil
    ) {
        self.id = id
        self.iconName = iconName
        self.label = label
        self.onSelect = onSelect
    }
}

/// Per-region bottom toolbar item. Reuses the StatusbarItem style.
public struct RegionBottomItem: Identifiable, Sendable {
    public let id: String
    public let label: String?
    public let detail: String?
    public let iconName: String?

    public init(
        id: String,
        label: String? = nil,
        detail: String? = nil,
        iconName: String? = nil
    ) {
        self.id = id
        self.label = label
        self.detail = detail
        self.iconName = iconName
    }
}

// MARK: - Region per-zone chrome (= 30 PT top + content + 30 PT bottom)

/// Per-region top + bottom toolbar height (= matches old 6区
/// `ZoneTopToolbar` 30 PT + `ZoneBottomToolbar` 30 PT = 60 PT total
/// per region). Global AppTitlebar 34 PT + AppStatusbar 24 PT are
/// separate (= different constant).
public let kRegionPerZoneToolbarHeight: CGFloat = 30

/// Region zone chrome (= per-region top toolbar + content + bottom toolbar).
/// Matches the old 6区 `ZoneModule` shape (= ZoneTopToolbar 30 PT + content +
/// ZoneBottomToolbar 30 PT) but new framework doesn't ship ZoneModule yet.
/// When the new WorkspaceView/PaneRenderer ships (= v0.29+), the per-region
/// chrome wraps each pane. For now (= 2026-08-29 followup), this is a
/// standalone component boss can wire into WenshuChromeOverlay via
/// `regionChrome(zone: .projectSidebar, ...)` parameter.
@MainActor
public struct RegionPerZoneChrome<Content: View>: View {
    let topItems: [RegionTopItem]
    let bottomItems: [RegionBottomItem]
    let content: () -> Content

    public init(
        topItems: [RegionTopItem] = [],
        bottomItems: [RegionBottomItem] = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.topItems = topItems
        self.bottomItems = bottomItems
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Region top toolbar (30 PT, per old 6区 spec).
            if !topItems.isEmpty {
                RegionTopBar(items: topItems)
            } else {
                // Empty placeholder (= still 30 PT to preserve layout)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: kRegionPerZoneToolbarHeight)
            }
            // Region content.
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Region bottom toolbar (30 PT, per old 6区 spec).
            if !bottomItems.isEmpty {
                RegionBottomBar(items: bottomItems)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: kRegionPerZoneToolbarHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Region top bar (= 30 PT, matches old ZoneTopToolbar)

@MainActor
private struct RegionTopBar: View {
    let items: [RegionTopItem]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    item.onSelect?()
                } label: {
                    Image(systemName: item.iconName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.label)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: kRegionPerZoneToolbarHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}

// MARK: - Region bottom bar (= 30 PT, matches old ZoneBottomToolbar)

@MainActor
private struct RegionBottomBar: View {
    let items: [RegionBottomItem]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                if let iconName = item.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }
                if let label = item.label {
                    Text(label)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.primary)
                }
                if let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: kRegionPerZoneToolbarHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .top
        )
    }
}

// MARK: - Default per-region chrome (= Boss's spec)

// These mirror the old 6区 per-zone actions (= per old LayoutShellView
// ZoneTopToolbar + ZoneBottomToolbar + ZoneModule.zoneStatus / rightStatus).
// Boss: "看老 LayoutShellView 的 ZoneModule.zoneStatus 是怎么写的" = exactly
// reproduced here for backward compat. New features can be added
// incrementally (= 1 new contribution per region per action).

/// Sidebar (= 项目管理区) per-region chrome. Status: 书架数 (left) + 书数 (right).
public func defaultSidebarRegionChrome(bookCount: Int, shelfCount: Int) -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    let top: [RegionTopItem] = [
        RegionTopItem(id: "new-book", iconName: "plus", label: "新建"),
        RegionTopItem(id: "search", iconName: "magnifyingglass", label: "搜索"),
    ]
    let bottom: [RegionBottomItem] = [
        RegionBottomItem(id: "shelf-count", label: "书架: \(shelfCount)"),
        RegionBottomItem(id: "book-count", label: "书: \(bookCount)"),
    ]
    return (top, bottom)
}

/// Preview (= 素材预览区) per-region chrome. Status: 章节数 + 当前章节.
public func defaultPreviewRegionChrome(chapterCount: Int) -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    let top: [RegionTopItem] = [
        RegionTopItem(id: "search", iconName: "magnifyingglass", label: "搜索"),
        RegionTopItem(id: "filter", iconName: "line.3.horizontal.decrease", label: "筛选"),
    ]
    let bottom: [RegionBottomItem] = [
        RegionBottomItem(id: "chapter-count", label: "章节: \(chapterCount)"),
    ]
    return (top, bottom)
}

/// Editor (= 编辑器) per-region chrome. Status: 字数 + 进度.
public func defaultEditorRegionChrome(wordCount: Int, progress: Double) -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    let top: [RegionTopItem] = [
        RegionTopItem(id: "bold", iconName: "bold", label: "粗体"),
        RegionTopItem(id: "italic", iconName: "italic", label: "斜体"),
        RegionTopItem(id: "underline", iconName: "underline", label: "下划线"),
        RegionTopItem(id: "list", iconName: "list.bullet", label: "列表"),
        RegionTopItem(id: "more", iconName: "ellipsis", label: "更多"),
    ]
    let bottom: [RegionBottomItem] = [
        RegionBottomItem(id: "word-count", label: "字数: \(wordCount)"),
        RegionBottomItem(id: "progress", detail: "\(Int(progress * 100))%"),
    ]
    return (top, bottom)
}

/// Tools (= 工具区) per-region chrome. Status: 工具就绪.
public func defaultToolsRegionChrome() -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    let top: [RegionTopItem] = [
        RegionTopItem(id: "outline", iconName: "list.bullet.rectangle", label: "大纲"),
        RegionTopItem(id: "kanban", iconName: "rectangle.split.3x1", label: "看板"),
    ]
    let bottom: [RegionBottomItem] = [
        RegionBottomItem(id: "tools-status", label: "工具就绪"),
    ]
    return (top, bottom)
}

/// Chat (= 聊天区) per-region chrome. No top toolbar (= ChatView has
/// its own internal tab bar). Status: 来自 chat 子组件 (= 已有).
public func defaultChatRegionChrome() -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    // No top (= chat zone uses in-child ChatBottomToolbar per v0.21 ticket 10).
    // Bottom: empty (= chat zone has its own internal status).
    return ([], [])
}

/// Dynamic (= 动态区) per-region chrome. Status: 看板.
public func defaultDynamicRegionChrome() -> (top: [RegionTopItem], bottom: [RegionBottomItem]) {
    let top: [RegionTopItem] = [
        RegionTopItem(id: "progress", iconName: "chart.bar", label: "进度"),
        RegionTopItem(id: "todo", iconName: "checklist", label: "待办"),
        RegionTopItem(id: "search", iconName: "magnifyingglass", label: "搜索"),
    ]
    let bottom: [RegionBottomItem] = [
        RegionBottomItem(id: "kanban", label: "看板"),
    ]
    return (top, bottom)
}