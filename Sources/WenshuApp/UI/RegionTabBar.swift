// Sources/WenshuApp/UI/RegionTabBar.swift
//
// v0.28 followup Boss UX round 30 (Boss 2026-08-29 OOB '顶栏不是一个
// [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
// 组件吗, 底栏不是一个组件吗, 背景区不是一个组件吗, 你看截图, 每
// 个区域的毛玻璃效果都不一样, 感觉是某些设定不一样'):
//
// = Single source of truth for ALL per-pane tab bars across the app.
// Previously each pane had its OWN implementation of "tab bar with
// Liquid Glass background + 1 PT bottom separator + 30 PT height":
//
//   1. ZoneContentView.ZoneContentTabBar (= sidebar / preview / editor / tools)
//   2. (deleted in v0.34) chat-zone wrapper (= chat, since inlined
//      into TabContentDispatcher.aiChat via a direct PaneTabBar call)
//   3. DynamicZoneView.DynamicZoneTabBar (= dynamic / kanban; survives as a
//      genuine enum↔string binding shim)
//
// All three had IDENTICAL configuration but DIFFERENT visual result
// (= boss observed in screenshot: "每个区域的毛玻璃效果都不一样").
// Root cause = each component independently rendered its own
// .background(.regularMaterial) + .overlay(.separator), and SwiftUI's
// material rendering can subtly differ when the same configuration is
// applied in different contexts (= material renders relative to the
// underlying view layer = inconsistencies compound across implementations).
//
// Solution = extract a SINGLE RegionTabBar component that ALL three
// panes use. Now they all render identically (= one configuration =
// one visual result).
//
// Design contract for the single component:
// - Height: kChromeHeight = 30 PT (= matches canonical macOS HIG
//   tab bar height, unified across the app in round 26).
// - Background: .regularMaterial (= Apple canonical Liquid Glass
//   translucency, macOS 27 Tahoe).
// - Bottom separator: 1 PT Apple .separator ShapeStyle (= canonical
//   Liquid Glass hairline, semitransparent + dark/light adaptive).
// - Layout: HStack with left-aligned content + spacer + right-aligned
//   trailing content (= Apple HIG tab bar pattern).
//
// Why this works:
// - ONE component = ONE render path = ONE visual result everywhere.
// - Future Liquid Glass tweaks apply to all panes simultaneously
//   (= boss doesn't need to "make each pane's material the same" again).
// - Layout tokens (kChromeHeight, etc.) are centralized in
//   LayoutTokens (= the .regularMaterial background references a single
//   canonical source = no drift across implementations).

import SwiftUI

// MARK: - RegionTabBar

/// Canonical per-region tab bar (= the "top tab bar" each pane shows
/// at its top with the active tab + trailing buttons).
///
/// **SINGLE SOURCE OF TRUTH**: Used by all per-pane tab bars across
/// the app (= `ZoneContentView.ZoneContentTabBar`,
/// `DynamicZoneView.DynamicZoneTabBar`). Both now render identically
/// because they call this same view. The third historical wrapper
/// (= the chat-zone tab bar that lived inline in `PaneRenderer` before
/// v0.34) was deleted; its chat-zone call site now lives inline in
/// `TabContentDispatcher.aiChat`.
///
/// Visual configuration:
/// - Height: `LayoutTokens.toolbarHeight` (= 30 PT, canonical)
/// - Background: `.regularMaterial` (= Apple Liquid Glass translucency)
/// - Bottom separator: 1 PT Apple `.separator` ShapeStyle
///
/// Per Apple HIG canonical tab bar (= Pages, Mail, Xcode, Finder all
/// use this pattern): translucent material + 1 PT hairline at the
/// bottom edge (= semitransparent separator that adapts to dark/light
/// mode automatically).
@MainActor
public struct RegionTabBar<Content: View>: View {
    /// Content builder for the HStack inside the tab bar.
    /// Caller provides: tab buttons + trailing buttons + any spacers.
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    // v0.32 boss 2026-09-02 OOB: Apple canonical .glassEffect(.regular)
    // replaces the Liquid Glass opacity slider. Apple auto-adapts to
    // system settings (= dark mode / Reduce Transparency).

    public var body: some View {
        // RegionTabBar is a wrapper around the caller's content; spacing
        // is the caller's choice (= caller provides tabs + trailing + spacers,
        // so a single fixed HStack(spacing: 0) here keeps the caller's
        // HStack consistent). PaneTabBar (the canonical caller) sets
        // HStack(spacing: DesignTokens.chromePaddingClusterGap) for
        // the 4 PT Apple HIG button gap.
        HStack(spacing: 0) {
            content()
        }
        // Full-width, leading-aligned (= tabs start at left edge with
        // 18 PT horizontal padding from caller, matches Apple's Pages
        // / Mail tab bar layout). alignment: .leading + Spacer pushes
        // trailing buttons to the right edge.
        //
        // v0.30 boss 8/31 OOB: previously the trailing slot in
        // PaneTabBar (= PreviewSortMenuButton) was not visible
        // (= Spacer(minLength: 0) collapsed because the outer
        // .frame didn't force the HStack to fill the available
        // width). Now .frame(maxWidth: .infinity, alignment: .leading)
        // stays (= tabs start at left) but the HStack expands to
        // fill the row width (= Spacer inside the HStack now has
        // real space to consume = trailing button pushed right).
        .frame(maxWidth: .infinity, alignment: .leading)
        // Canonical 30 PT height (= matches kZoneToolbarHeight = 30 PT
        // = kChromeHeight = 30 PT = LayoutTokens.toolbarHeight = 30 PT
        // = unified chrome height across the app in round 26).
        .frame(height: LayoutTokens.toolbarHeight)
        // v0.32 boss 2026-09-02 OOB ('默认不加液态玻璃效果,
        // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
        // 我们就不加; 默认带的, 我们就默认带; 不能空着,
        // 空着透明了'): use Apple canonical controlBackgroundColor
        // (= NSColor controlBackgroundColor; macOS 27 Tahoe default
        // = system-managed color that adapts to dark / light mode
        // + accent tint; no per-pane glass specular, no transparent
        // see-through to the desktop wallpaper).
        .background(Color(nsColor: .controlBackgroundColor))
        // 1 PT Apple .separator ShapeStyle (= canonical Liquid Glass
        // hairline, semitransparent + dark/light adaptive). Applied
        // ONCE here as bottom overlay (= no manual Color, no NSColor,
        // = SwiftUI semantic separator = works with Liquid Glass).
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator as SeparatorShapeStyle)
                .frame(height: 1)
        }
    }
}

// MARK: - RegionStatusBar

/// Canonical per-region status bar (= the "bottom status bar" each pane
/// shows at its bottom with status text / icons). Same design contract
/// as `RegionTabBar` but flipped vertically (status text instead of tabs,
/// separator at TOP instead of BOTTOM).
///
/// **SINGLE SOURCE OF TRUTH**: Used by `ZonePerRegionChrome.bottomBar`
/// (the bottom status strip for all 6 panes).
///
/// Visual configuration:
/// - Height: `LayoutTokens.toolbarHeight` (= 30 PT, canonical)
/// - Background: `.regularMaterial` (= Apple Liquid Glass translucency)
/// - Top separator: 1 PT Apple `.separator` ShapeStyle
@MainActor
public struct RegionStatusBar<Content: View>: View {
    let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    // v0.32 boss 2026-09-02 OOB: Apple canonical .glassEffect(.regular)
    // replaces the Liquid Glass opacity slider. Apple auto-adapts to
    // system settings (= dark mode / Reduce Transparency).

    public var body: some View {
        // RegionStatusBar is a wrapper around the caller's content;
        // spacing is the caller's choice. PaneStatusBar (the canonical
        // caller) sets HStack(spacing: DesignTokens.chromePaddingClusterGap)
        // for the 4 PT Apple HIG gap between status text elements.
        HStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: LayoutTokens.toolbarHeight)
        // v0.32 boss 2026-09-02 OOB ('默认不加液态玻璃效果,
        // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
        // 我们就不加; 默认带的, 我们就默认带; 不能空着,
        // 空着透明了'): use Apple canonical controlBackgroundColor
        // (= NSColor controlBackgroundColor; macOS 27 Tahoe default
        // = system-managed color that adapts to dark / light mode
        // + accent tint; no per-pane glass specular, no transparent
        // see-through to the desktop wallpaper).
        .background(Color(nsColor: .controlBackgroundColor))
        // Top separator (1 PT Apple .separator) for the status bar
        // (= visually separates pane content from the bottom status).
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.separator as SeparatorShapeStyle)
                .frame(height: 1)
        }
    }
}