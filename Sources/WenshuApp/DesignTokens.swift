// Sources/WenshuApp/UI/DesignTokens.swift
//
// v0.28 followup Boss UX round A (Boss 2026-08-30 OOB '你需要做一个组件索引,
// 以后如果有新的地方用到相同的东西, 会自然而然的找到组件, 而不是默认自动
// 写个新的'): Phase 1 of 5-phase component refactor.
//
// Single source of truth for all chrome dimensions, paddings, font sizes,
// dividers, tab metrics (= extracted from LayoutTokens + 16 files of
// inline literals). Listed in ComponentIndex.md Level 1.1.
//
// = canonical dimensions for the unified Wenshu per-region chrome (= matches
// Apple HIG 30 PT toolbar standard, Apple Pages / Mail / Xcode toolbar
// layout). Use these constants instead of inline numbers.
//
// Boss's dual-axis audit found:
// - chrome height 30 PT in 3 different places (= LayoutTokens + ZonePerRegionChrome)
// - chrome padding 18 PT in 5 different places (LayoutTokens + inline)
// - .font(.system(size:13)) in 10 files (= status bar text)
// - .foregroundStyle(.tertiary) in 16 files (= status bar text)
// - chatTabHotArea (= 28 PT) named after chat but used by ALL pane tabs
// - divider 1 PT in 5 inline places (= no constant)

import SwiftUI

// MARK: - DesignTokens namespace

/// Single source of truth for all chrome dimensions, paddings, fonts,
/// dividers, tab metrics (= Wenshu per-region UI). Use these constants
/// instead of inline numbers (= ComponentIndex.md Level 1.1).
@MainActor
public enum DesignTokens {
    // MARK: - Chrome dimensions

    /// Per-pane chrome height (= 30 PT, matches Apple HIG canonical toolbar).
    /// Used by: RegionTabBar, RegionStatusBar, ZonePerRegionChrome.topBar/
    /// bottomBar, ZoneContentTabBar, DynamicZoneTabBar, ChatZoneTopChrome.
    public static let chromeHeight: CGFloat = 30

    /// Per-pane chrome horizontal leading padding (= 18 PT, matches Apple HIG).
    public static let chromePaddingLeading: CGFloat = 18

    /// Per-pane chrome horizontal trailing padding (= 18 PT, matches Apple HIG).
    public static let chromePaddingTrailing: CGFloat = 18

    /// Per-pane chrome vertical padding (= 8 PT, Apple HIG standard for
    /// vertically-centered 13 PT text + 18 PT icon). Replaces previous
    /// chromePaddingMedium (5) + chromePaddingLarge (6) (= inconsistent).
    public static let chromePaddingVertical: CGFloat = 8

    // MARK: - Tab metrics

    /// Per-pane tab button hot area (= 28×28 PT). Matches Apple HIG
    /// canonical small toolbar button size.
    /// **Renamed from** `DesignTokens.paneTabHotArea` (= was chat-specific
    /// naming, now generic for ALL pane tabs).
    public static let paneTabHotArea: CGFloat = 28

    /// Per-pane tab icon size (= 18×18 PT, fits within 28 PT hot area).
    public static let tabIconSize: CGFloat = 18

    /// Per-pane tab selected-state underline height (= 1 PT, Apple HIG
    /// standard for tab bar selected indicator). The line is rendered
    /// with `.clipShape(Capsule())` for fully rounded ends (= two
    /// round caps on both sides, per boss 2026-08-30 OOB '加满圆角, 两头圆').
    public static let tabUnderlineHeight: CGFloat = 1

    // MARK: - Dividers

    /// 1 PT hairline divider height (= Apple HIG standard for tab bar /
    /// status bar bottom divider + splitter).
    public static let dividerHeight: CGFloat = 1

    // MARK: - Status bar text

    /// Status bar font (= 13 PT, Apple HIG secondary text). Replaces
    /// `.font(.system(size: 13))` in 10 files.
    public static let statusFont: Font = .system(size: 13)

    /// Status bar foreground (= Apple HIG `.tertiary` HierarchicalShapeStyle).
    /// Replaces `.foregroundStyle(.tertiary)` in 16 files.
    public static let statusForeground: HierarchicalShapeStyle = .tertiary
}