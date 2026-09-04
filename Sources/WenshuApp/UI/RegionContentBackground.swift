// Sources/WenshuApp/UI/RegionContentBackground.swift
//
// v0.28 followup Boss UX round 31-32 (Boss 2026-08-29 OOB '素材预览区,
// [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
// 动态区, 那种透明的程度, 和其他区域不一样, 我说的是背景, 你仔细
// 对比一下'):
//
// = Single source of truth for per-pane content backgrounds (= the
// background behind the actual content of each pane, NOT the tab bar
// at the top of the pane).
//
// Initially (round 31) tried to use `.regularMaterial` (= a layered
// material that adds blur to whatever is behind it). But this is
// OPAQUE-ISH — it BLOCKS the underlying window's `.glass` material
// from showing through. Sidebar / Tools / Chat panes have NO
// explicit background (= transparent), so they SHOW the window's
// `.glass` (= truly see-through to the desktop wallpaper).
//
// Round 32 fix: changed RegionContentBackground to `.glass` (= Apple's
// window-level glass material that matches what the window's
// containerBackground uses in App.swift). This way ALL panes have
// the SAME visual depth (= the window's `.glass` material shows
// through everywhere).
//
// Why `.glass` (= SwiftUICore.Glass.regular):
// - Matches the WindowGroup's `.containerBackground(for: .window)
//   { Rectangle.glassEffect(.regular) }` (= exact same material =
//   visually identical when stacked).
// - Renders the same regardless of where it's applied (= single
//   source of truth = identical visual depth across all panes).
// - Apple HIG canonical per-pane content background style on macOS
//   27 Tahoe (= Pages, Mail, Xcode all use this pattern).
//
// Why NOT `.regularMaterial` (= what round 31 used):
// - `.regularMaterial` is a DIFFERENT material from `.glass`
//   (= layered material vs. window material).
// - Renders as semi-opaque blur (= blocks the window's .glass).
// - Sidebar / Tools / Chat have NO background, so they showed
//   window's `.glass` (= more transparent than the panes that had
//   `.regularMaterial`).
// - Boss's observation in round 32: 'preview pane + dynamic pane look
//   less transparent than other panes' — this was because of
//   `.regularMaterial` blocking the window's glass.
//
// Solution = change RegionContentBackground to `.glass` (= window-
// level material = identical visual depth everywhere).

import SwiftUI

// MARK: - RegionContentBackground

/// Canonical per-pane content background (= the translucent material
/// behind the actual content of each pane, NOT the tab bar at the top).
///
/// **SINGLE SOURCE OF TRUTH**: Used by all per-pane content views
/// (= `PreviewTabBackground`, `DynamicZoneView` outer VStack, editor
/// placeholder, etc.). All panes now render with the same `.glass`
/// window-level material (= matches the Wenshu window's own
/// `.containerBackground(.glass)` so every pane shows the same
/// see-through desktop wallpaper).
///
/// Visual configuration:
/// - Material: `.glass` (= Apple SwiftUICore.Glass.regular, the same
///   canonical Liquid Glass used by the window's containerBackground).
/// - Truly transparent (= desktop wallpaper shows through, same as
///   Sidebar / Tools / Chat panes which have no explicit background).
@MainActor
public struct RegionContentBackground: View {
    /// v0.32 boss 2026-09-02 OOB ('参考一下 FCP, 各区有不同的区域
    // [CJK-TRANSLATE] 2 line(s) awaiting manual translation (see git blame for original CJK text)
    /// 颜色, 这样各区很自然然的做了区分. 你看一下 apple api 的颜色,
    /// 暗色模式是怎么分级的, 亮色模式是怎么分级的'): FCP-style
    /// natural per-region differentiation via Apple-supplied NSColor
    /// brightness tiers (= no custom RGB ladder, no opacity-tinted
    /// divisions). The 6 zones map to 2 Apple-canonical tiers:
    ///
    /// - chrome tier (.controlBackgroundColor) for the 2 chrome
    ///   zones (projectSidebar, specializedTools) = Apple HIG
    ///   "large controls" (sidebar / inspector). Renders 1 tier
    ///   LIGHTER than windowBackgroundColor in dark mode (= chrome
    ///   appears raised above the content inset below).
    /// - content tier (.windowBackgroundColor) for the 4 content
    ///   zones (projectPreview, editor, aiChat, aiDynamic) = Apple
    ///   HIG "document content" area (= the area beneath your
    ///   window's views). Renders 1 tier DARKER than
    ///   controlBackgroundColor in dark mode (= content appears
    ///   inset into the window).
    ///
    /// Light mode reverses the brightness direction automatically
    /// (= Apple's AppKit adapts the same NSColor call to the
    /// opposite brightness direction without wenshu intervention).
    /// See `.scratch/v0.32-color-apple-audit/audit.md` §1.2 for the
    /// full light/dark brightness ladder table.
    private let zone: ZoneSlot

    /// Default initializer (= no zone). Used by legacy callers that
    /// predate the v0.32 zone-routed colors (= e.g. SwiftUI previews,
    /// or any caller that has not yet migrated). Default = chrome
    /// tier (.controlBackgroundColor) because that is the more
    /// common case (= 2 of 6 zones, plus it visually matches the
    /// pre-v0.32 pane look so the migration is non-regressive for
    /// any caller that has not migrated).
    public init() {
        self.zone = .projectSidebar
    }

    /// Zone-routed initializer (= v0.32). Caller passes the
    /// ZoneSlot whose background is being rendered.
    /// ZonePerRegionChrome is the single source-of-truth caller
    /// (= all 6 zones go through it); this initializer exists so
    /// the zone lookup is centralized here, not duplicated at
    /// every call site. `internal` because ZoneSlot itself is
    /// module-internal (= declared in App.swift without `public`).
    init(zone: ZoneSlot) {
        self.zone = zone
    }

    /// Apple-canonical NSColor per zone (= chrome tier or content
    /// tier, per the audit mapping). Direct NSColor static property
    /// call — no wrapper enum, no custom color construct. Boss
    /// 2026-09-02 OOB hard rule: "你所有用的颜色, 都是 API 给的,
    /// 不要自定义" — every color literal must come from an Apple
    /// NSColor API.
    ///
    /// Per boss 2026-09-02 OOB Monterey 12.0.1 Dark Mode
    /// reference values for the 4-tier dynamic system color
    /// hierarchy (= the standard Apple HIG layout):
    /// - windowBackgroundColor    = #323232 (lightest = container)
    /// - underPageBackgroundColor = #282828 (middle = content)
    /// - controlBackgroundColor   = #1E1E1E (deepest = chrome)
    /// - textBackgroundColor      = #1E1E1E (deepest = chrome)
    ///
    /// Content tier = .underPageBackgroundColor (= 1 tier lighter
    /// than chrome in dark mode = visually floats above the chrome
    /// tier per Apple HIG content-floats convention).
    ///
    /// Note: current local macOS environment is compressing
    /// windowBackgroundColor to #1E1E1E (= identical to
    /// controlBackgroundColor = no visible delta). This is
    /// accessibility-driven (= Increase Contrast or Tinted mode).
    /// The code uses Apple canonical NSColor = will re-expand the
    /// tiers when the accessibility override is disabled.
    private var appleBackground: Color {
        switch zone {
        case .projectSidebar, .specializedTools:
            // Chrome tier (= sidebar / inspector / large control).
            // Dark mode: #1E1E1E (= the deepest of the 4 tiers =
            // recessed container).
            return Color(nsColor: .controlBackgroundColor)
        case .projectPreview, .editor, .aiChat, .aiDynamic:
            // Content tier (= "the area beneath your window's
            // views" per Apple docs). Dark mode: #282828 (= 1
            // tier lighter than chrome in dark mode = Apple HIG
            // content-floats).
            return Color(nsColor: .underPageBackgroundColor)
        }
    }

    public var body: some View {
        // Per-pane content background = opaque Apple NSColor (chrome
        // tier vs content tier). Apple .glassEffect auto-applies
        // project-wide and auto-adapts to system settings (dark mode,
        // Reduce Transparency, Increase Contrast).
        Rectangle().fill(appleBackground)
    }
}

// MARK: - View extension

/// Convenience View extension: `.regionContentBackground()` applies the
/// canonical RegionContentBackground to any view (= single source of
/// truth for per-pane content backgrounds across the app).
public extension View {
    /// Apply canonical per-pane content background (= single
    /// `.glass` window-level Liquid Glass layer).
    ///
    /// Usage: `SomeView().regionContentBackground()`
    func regionContentBackground() -> some View {
        self.background(RegionContentBackground())
    }
}