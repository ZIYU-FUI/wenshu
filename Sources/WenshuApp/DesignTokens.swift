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

    /// Per-pane chrome micro padding (= 4 PT). Used for tight inset inside
    /// chrome chrome (= icon-picker cells, tab handles, divider label gaps).
    /// Replaces inline `.padding(.horizontal, 4)`.
    public static let chromePaddingMicro: CGFloat = 4

    /// Per-pane chrome small padding (= 6 PT). Used for status bar hover,
    /// tight text padding inside chips, badge interior gaps.
    /// Replaces inline `.padding(.vertical, 6)`.
    public static let chromePaddingSmall: CGFloat = 6

    /// Per-pane chrome medium padding (= 12 PT). Apple HIG standard for
    /// bordered content rows (= chat input, popup buttons, picker rows).
    /// Replaces inline `.padding(.horizontal, 12)`.
    public static let chromePaddingMedium: CGFloat = 12

    /// Per-pane chrome large padding (= 16 PT). Apple HIG standard for
    /// stacked section separators (= onboarding body, Settings rows).
    /// Replaces inline `.padding(.top, 16)`.
    public static let chromePaddingLarge: CGFloat = 16

    /// Per-pane chrome extra-large padding (= 24 PT). Used only for
    /// onboarding hero text block (= one-time welcome layout).
    /// Replaces inline `.padding(.horizontal, 24)`.
    public static let chromePaddingXLarge: CGFloat = 24

    /// Settings segmented picker leading inset (= 14 PT). Apple HIG
    /// standard for inline picker alignment inside Settings rows.
    /// Replaces inline `.padding(.leading, 14)`.
    public static let chromePaddingPickerLeading: CGFloat = 14

    /// Chat input outer bottom margin (= 10 PT). Apple HIG standard for
    /// chat input row bottom inset (= Messages / Mail / Xcode).
    /// Replaces inline `.padding(.bottom, 10)`.
    public static let chromePaddingChatBottom: CGFloat = 10

    /// Floating edit-mode indicator chip horizontal padding (= 10 PT).
    /// Apple HIG standard for floating chip / badge layout.
    /// Replaces inline `.padding(.horizontal, 10)`.
    public static let chromePaddingChipHorizontal: CGFloat = 10

    /// Hotkey chip micro vertical padding (= 1 PT). Apple HIG standard
    /// for inline keyboard-shortcut chip inside toolbar labels.
    /// Replaces inline `.padding(.vertical, 1)`.
    public static let chromePaddingHotkeyVertical: CGFloat = 1

    /// Toolbar / statusbar cluster internal icon-to-icon gap (= 4 PT).
    /// Apple HIG canonical (= developer.apple.com/design/human-interface-
    /// guidelines/toolbars): minimum spacing for grouped toolbar icons
    /// (= the gap Finder / Mail / Pages use between grouped buttons in
    /// the per-pane tab bar + status bar). Replaces inline
    /// `HStack(spacing: 0)` between cluster buttons (= magic number
    /// 0 = not Apple HIG, but Apple HStack requires a value; using
    /// `0` was a self-rolled non-canonical choice = zero spacing
    /// = buttons snapped together = Apple HIG violation).
    public static let chromePaddingClusterGap: CGFloat = 4

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