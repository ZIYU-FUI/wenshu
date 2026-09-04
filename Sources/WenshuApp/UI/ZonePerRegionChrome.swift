// ZonePerRegionChrome.swift · Wenshu (文枢) · v0.28 followup Boss UX round 3
//
// Boss 2026-08-29 OOB '按老六区已经实现的复刻' = port the OLD 6区
// `ZoneTopToolbar` + `ZoneBottomToolbar` exactly (= 30 PT top + 30 PT
// bottom + the exact icons + status text per slot).
//
// Old 6区 source (= v0.27 = App.swift:1935-2058):
// - ZoneTopToolbar: HStack of buttons (Lucide icons via ZoneIcon),
//   30 PT height, with placeholder "占位文字" text at top-trailing.
//   Splitter line at bottom (1 PT).
// - ZoneBottomToolbar: status text at bottom-leading + optional
//   rightStatus text at bottom-trailing (= or WordCountInlineLabel
//   fallback). Splitter line at top (1 PT).
// - zoneStatus(for:) = per-slot left text:
//   - projectSidebar = "书架: N"
//   - projectPreview = "章节: N"
//   - editor = "字数: N"
//   - specializedTools = "工具就绪"
//   - aiChat = "" (skipped, ChatBottomToolbar internal)
//   - aiDynamic = "看板"
// - rightStatus(for:) = per-slot right text:
//   - projectSidebar = "书: N"
//   - others = "" (= WordCountInlineLabel fallback)
// - toolbarActions(for:) = per-slot top icon array:
//   - projectSidebar = [Templates(doc.badge.plus), 新建(book-open), 入驻(archive)]
//   - projectPreview = [Graph(waypoints), Search(magnifyingglass hidden in v0.25.1)]
//   - editor = [编辑(book-open-text), 大纲(puzzle), 反链(link)] + expand/shrink trailing
//   - specializedTools = [画布(scribble), 数据库(tablecells)]
//   - aiChat = [Bot(bot), Inbox(inbox)]
//   - aiDynamic = [] (uses internal DynamicZoneTabBar)
//
// This file ports all of these as pure value types + per-zone default
// factories (= boss拍: add 1 per-zone factory = 1 commit, auto-propagates
// to all builtin presets via the existing `RegionPerZoneChrome` wire-up).

import SwiftUI
import Lucide

// MARK: - Toolbar constants (= matches old LayoutTokens.toolbarHeight = 30 PT)

/// Per-region top + bottom toolbar height (= matches old 6区
/// `LayoutTokens.toolbarHeight = 30`, also matches v0.27 `ZoneTopToolbar`
/// + `ZoneBottomToolbar`).
public let kZoneToolbarHeight: CGFloat = 30
// v0.28 followup Boss UX round 26 (Boss 2026-08-29 OOB '我发现合底栏
// 顶栏的高度不一致, 分隔线高度也不一致'): canonical unified
// chrome height = 30 PT (= matches the macOS HIG tab bar / statusbar
// standard). All per-region toolbars (= zone top tab bar + zone
// bottom status) AND the Wenshu global statusbar use this same
// 30 PT value so they all line up flush when stacked vertically.
public let kChromeHeight: CGFloat = 30

/// Per-region icon visual size (= matches old `LayoutTokens.iconSize = 18`).
public let kZoneToolbarIconSize: CGFloat = 18

// MARK: - Top action (= matches old ZoneToolbarAction)

/// Per-region top toolbar button. Mirrors old `ZoneToolbarAction`
/// (= label + icon + action closure).
public struct ZoneTopAction: Identifiable, Sendable {
    public let id: String
    public let label: String       // accessibility + tooltip
    public let icon: String        // Lucide name (kebab-case, e.g. "waypoints")
    public let onSelect: (@Sendable () -> Void)?

    public init(
        id: String,
        label: String,
        icon: String,
        onSelect: (@Sendable () -> Void)? = nil
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.onSelect = onSelect
    }
}

/// Per-region bottom status text (= matches old `ZoneBottomToolbar.status`).
///
/// B-16: added `rightOnTap` closure for clickable right-field text
/// (= e.g. editor zone "反链 0" label triggers popover). Default nil
/// keeps backward compat with sidebar/preview/tools/dynamic zones
/// whose right text is plain (= no tap affordance). `@Sendable`
/// wrapper preserves the struct's Sendable conformance (= closure
/// captures stay on the MainActor; = Swift 6 strict concurrency safe).
public struct ZoneBottomStatus: Sendable {
    public let left: String        // left-aligned text (e.g. "章节: 0", "书架: 3")
    public let right: String       // right-aligned text (e.g. "书: 5", "反链 0")
    public let rightOnTap: (@Sendable () -> Void)?  // optional tap handler on right text (= boss 9/2 OOB '右下的反链 0, 点击可以弹窗')

    public init(left: String = "", right: String = "", rightOnTap: (@Sendable () -> Void)? = nil) {
        self.left = left
        self.right = right
        self.rightOnTap = rightOnTap
    }
}

// MARK: - Zone chrome (= matches old ZoneModule outer chrome)

/// Per-region chrome = top toolbar (30 PT) + content + bottom toolbar
/// (30 PT), exactly matching old `ZoneModule` shape (= per Boss plan A
/// verbatim port of v0.27 implementation). When `topActions` is empty,
/// renders the old placeholder mode (= shows lucide icon set inline).
/// When `bottomStatus` is empty, renders the old placeholder text
/// "占位文字" (= backward compatibility per ticket 015.020 Standards
/// F2 fix).
@MainActor
public struct ZonePerRegionChrome<Content: View>: View {
    let topActions: [ZoneTopAction]
    let bottomStatus: ZoneBottomStatus
    let topSkip: Bool             // when true (= editor), skip top toolbar (= internal ZoneContentTabBar is the top)
    let bottomSkip: Bool          // when true (= aiChat), skip bottom toolbar
    // v0.32 boss 2026-09-02 OOB: ZoneSlot routed to
    // RegionContentBackground (= chrome tier vs content tier per
    // FCP-style brightness delta). nil = legacy caller (= chrome
    // tier fallback so SwiftUI previews + tests keep working).
    let zone: ZoneSlot?
    let content: () -> Content

    // v0.32: zone parameter is module-internal because ZoneSlot is
    // internal (= declared in App.swift without `public`). The init
    // itself drops `public` to match.
    init(
        topActions: [ZoneTopAction] = [],
        bottomStatus: ZoneBottomStatus = ZoneBottomStatus(),
        topSkip: Bool = false,
        bottomSkip: Bool = false,
        // v0.32 boss 2026-09-02 OOB ('参考一下 FCP, 各区有不同的
        // 区域颜色'): the ZoneSlot is now plumbed through to
        // RegionContentBackground (= single source of truth for
        // per-zone pane content color). Default = nil so legacy
        // callers (= SwiftUI previews, tests) keep working
        // unchanged (= they fall back to the chrome tier).
        zone: ZoneSlot? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.topActions = topActions
        self.bottomStatus = bottomStatus
        self.topSkip = topSkip
        self.bottomSkip = bottomSkip
        self.zone = zone
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            // v0.34: topBar removed (= 0 active caller, see file-bottom comment).
            // Region content (= fills remaining space).
            // v0.28 followup Boss UX round 42 (Boss 2026-08-29 OOB
            // '缺三个区, 项目管理, 工具, 聊天, 都没进你的样式表' =
            // Sidebar / Tools / Chat / Dynamic panes were missing
            // the RegionContentBackground wrapper). Apply it here at
            // the ZonePerRegionChrome layer (= wraps ALL 6 panes
            // uniformly = single source of truth for the canonical
            // per-pane content background).
            // v0.32 boss 2026-09-02 OOB: pass the routed ZoneSlot
            // through (= chrome tier or content tier per FCP-style
            // brightness delta). nil falls back to the chrome tier
            // so SwiftUI previews + tests keep working unchanged.
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(zone.map(RegionContentBackground.init(zone:)) ?? RegionContentBackground())
            // Bottom toolbar (= 30 PT, matches old ZoneBottomToolbar).
            // 5 of 6 active callers (sidebar/preview/editor/tools/dynamic)
            // pass bottomSkip: false; chat passes bottomSkip: true (= chat
            // uses its own internal ChatBottomToolbar per v0.21 ticket 10).
            if !bottomSkip {
                bottomBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom toolbar (= matches old ZoneBottomToolbar body)

    @MainActor
    private var bottomBar: some View {
        // v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个
        // 组件索引, 以后如果有新的地方用到相同的东西, 会自然而然的找到组件,
        // 而不是默认自动写个新的'): Phase 5 of refactor. Now uses the
        // new `PaneStatusBar` component (= ComponentIndex.md Level 2.6)
        // instead of inline HStack { Text + Spacer + Text } pattern.
        // PaneStatusBar wraps RegionStatusBar + applies DesignTokens
        // statusFont + statusForeground + chrome paddings automatically.
        // B-16: forward bottomStatus.rightOnTap so PaneStatusBar can
        // render the right text as a clickable Button (= editor zone's
        // "反链 0" popover trigger).
        PaneStatusBar(
            leftText: bottomStatus.left,
            rightText: bottomStatus.right,
            rightOnTap: bottomStatus.rightOnTap
        )
    }
}

// v0.34 boss 2026-09-02 OOB '所有区域的顶栏, 结构都一样, 为什么不能是一个组件'.
// The topBar (which used to be a 'private var' in ZonePerRegionChrome)
// was DEAD CODE: all 6 callers in TabContentDispatcher.swift pass
// topActions: [] + topSkip: true, meaning the topBar was never rendered
// (= each zone uses its own internal ZoneContentTabBar /
// DynamicZoneTabBar; the former chat-zone wrapper was inlined in v0.34).
// Removed in v0.34.
//
// Single-source-of-truth for per-pane top chrome (= the actual canonical
// 2 different components that the 6 zones use, post-v0.34) is split across:
//   - ZoneContentTabBar (sidebar/preview/editor/tools) — most common
//   - DynamicZoneTabBar (aiDynamic)
// Both follow the same Apple HIG structure (= HStack + icons +
// selected underline + .controlBackgroundColor + 1 PT .separator).
// The chat zone's tab bar now lives inline in TabContentDispatcher.aiChat
// as a direct PaneTabBar call (= PaneTabItem(id:"chat") + archive
// trailing button). Future ticket (= v0.35+ boss拍): if zone-specific
// state plumbing can be unified, merge ZoneContentTabBar +
// DynamicZoneTabBar + the inlined chat call into 1 WenshuZoneTopBar<ZoneSlot>
// generic component. Not done in v0.34 because DynamicZoneTabBar still
// needs its enum↔string binding shim (= SwiftUI Binding limitation).

// MARK: - Lucide + SF Symbol fallback icon (= matches old ZoneIcon)

/// Render a Lucide icon with SF Symbol fallback. Matches old `ZoneIcon`
/// (= ticket 005 pattern: Layer 1 = Lucide first, Layer 3 = SF Symbol
/// fallback on nil). Uses the wenshu `Lucide(_:)` API.
@MainActor
public struct ZoneChromeIcon: View {
    let systemName: String
    let size: CGFloat

    public init(systemName: String, size: CGFloat = kZoneToolbarIconSize) {
        self.systemName = systemName
        self.size = size
    }

    public var body: some View {
        if let lucide = Lucide(systemName) {
            lucide
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: systemName)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Per-zone default chrome factories (= verbatim port of v0.27 ZoneModule toolbarActions + zoneStatus + rightStatus)

/// Project sidebar chrome (= matches old `ZoneModule` `toolbarActions(for: .projectSidebar)` + `zoneStatus(for: .projectSidebar)` + `rightStatus(for: .projectSidebar)`).
///
/// Top actions (v0.27 boss 8/27 OOB):
/// - doc.badge.plus (Templates)
/// - book-open (新建)
/// - archive (入驻 — same pattern as editor expand/shrink trailing button)
///
/// Bottom: left = "书架: N", right = "书: N".
public func projectSidebarChrome(shelfCount: Int, bookCount: Int) -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top = [
        ZoneTopAction(id: "templates", label: "Templates", icon: "doc.badge.plus"),
        ZoneTopAction(id: "new-book", label: "新建", icon: "book-open"),
        ZoneTopAction(id: "archive", label: "入驻", icon: "archive"),
    ]
    let bottom = ZoneBottomStatus(left: "书架: \(shelfCount)", right: "书: \(bookCount)")
    return (top, bottom)
}

/// Project preview chrome (= matches old `toolbarActions(for: .projectPreview)` + `zoneStatus(for: .projectPreview)`).
///
/// Top actions (v0.25.1 ticket 012 + 014):
/// - book-open-check (预览 — replaces "eye", owner 2026-08-26 OOB)
/// - waypoints (图 — replaces "circle.grid.cross", owner 2026-08-26 OOB)
/// - (Search hidden in v0.25.1 per owner 2026-08-26 OOB; code preserved for future)
///
/// Bottom: left = "章节: N", right = "" (empty).
public func projectPreviewChrome(chapterCount: Int) -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top = [
        ZoneTopAction(id: "preview", label: "预览", icon: "book-open-check"),
        ZoneTopAction(id: "graph", label: "图", icon: "waypoints"),
    ]
    let bottom = ZoneBottomStatus(left: "章节: \(chapterCount)", right: "")
    return (top, bottom)
}

/// Editor chrome (= matches old `ZoneContentView(zoneSlug: "editor", tabs: [...])` icons + `zoneStatus(for: .editor)` + `rightStatus(for: .editor)`).
///
/// Top actions (v0.25.1 tickets 017 + 028):
/// - book-open-text (编辑 — replaces "pencil")
/// - puzzle (大纲 — replaces "list.bullet")
/// - link (反链 — same name in SF + Lucide)
///
/// Note: expand/shrink trailing button is NOT in this list (= it's a
/// separate trailing button per boss 2026-08-26 OOB '他是一个按钮
/// 不是一个 teb' = wired separately via `editorTrailingAction` param).
///
/// Bottom: left = "字数: N" (= reserved for future real word count
/// implementation; today = static 0), right = "反链 N" (boss 9/2 OOB:
/// REPLACE the legacy "N%" progress placeholder with backlinks count).
public func editorChrome(wordCount: Int, backlinkCount: Int) -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top = [
        ZoneTopAction(id: "edit", label: "编辑", icon: "book-open-text"),
        ZoneTopAction(id: "outline", label: "大纲", icon: "puzzle"),
        ZoneTopAction(id: "backlinks", label: "反链", icon: "link"),
    ]
    let bottom = ZoneBottomStatus(left: "字数: \(wordCount)", right: "反链 \(backlinkCount)")
    return (top, bottom)
}

/// Specialized tools chrome (= matches old `ZoneContentView(zoneSlug: "specializedTools", tabs: [...])` icons + `zoneStatus(for: .specializedTools)`).
///
/// Top actions (after v0.24 boss 8/24 删 '作曲' tab):
/// - scribble (画布)
/// - tablecells (数据库)
///
/// Bottom: left = "工具就绪", right = "".
public func specializedToolsChrome() -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top = [
        ZoneTopAction(id: "canvas", label: "画布", icon: "scribble"),
        ZoneTopAction(id: "database", label: "数据库", icon: "tablecells"),
    ]
    let bottom = ZoneBottomStatus(left: "工具就绪", right: "")
    return (top, bottom)
}

/// AI chat chrome (= matches old `toolbarActions(for: .aiChat)` — v0.25.1 ticket 005).
///
/// Top actions:
/// - bot (Bot — owner 2026-08-26 OOB)
/// - inbox (Inbox — owner 2026-08-26 OOB)
///
/// Bottom: SKIPPED (= chat zone uses internal ChatBottomToolbar per
/// v0.21 ticket 10, matches old `if slot != .aiChat` guard).
public func aiChatChrome() -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top = [
        ZoneTopAction(id: "bot", label: "Bot", icon: "bot"),
        ZoneTopAction(id: "inbox", label: "Inbox", icon: "inbox"),
    ]
    let bottom = ZoneBottomStatus(left: "", right: "")
    return (top, bottom)
}

/// AI dynamic chrome (= matches old `ZoneModule` `toolbarActions(for: .aiDynamic)` + `zoneStatus(for: .aiDynamic)`).
///
/// Top actions: EMPTY (= dynamic zone uses internal DynamicZoneTabBar per
/// v0.24 boss 8/24 OOB 'Toolbar 清空', = placeholder mode).
///
/// Bottom: left = "看板", right = "".
public func aiDynamicChrome() -> (top: [ZoneTopAction], bottom: ZoneBottomStatus) {
    let top: [ZoneTopAction] = []
    let bottom = ZoneBottomStatus(left: "看板", right: "")
    return (top, bottom)
}
